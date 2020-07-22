// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../trader/robot/strategy/RSITrendingStrategy.sol";

contract TestRSITrendingStrategy is RSITrendingStrategy {

    uint256 internal _timestamp;

    constructor(
        address priceReader,
        uint256 period,
        uint256 numPeriod,
        uint256[] memory seperators,
        InputTargetEntry[] memory transferEntries
    )
        public
        RSITrendingStrategy(priceReader, period, numPeriod, seperators, transferEntries)
    {

    }

    function setTimestamp(uint256 newTimestamp) external {
        _timestamp = newTimestamp;
    }

    function timestamp() internal virtual override view returns (uint256) {
        return _timestamp;
    }

    function lastSegment() external view returns (uint256) {
        return _lastSegment;
    }

    function getSegment() external view returns (uint256) {
        uint256 rsi = getCurrentRSI();
        uint256 segment = _seperators.length;
        for (uint256 i = 0; i < _seperators.length; i++) {
            if (rsi < _seperators[i]) {
                segment = i;
                break;
            }
        }
        return segment;
    }

}