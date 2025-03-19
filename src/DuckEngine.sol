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

// Uniswap V3 Router Interface
import {ISwapRouter} from "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// ERC20 Token Standard from OpenZeppelin
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Chainlink Automation Interface
import {AutomationCompatibleInterface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract UniswapSwapper {
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
}
