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
    address ethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployDuck();
        (duckEngine, duckCoin, helperConfig) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 12e18;
        // 12e18 * 2000e18 = 24000e18
        uint256 expectedEthUsdValue = 24000e18;
        uint256 ethUsdValue = duckEngine.getPriceUsd(weth, ethAmount);
        assertEq(ethUsdValue, expectedEthUsdValue);
    }
}
