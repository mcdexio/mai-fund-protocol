// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../storage/FundStorage.sol";
import "../trader/FundBase.sol";
import "../trader/FundManagement.sol";

contract TestFund is
    FundStorage,
    FundBase,
    FundManagement
{
    address private _owner;

    constructor() public {
        _owner = msg.sender;
    }

    function administrator() public view override virtual returns (address) {
        return _owner;
    }
}