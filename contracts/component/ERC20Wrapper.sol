// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Capped.sol";

import "./Account.sol";

/**
 * @notice Implemetation of ERC20 interfaces.
 */
contract ERC20Wrapper is Initializable, ERC20CappedUpgradeSafe {
    using SafeMath for uint256;

    // using fixed decimals 18
    uint8 constant private FUND_SHARE_ERC20_DECIMALS = 18;

    function __ERC20Wrapper_init_unchained(uint256 cap)
        internal
        initializer
    {
        _setupDecimals(FUND_SHARE_ERC20_DECIMALS);
    }

    // function _beforeTokenTransfer(address from, address to, uint256 amount)
    //     internal
    //     virtual
    //     override
    // {
    //     super()._beforeTokenTransfer(from, to, amount);
    //     require(amount <= _redeemableShareBalance(from), "transfer amount exceeded");
    // }
}