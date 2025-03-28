//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Test, console2} from "forge-std/Test.sol";
import {DuckCoin} from "../../src/DuckCoin.sol";
import {DuckEngine} from "../../src/DuckEngine.sol";
import {ERC20Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    DuckEngine duckEngine;
    DuckCoin duckCoin;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public count;
    address[] public usersWhoDeposited;

    constructor(DuckEngine _duckEngine, DuckCoin _duckCoin) {
        duckEngine = _duckEngine;
        duckCoin = _duckCoin;
    }

    function depositCollateral(uint256 collateral, uint256 amount) public {
        address collateralToken = _getCollateralFromSeed(collateral);
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        ERC20Mock(collateralToken).mint(msg.sender, amount);
        ERC20Mock(collateralToken).approve(address(duckEngine), amount);
        duckEngine.depositCollateral(collateralToken, amount);
        bool exist = false;
        for (uint256 x = 0; x < usersWhoDeposited.length; x++) {
            if (usersWhoDeposited[x] == payable(msg.sender)) {
                exist = true;
                break;
            }
        }
        if (!exist) {
            usersWhoDeposited.push(msg.sender);
        }
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateral, uint256 amount) public {
        address collateralToken = _getCollateralFromSeed(collateral);
        vm.startPrank(msg.sender);
        uint256 userBalance = duckEngine.getUserCollateralBalance(
            msg.sender,
            collateralToken
        );
        amount = bound(amount, 0, userBalance);
        vm.assume(amount != 0); // Ensure amount does not exceed user's balance
        duckEngine.redeemCollateral(collateralToken, amount);
        vm.stopPrank();
    }

    function mintDuck(uint256 amount) public {
        (uint256 totalminted, uint256 totalCollateralUsd) = duckEngine
            .getAccountInfoUser(msg.sender);
        uint256 maxDuckTomint = (totalCollateralUsd / 2) - totalminted;
        vm.assume(maxDuckTomint < 0);
        amount = bound(amount, 0, maxDuckTomint);
        vm.assume(amount != 0); // Ensure amount does not exceed user's balance
        vm.startPrank(msg.sender);
        duckEngine.mintDuckCoin(amount);
        vm.stopPrank();
        count++;
    }

    function _getCollateralFromSeed(
        uint256 seed
    ) private view returns (address) {
        if (seed % 2 == 0) {
            return duckEngine.getCollateralTokens()[0];
        } else {
            return duckEngine.getCollateralTokens()[1];
        }
    }
}
