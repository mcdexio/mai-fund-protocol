// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/FundConfiguration.sol";

contract TestFundConfiguration is FundConfiguration {

    function setRedeemingLockPeriodPublic(uint256 period)
        public
    {
        _setRedeemingLockPeriod(period);
    }

    function setDrawdownHighWaterMarkPublic(uint256 hwm)
        public
    {
        _setDrawdownHighWaterMark(hwm);
    }

    function setLeverageHighWaterMarkPublic(uint256 hwm)
        public
    {
        _setLeverageHighWaterMark(hwm);
    }

    function setEntranceFeeRatePublic(uint256 newRate)
        public
    {
        _setEntranceFeeRate(newRate);
    }

    function setStreamingFeeRatePublic(uint256 newRate)
        public
    {
        _setStreamingFeeRate(newRate);
    }

    function setPerformanceFeeRatePublic(uint256 newRate)
        public
    {
        _setPerformanceFeeRate(newRate);
    }
}
