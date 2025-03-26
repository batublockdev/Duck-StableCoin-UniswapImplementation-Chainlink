// SPDX-Liciense-Identifier: MIT
pragma solidity ^0.8.18;
import {Test, console2} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {DeployDuck} from "../../script/DeployDuck.s.sol";
import {DuckEngine} from "../../src/DuckEngine.sol";
import {DuckCoin} from "../../src/DuckCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

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
    address public USERX = makeAddr("userx");

    uint256 public constant AMOUNT_MINT = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_MINT_DUCK = 10000 ether;
    int256 public constant ETH_USD_PRICE = 18e8;

    function setUp() public {
        deployer = new DeployDuck();
        (duckEngine, duckCoin, helperConfig) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
        ERC20Mock(weth).mint(USER, AMOUNT_MINT);
    }

    modifier deposit() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(duckEngine), AMOUNT_MINT);
        duckEngine.depositCollateralandMintDuckCoin(
            weth,
            AMOUNT_COLLATERAL,
            AMOUNT_MINT_DUCK
        );
        vm.stopPrank();
        _;
    }

    //////////////////////////////
    /////   CONSTRUCTOR       /////
    //////////////////////////////

    function testDuckEngine_CollateralLenghtAndPricesFeedsMustBeEqual() public {
        vm.startPrank(USER);
        address[] memory collateralAssets = new address[](1);
        address[] memory priceFeeds = new address[](2);
        vm.expectRevert(
            DuckEngine
                .DuckEngine_CollateralLenghtAndPricesFeedsMustBeEqual
                .selector
        );
        DuckEngine duckEngine = new DuckEngine(
            collateralAssets,
            priceFeeds,
            address(duckCoin)
        );
        vm.stopPrank();
    }

    //////////////////////////////
    /////   Price Test       /////
    //////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 10 ether;
        // 12e18 * 2000e18 = 24000e18
        // 10 ether * 2000e18 = 20000e18usd
        uint256 expectedEthUsdValue = 20000e18;
        uint256 ethUsdValue = duckEngine.getPriceUsd(weth, ethAmount);
        assertEq(ethUsdValue, expectedEthUsdValue);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 24000e18;
        // 24000e18 / 2000e18 = 12e18
        uint256 expectedEthAmount = 12e18;
        uint256 ethAmount = duckEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(ethAmount, expectedEthAmount);
    }

    //////////////////////////////
    /////   Deposit and mint /////
    //////////////////////////////

    function testDepositAndMint() public deposit {
        (uint256 debt, uint256 collateral) = duckEngine.getAccountInfoUser(
            USER
        );
        assertEq(collateral, duckEngine.getPriceUsd(weth, AMOUNT_COLLATERAL));
        assertEq(debt, AMOUNT_MINT_DUCK);
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

    function testDuckEngine_CollateralNotSupported() public {
        vm.startPrank(USER);
        ERC20Mock grasa = new ERC20Mock(
            "GRASA",
            "GRASA",
            msg.sender,
            AMOUNT_MINT
        );

        ERC20Mock(grasa).approve(address(duckEngine), AMOUNT_MINT);
        vm.expectRevert(DuckEngine.DuckEngine_CollateralNotSupported.selector);
        duckEngine.depositCollateral(address(grasa), AMOUNT_MINT);
        vm.stopPrank();
    }

    function testGetinfoUser() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(duckEngine), AMOUNT_MINT);
        duckEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        (uint256 debt, uint256 collateral) = duckEngine.getAccountInfoUser(
            USER
        );

        assertEq(collateral, duckEngine.getPriceUsd(weth, AMOUNT_COLLATERAL));
        assertEq(debt, 0);
    }

    //////////////////////////////
    /////   REDEEM C        /////
    //////////////////////////////

    function testredeemCollateralAndBurnDuckCoin() public deposit {
        vm.startPrank(USER);
        duckCoin.approve(address(duckEngine), AMOUNT_MINT_DUCK);
        duckEngine.redeemCollateralAndBurnDuckCoin(
            weth,
            AMOUNT_COLLATERAL,
            AMOUNT_MINT_DUCK
        );
        vm.stopPrank();
        (uint256 debt, uint256 collateral) = duckEngine.getAccountInfoUser(
            USER
        );
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function testredeemCollateralandburnDuckCoin() public deposit {
        vm.startPrank(USER);
        duckCoin.approve(address(duckEngine), AMOUNT_MINT_DUCK);
        duckEngine.burnDuckCoin(AMOUNT_MINT_DUCK);
        duckEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        (uint256 debt, uint256 collateral) = duckEngine.getAccountInfoUser(
            USER
        );
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    //////////////////////////////
    /////   liquidate       /////
    //////////////////////////////

    function testLiquidate() public deposit {
        uint256 heatlhx1 = duckEngine.getHealthFactor(USER);
        console2.log("helath factor: ", heatlhx1);
        (uint256 debt, uint256 collateral) = duckEngine.getAccountInfoUser(
            USER
        );

        console2.log("Collateral: ", collateral);

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ETH_USD_PRICE);
        uint256 heatlh = duckEngine.getHealthFactor(USER);
        console2.log("helath factor: ", duckEngine.getHealthFactor(USER));
        if (heatlh < 1) {
            console2.log("Break: ", heatlh);
        }

        (, uint256 collateralx) = duckEngine.getAccountInfoUser(USER);
        console2.log("Collateral: ", collateralx);

        assertTrue(heatlhx1 != heatlh);

        vm.startPrank(USERX);
        ERC20Mock(weth).mint(USERX, AMOUNT_MINT);
        ERC20Mock(weth).approve(address(duckEngine), AMOUNT_MINT);
        duckEngine.depositCollateralandMintDuckCoin(
            weth,
            AMOUNT_MINT,
            30 ether
        );
        duckCoin.approve(address(duckEngine), 30 ether);
        vm.stopPrank();
        duckEngine.liquidate(address(weth), USER, 30 ether);
        console2.log("helath factor: ", duckEngine.getHealthFactor(USER));
    }
}
