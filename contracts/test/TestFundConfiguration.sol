// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/FundConfiguration.sol";

contract TestFundConfiguration is FundConfiguration {

    function setRedeemingLockPeriodPublic(uint256 period)
        public
    {
        setRedeemingLockPeriod(period);
    }

    function setDrawdownHighWaterMarkPublic(uint256 hwm)
        public
    {
        setDrawdownHighWaterMark(hwm);
    }

    function setLeverageHighWaterMarkPublic(uint256 hwm)
        public
    {
        setLeverageHighWaterMark(hwm);
    }

    function setEntranceFeeRatePublic(uint256 newRate)
        public
    {
        setEntranceFeeRate(newRate);
    }

    function setStreamingFeeRatePublic(uint256 newRate)
        public
    {
        setStreamingFeeRate(newRate);
    }

    function setPerformanceFeeRatePublic(uint256 newRate)
        public
    {
        setPerformanceFeeRate(newRate);
    }
}
