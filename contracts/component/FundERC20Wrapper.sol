// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../storage/FundStorage.sol";
import "./FundAccount.sol";

/**
 * @notice Implemetation of ERC20 interfaces.
 */
contract FundERC20Wrapper is FundStorage, FundAccount, IERC20 {
    using SafeMath for uint256;

    // using fixed decimals 18
    uint8 constant private ERC20_DECIMALS = 18;

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public pure virtual returns (uint8) {
        return ERC20_DECIMALS;
    }

    function balanceOf(address account) public view override virtual returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view override virtual returns (uint256) {
        return _totalSupply;
    }

    // code below comes from ERC20 by openzepplin
    // "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance")
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero")
        );
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    // end of ERC20 by openzepplin


    /**
     * @dev Amount which is transferrable
     */
    function _transferrableBalance(address account) internal view returns (uint256) {
        return _redeemableShareBalance(account);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount <= _transferrableBalance(sender), "ERC20: insufficient fund to transfer");

        _decreaseShareBalance(sender, amount);
        _increaseShareBalance(recipient, amount);

        emit Transfer(sender, recipient, amount);
    }
}