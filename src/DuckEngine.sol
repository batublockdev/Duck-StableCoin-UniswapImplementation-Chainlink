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
 * The collateral assets include  WBTC, and WETH.
 *
 * StableCoin Peg: 1 DUCK = 1 USD
 *
 * Properties:
 * -Exogenous Collateral:  WBTC, WETH
 * -Dollar Peg
 * -Algorithmic Stability
 *
 * this sytem control the stability of the DuckCoin stablecoin by overcollateralizing
 * the DuckCoin stablecoin with the exogenous collateral assets
 * the system also uses the Chainlink price feeds to get the price of the collateral assets
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

// ERC20 Token Standard from OpenZeppelin
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DuckEngine is ReentrancyGuard {
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
        private s_user_collateralAssets;
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
        _;
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
        address[] memory _pricesFeedsAddress,
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

    /**
     * @dev we have the idea to control the liquidation procces by
     * swaping 100% the collateral assets to other stablecoin like USDC
     * and keeping the 20% of the collateral assets in the contract
     * to preper to the rebounce, this is planed to do using the Uniswap V3 Router or V2
     * and the stablecoin swaped will be invested in curve finance to get the best return
     * on top of that we will use the Chainlink Automation to automate the process
     * and to make the system more secure and trustable, checking the health factor
     * and the price of the collateral assets dayly or weekly
     */
    /**
     *
     * @param token the address of the token to be used as collateral
     * @param amount the amount of the token to be deposited as collateral
     */
    function depositCollateral(
        address token,
        uint256 amount
    ) external notZero(amount) isAllowedCollateral(token) nonReentrant {
        s_user_collateralAssets[msg.sender][token] += amount;
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
     * @param user user to get the health factor
     * @return  health factor of the user, if the health factor is below 1 the user is liquid
     *
     */
    function getHealthFactor(address user) public view returns (uint256) {
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
     * @param  token to get the price in USD
     * @param amount the amount of the token to get the price for
     * @return  price of the token in USD
     */
    function getPriceUsd(
        address token,
        uint256 amount
    ) public view returns (uint256) {
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
     * @param  user to get the total collateral value in USD
     * @return  total collateral value in USD
     */
    function getCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralValueInUSD = 0;
        for (uint256 i = 0; i < s_collateralAssets.length; i++) {
            address token = s_collateralAssets[i];
            uint256 amount = s_user_collateralAssets[user][token];
            totalCollateralValueInUSD += getPriceUsd(token, amount);
        }
        return totalCollateralValueInUSD;
    }
}
