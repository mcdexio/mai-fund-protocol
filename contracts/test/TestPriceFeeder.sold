// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

contract TestPriceFeeder {
    uint256 public latestAnswer;
    uint256 public latestTimestamp;

    function setPrice(uint256 newPrice, uint256 newTimestamp) public {
        latestAnswer = newPrice;
        latestTimestamp = newTimestamp;
    }

    function price() public view returns (uint256 newPrice, uint256 newTimestamp) {
        newPrice = latestAnswer;
        newTimestamp = latestTimestamp;
    }
}

