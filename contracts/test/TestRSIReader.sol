// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../oracle/RSIReader.sol";

contract TestRSIReader is RSIReader {

    uint256 internal _mockTimestamp;

    constructor(address priceSeriesRetriever, uint256 period, uint256 numPeriod)
        public
        RSIReader(priceSeriesRetriever, period, numPeriod)
    {
    }

    function setTimestamp(uint256 newTimestamp) external {
        _mockTimestamp = newTimestamp;
    }

    function retrieveData() external view returns (uint256[] memory) {
        return _priceSeriesRetriever.retrievePriceSeries(
            _period,
            _now().sub(_totalPeriod),
            _now()
        );
    }

    function calculateRSI(uint256[] memory prices)
        external
        pure
        returns (uint256)
    {
        return _calculateRSI(prices);
    }

    function _now()
        internal
        virtual
        override
        view
        returns (uint256)
    {
        return _mockTimestamp;
    }
}