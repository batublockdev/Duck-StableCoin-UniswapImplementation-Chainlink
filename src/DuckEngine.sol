// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
pragma solidity ^0.8.19;

/**
 * @title DuckEngine
 * @author BatuBlockchain
 *
 * The DuckEngine contract is the governance contract for the DuckCoin stablecoin.
 * It is responsible for managing the minting and burning of DuckCoin tokens.
 * It is also responsible for managing the collateral assets that back the DuckCoin stablecoin.
 * The collateral assets include USDC, WBTC, and WETH.
 *
 * StableCoin Peg: 1 DUCK = 1 USD
 *
 * Properties:
 * -Exogenous Collateral: USDC, WBTC, WETH
 * -Dollar Peg
 * -Algorithmic Stability
 *
 * this sytem control the stability of the DuckCoin stablecoin by overcollateralizing
 * the DuckCoin stablecoin with the exogenous collateral assets
 * and swapping the collateral assets to maintain the peg.
 *
 * @notice this contract is the core of the DuckCoin stablecoin system.
 */

//////////////////////////////
/////   imports           /////
//////////////////////////////

//DuckCoin Stablecoin Contract
import {DuckCoin} from "./DuckCoin.sol";

// Chainlink Aggregator Interface
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

// Uniswap V3 Router Interface
import {ISwapRouter} from "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// ERC20 Token Standard from OpenZeppelin
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Chainlink Automation Interface
import {AutomationCompatibleInterface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract DuckEngine is AutomationCompatibleInterface, ReentrancyGuard {
    //////////////////////////////
    /////   Error Messages   /////
    //////////////////////////////

    error DuckEngine_CantBeZero();
    error DuckEngine_CollateralLenghtAndPricesFeedsMustBeEqual();
    error DuckEngine_CollateralNotSupported();
    error DuckEngine_FaildToTransferCollateral();
    error DuckEngine_BreaksHelthFactor(uint256 healthFactor);
    error DuckEngine_FaildToMint();

    //////////////////////////////
    /////   Variables       /////
    //////////////////////////////

    mapping(address token => address priceFeed) private collateralPrices;
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralAssets;
    mapping(address user => uint256 amount) private s_duckCoinBalances;
    address[] private s_collateralAssets;

    uint256 private constant ADITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRICE_PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECITION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    DuckCoin private immutable i_duckCoin;

    //////////////////////////////
    /////   Modifier        /////
    //////////////////////////////

    modifier notZero(uint256 _amount) {
        if (_amount == 0) {
            revert DuckEngine_CantBeZero();
        }
        _;
    }
    modifier isAllowedCollateral(address _collateral) {
        if (collateralPrices[_collateral] != address(0)) {
            revert DuckEngine_CollateralNotSupported();
        }
    }
    //////////////////////////////
    /////   EVENTS          /////
    //////////////////////////////

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    //////////////////////////////
    /////   Funtions        /////
    //////////////////////////////

    constructor(
        address[] memory _collateralAssets,
        address memory _pricesFeedsAddress,
        address _duckCoin
    ) {
        if (_collateralAssets.length != _pricesFeedsAddress.length) {
            revert DuckEngine_CollateralLenghtAndPricesFeedsMustBeEqual();
        }
        for (uint256 i = 0; i < _collateralAssets.length; i++) {
            collateralPrices[_collateralAssets[i]] = _pricesFeedsAddress[i];
            s_collateralAssets.push(_collateralAssets[i]);
        }
        i_duckCoin = DuckCoin(_duckCoin);
    }

    address private constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564; // Polygon Uniswap V3 Router
    ISwapRouter private constant swapRouter = ISwapRouter(UNISWAP_V3_ROUTER);

    address private constant WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6; // Polygon WBTC
    address private constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // Polygon WETH
    address private constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // Polygon USDC
    uint24 private constant POOL_FEE = 3000; // 0.3% fee tier

    function swapToUSDC(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin
    ) external {
        require(tokenIn == WBTC || tokenIn == WETH, "Invalid token");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: USDC,
                fee: POOL_FEE,
                recipient: msg.sender,
                deadline: block.timestamp + 15,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });

        swapRouter.exactInputSingle(params);
    }

    int public priceThreshold = 2000 * 10 ** 8; // 2000 USDC per WETH

    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        int currentPrice = getPrice();
        upkeepNeeded = currentPrice >= priceThreshold;
    }

    function performUpkeep(bytes calldata) external override {
        executeSwap(1 ether, 1900 * 10 ** 6);
    }

    /*------------------------------------------------------*/

    /**
     *
     * @param token the address of the token to be used as collateral
     * @param amount the amount of the token to be deposited as collateral
     */
    function depositCollateral(
        address token,
        uint256 amount
    ) external notZero(amount) isAllowedCollateral(token) nonReentrant {
        s_collateralAssets[msg.sender][token] += amount;
        emit CollateralDeposited(msg.sender, token, amount);
        bool sucess = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!sucess) {
            revert DuckEngine_FaildToTransferCollateral();
        }
    }

    /**
     * @notice follows CEI
     * @param amount the amount of DuckCoin to be minted
     * @dev to mint DuckCoin, the user must have collateral assets deposited
     */

    function mintDuckCoin(
        uint256 amount
    ) external notZero(amount) nonReentrant {
        s_duckCoinBalances[msg.sender] += amount;
        _revetIfHealthFactorBelowThreshold(msg.sender);
        bool sucess = i_duckCoin.mint(msg.sender, amount);
        if (!sucess) {
            revert DuckEngine_FaildToMint();
        }
    }

    function _getUserInformation(
        address user
    ) internal view returns (uint256, uint256) {
        return (s_duckCoinBalances[user], getCollateralValue(user));
    }

    /**
     * @notice follows CEI
     * @param adddress user to get the health factor
     * @return the health factor of the user, if the health factor is below 1 the user is liquid
     *
     */
    function getHealthFactor(address user) external view returns (uint256) {
        (
            uint256 duckCoinBalance,
            uint256 collateralValueInUSD
        ) = _getUserInformation(user);
        uint256 collateralAjustedForThreshold = (collateralValueInUSD *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECITION;
        return
            (collateralAjustedForThreshold * PRICE_PRECISION) / duckCoinBalance;
    }

    /**
     * @notice follows CEI
     * @param user to check if the health factor is below the 1 otherwise revert
     */
    function _revetIfHealthFactorBelowThreshold(address user) internal {
        uint256 healthFactor = getHealthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DuckEngine_BreaksHelthFactor(healthFactor);
        }
    }

    /**
     * @notice follows CEI
     * @param adresss token to get the price in USD
     * @param amount the amount of the token to get the price for
     * @return the price of the token in USD
     */
    function getPriceUsd(
        address token,
        uint256 amount
    ) external view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            collateralPrices[token]
        );
        (, int price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * ADITIONAL_FEED_PRECISION) * amount) /
            PRICE_PRECISION;
    }

    /**
     * @notice follows CEI
     * @param address user to get the total collateral value in USD
     * @return the total collateral value in USD
     */
    function getCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralValueInUSD = 0;
        for (uint256 i = 0; i < s_collateralAssets.length; i++) {
            address token = s_collateralAssets[i];
            uint256 amount = s_collateralAssets[user][token];
            totalCollateralValueInUSD += getPriceUsd(token, amount);
        }
        return totalCollateralValueInUSD;
    }
}
