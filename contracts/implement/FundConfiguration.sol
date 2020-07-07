// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/LibUtils.sol";
import "../storage/FundStorage.sol";

contract FundConfiguration is FundStorage {

    function setFeeClaimingPeriod(uint256 period) internal {
        _feeClaimingPeriod = period;
    }

    function setRedeemingLockdownPeriod(uint256 period) internal {
        _redeemingLockdownPeriod = period;
    }

    function setEntranceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _entranceFeeRate = newRate;
    }

    function setStreamingFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _entranceFeeRate = newRate;
    }

    function setPerformanceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "performance fee rate must be less than 100%");
        _performanceFeeRate = newRate;
    }
}