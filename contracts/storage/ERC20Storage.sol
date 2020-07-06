// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

contract ERC20Storage {
    // ERC20
    string internal _name;
    string internal _symbol;
    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping (address => uint256)) internal _allowances;
}