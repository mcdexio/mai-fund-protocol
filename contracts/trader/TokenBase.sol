pragma solidity 0.6.10;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Fund.sol";
import "../lib/LibOrderbook.sol";
import "../lib/LibFundStorage.sol";
import "../lib/LibFundCalculator.sol";

contract TokenBase is TraderBase, IERC20 {

    uint8 constant private DECIMALS = 18;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    function decimals() public view returns (uint8) {
        return DECIMALS;
    }

    function name() public view returns (string memory) {
        return _fundStorage.name;
    }

    function symbol() public view returns (string memory) {
        return _fundStorage.symbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _fundStorage.accounts[msg.sender].shareBalance;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _fundStorage.accounts[sender].transferShareBalance(_fundStorage.accounts[recipient], amount);

        emit Transfer(sender, recipient, amount);
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
}