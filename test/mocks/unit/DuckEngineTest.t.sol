// SPDX-Liciense-Identifier: MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {DeployDuck} from "../../../script/DeployDuck.s.sol";
import {DuckEngine} from "../../../src/DuckEngine.sol";
import {DuckCoin} from "../../../src/DuckCoin.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/mocks/ERC20Mock.sol";

contract DuckEngineTest is Test {
    DeployDuck deployer;
    DuckEngine duckEngine;
    DuckCoin duckCoin;
    HelperConfig helperConfig;

    /*-------------- Variable Declaration -------------------*/
    address ethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");

    uint256 public constant AMOUNT_MINT = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() public {
        deployer = new DeployDuck();
        (duckEngine, duckCoin, helperConfig) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
        ERC20Mock(weth).mint(USER, AMOUNT_MINT);
    }

    //////////////////////////////
    /////   Get usd value    /////
    //////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 12e18;
        // 12e18 * 2000e18 = 24000e18
        uint256 expectedEthUsdValue = 24000e18;
        uint256 ethUsdValue = duckEngine.getPriceUsd(weth, ethAmount);
        assertEq(ethUsdValue, expectedEthUsdValue);
    }

    //////////////////////////////
    /////   Deposit collatera /////
    //////////////////////////////

    function testDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(duckEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DuckEngine.DuckEngine_CantBeZero.selector);
        duckEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
