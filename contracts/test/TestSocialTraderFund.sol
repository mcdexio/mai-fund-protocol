// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../fund/implement/SocialTraderFund.sol";

contract TestSocialTraderFund is SocialTraderFund {

    uint256 private _mockTimestamp;

    function setTimestamp(uint256 timestamp)
        external
    {
        _mockTimestamp = timestamp;
    }

    function _now()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (_mockTimestamp == 0) {
            return block.timestamp;
        }
        return _mockTimestamp ;
    }

}