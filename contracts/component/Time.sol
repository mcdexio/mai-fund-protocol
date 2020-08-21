// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

contract Time {
    function _now() internal view returns (uint256) {
        return block.timestamp;
    }
}