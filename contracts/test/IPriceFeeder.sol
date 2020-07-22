// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

interface IPriceFeeder {

    function setPrice(int256 newPrice) external;

    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);

    function price() external view returns (uint256 newPrice, uint256 timestamp);

}
