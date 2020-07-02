// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "./FundOperation.sol";
import "./ERC20Wrapper.sol";

contract FundBase is FundOperation, ERC20Wrapper {
    // using fixed decimals 18
    uint8 constant private DECIMALS = 18;

    function name() public view override virtual returns (string memory) {
        return _core.name;
    }

    function symbol() public view override virtual returns (string memory) {
        return _core.symbol;
    }

    function decimals() public view override virtual returns (uint8) {
        return DECIMALS;
    }

    function balanceOf(address account) public view override virtual returns (uint256) {
        return _core.accounts[account].shareBalance;
    }

    function totalSupply() public view override virtual returns (uint256) {
        return _core.shareTotalSupply;
    }

    function _transferShare(address sender, address recipient, uint256 amount) internal override virtual {

    }
}