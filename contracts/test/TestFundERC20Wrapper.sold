// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/FundERC20Wrapper.sol";

contract TestFundERC20Wrapper is FundERC20Wrapper {

    address private _owner;

    constructor(string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }

    function mint(address account, uint256 amount) public virtual onlyOwner {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) public virtual onlyOwner {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function setRedeemingBalances(address account, uint256 amount) public {
        _redeemingBalances[account] = amount;
    }
}