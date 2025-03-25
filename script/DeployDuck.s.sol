// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {DuckEngine} from "../src/DuckEngine.sol";
import {DuckCoin} from "../src/DuckCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDuck is Script {
    address[] public collateralAssets;
    address[] public priceFeeds;

    function run() external returns (DuckEngine, DuckCoin, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        priceFeeds = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        collateralAssets = [weth, wbtc];

        vm.startBroadcast();
        DuckCoin duckCoin = new DuckCoin();
        DuckEngine duckEngine = new DuckEngine(
            collateralAssets,
            priceFeeds,
            address(duckCoin)
        );
        duckCoin.transferOwnership(address(duckEngine));
        vm.stopBroadcast();
        return (duckEngine, duckCoin, helperConfig);
    }
}
