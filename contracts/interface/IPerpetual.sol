// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../external/LibTypes.sol";

interface IPerpetual {

    function getMarginAccount(address trader) external view returns (LibTypes.MarginAccount memory);

    function status() external view returns (LibTypes.Status);

    function paused() external view returns (bool);

    function withdrawDisabled() external view returns (bool);

    function globalConfig() external view returns (address);

    function collateral() external view returns (address);

    function markPrice() external returns (uint256);

    function marginBalance(address trader) external returns (int256);

    function availableMargin(address trader) external returns (int256);

    function positionMargin(address trader) external view returns (uint256);

    function isSafe(address trader) external returns (bool);

    function isSafeWithPrice(address trader, uint256 currentMarkPrice) external returns (bool);

    function isIMSafe(address trader) external returns (bool);

    function isIMSafeWithPrice(address trader, uint256 currentMarkPrice) external returns (bool);

    function tradePosition(
        address taker,
        address maker,
        LibTypes.Side side,
        uint256 price,
        uint256 amount
    ) external returns (uint256, uint256);

    function transferCashBalance(
        address from,
        address to,
        uint256 amount
    ) external;

    function depositFor(address trader, uint256 amount) external payable;

    function withdrawFor(address payable trader, uint256 amount) external;

    function isValidLotSize(uint256 amount) external view returns (bool);

    function isValidTradingLotSize(uint256 amount) external view returns (bool);
}
