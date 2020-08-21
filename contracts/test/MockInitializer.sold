// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

contract MockInitializer {
    address private _collateral;

    constructor(address collateral) public {
        _collateral = collateral;
    }

    function collateral() public view returns (address) {
        return _collateral;
    }
}