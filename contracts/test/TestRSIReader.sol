// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../trader/robot/strategy/RSIReader.sol";

contract TestRSIReader is RSIReader {

    uint256 internal _timestamp;

    constructor(address priceSeriesRetriever, uint256 period, uint256 numPeriod)
        public
        RSIReader(priceSeriesRetriever, period, numPeriod)
    {
    }

    function setTimestamp(uint256 newTimestamp) external {
        _timestamp = newTimestamp;
    }

    function retrieveData() external view returns (uint256[] memory) {
        return _priceSeriesRetriever.retrievePriceSeries(
            _period,
            timestamp().sub(_totalPeriod),
            timestamp()
        );
    }

    function timestamp() internal virtual override view returns (uint256) {
        return _timestamp;
    }
}