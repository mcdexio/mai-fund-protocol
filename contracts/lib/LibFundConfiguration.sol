// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

library LibFundConfiguration {
    struct Configuration {
        uint256 withdrawPeriod;
        uint256 feeClaimingPeriod;
        uint256 minimalRedeemingPeriod;
        uint256 entranceFeeRate;
        uint256 streamingFeeRate;
        uint256 performanceFeeRate;
    }

    function initialize(Configuration storage configuration, uint256[] memory initialConfiguration)
        internal
    {
        require(initialConfiguration.length == 5, "incorrect num of initial configuration");
        // 0 ->
        seFeeClaimingPeriod(configuration, initialConfiguration[0]);
        setWithdrawPeriod(configuration, initialConfiguration[1]);
        setEntranceFeeRate(configuration, initialConfiguration[2]);
        setStreamingFeeRate(configuration, initialConfiguration[3]);
        setPerformanceFeeRate(configuration, initialConfiguration[4]);
    }

    function setWithdrawPeriod(Configuration storage configuration, uint256 period) internal {
        configuration.withdrawPeriod = period;
    }

    function seFeeClaimingPeriod(Configuration storage configuration, uint256 period) internal {
        configuration.feeClaimingPeriod = period;
    }

    function setEntranceFeeRate(Configuration storage configuration, uint256 newRate) internal {
        require(newRate < 10**18 * 100, "streaming fee rate must be less than 100%");
        configuration.entranceFeeRate = newRate;
    }

    function setStreamingFeeRate(Configuration storage configuration, uint256 newRate) internal {
        require(newRate < 10**18 * 100, "streaming fee rate must be less than 100%");
        configuration.entranceFeeRate = newRate;
    }

    function setPerformanceFeeRate(Configuration storage configuration, uint256 newRate) internal {
        require(newRate < 10**18 * 100, "performance fee rate must be less than 100%");
        configuration.performanceFeeRate = newRate;
    }
}