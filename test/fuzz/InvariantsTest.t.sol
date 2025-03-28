//SPDX-License-Identifier: MIT
// What are our invariants?
// the total supply of duck can't be more than total value of collateral

pragma solidity ^0.8.18;
import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDuck} from "../../script/DeployDuck.s.sol";
import {DuckEngine} from "../../src/DuckEngine.sol";
import {DuckCoin} from "../../src/DuckCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";
import {ERC20Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/mocks/ERC20Mock.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDuck deployer;
    DuckEngine duckEngine;
    DuckCoin duckCoin;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDuck();
        (duckEngine, duckCoin, helperConfig) = deployer.run();
        (, , weth, wbtc, ) = helperConfig.activeNetworkConfig();
        handler = new Handler(duckEngine, duckCoin);
        console2.log("DuckEngine address: ", address(handler));
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupplyx() public view {
        uint256 totalSupply = duckCoin.totalSupply();
        uint256 totalCollateralweth = ERC20Mock(weth).balanceOf(
            address(duckEngine)
        );
        uint256 totalCollateralwbtc = ERC20Mock(wbtc).balanceOf(
            address(duckEngine)
        );

        uint256 totalCollateralwethUSD = duckEngine.getPriceUsd(
            weth,
            totalCollateralweth
        );
        uint256 totalCollateralwbtcUSD = duckEngine.getPriceUsd(
            wbtc,
            totalCollateralwbtc
        );

        uint256 totalCollateral = totalCollateralwethUSD +
            totalCollateralwbtcUSD;

        console2.log("weth: ", totalCollateralwethUSD);
        console2.log("wbtc: ", totalCollateralwbtcUSD);
        console2.log("totalCollateral: ", totalCollateral);
        console2.log("totalSupply: ", totalSupply);

        console2.log("count: ", handler.count());
        console2.log("countx: ", handler.countx());
        assert(totalSupply <= totalCollateral);
    }
}
