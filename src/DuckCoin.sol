// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title DuckCoin
 * @author batublockchain
 * @dev DuckCoin ERC20 Token which is a decentralized stablecoin pegged to the value of USD.
 * Collateralized by a basket of assets including USDC, WBTC, and WETH.
 * Minted and redeemed by the DuckDAO community.
 * Relative stability pegged to the value of USD.
 *
 * This contract is mean to be governed by the DuckEngine contract.
 *
 *
 */

contract DuckCoin is ERC20Burnable, Ownable {
    /*Erros*/
    error DuckCoin_MustBeMoreThanZero();
    error DuckCoin_BurnAmountExceedsBalace();
    error DuckCoin_AddressCantBeZero();

    constructor() ERC20("DuckCoin", "DUCK") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DuckCoin_MustBeMoreThanZero();
        }
        if (_amount > balance) {
            revert DuckCoin_BurnAmountExceedsBalace();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DuckCoin_AddressCantBeZero();
        }
        if (_amount <= 0) {
            revert DuckCoin_MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
