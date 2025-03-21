// SPDX-Liciense-Identifier: MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {DeployDuck} from "../../../script/DeployDuck.s.sol";
import {DuckEngine} from "../../../src/DuckEngine.sol";
import {DuckCoin} from "../../../src/DuckCoin.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";

contract DuckEngineTest is Test {
    DeployDuck deployer;
    DuckEngine duckEngine;
    DuckCoin duckCoin;
    HelperConfig helperConfig;

    /*-------------- Variable Declaration -------------------*/
    adddresss ethUsdPriceFeed;
    adddresss wbtcUsdPriceFeed;
    adddresss weth;
    adddresss wbtc;

    function setUp() public {
        deployer = new DeployDuck();
        (duckEngine, duckCoin, helperConfig) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 1e18;
        uint256 wbtcAmount = 1e8;
        uint256 ethUsdValue = duckEngine.getUsdValue(weth, ethAmount);
        uint256 wbtcUsdValue = duckEngine.getUsdValue(wbtc, wbtcAmount);
        assertEq(ethUsdValue, 2000e18);
        assertEq(wbtcUsdValue, 1000e8);
    }
}
