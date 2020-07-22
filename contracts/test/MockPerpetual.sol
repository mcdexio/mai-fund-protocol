// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../lib/LibTypes.sol";

contract MockPerpetual {

    uint256 internal _margin;
    uint256 internal _markPrice;
    int256 internal _marginBalance;
    LibTypes.MarginAccount internal _marginAccount;

    function deposit(uint256 amount) external payable {

    }

    function withdraw(uint256 amount) external {

    }

    function setMarginAccount(LibTypes.MarginAccount memory marginAccount) external {
        _marginAccount = marginAccount;
    }

    function getMarginAccount(address) external view returns (LibTypes.MarginAccount memory) {
        return _marginAccount;
    }

    function setPositionMargin(uint256 margin) external {
        _margin = margin;
    }

    function positionMargin(address) external view returns (uint256) {
        return _margin;
    }

    function setMarginBalance(int256 marginBalance) external {
        _marginBalance = marginBalance;
    }

    function marginBalance(address) external returns (int256) {
        return _marginBalance;
    }

    function setMarkPrice(uint256 markPrice) external {
        _markPrice = markPrice;
    }

    function markPrice() external view returns (uint256) {
        return _markPrice;
    }

    function tradePosition(address, address, LibTypes.Side, uint256, uint256)
        external
        returns (uint256, uint256)
    {
        return (0, 0);
    }

}