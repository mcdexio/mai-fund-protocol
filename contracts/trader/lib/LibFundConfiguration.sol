pragma solidity 0.6.10;

library LibFundConfiguration {
    struct FundConfiguration {
        uint256 withdrawPeriod;
        uint256 feeClaimingPeriod;
        uint256 entranceFeeRate;
        uint256 streamingFeeRate;
        uint256 performanceFeeRate;
    }

    function initialize(FundConfiguration storage configuration, bytes calldata initialConfiguration)
        internal
    {
        (
            uint256 withdrawPeriod,
            uint256 feeClaimingPeriod,
            uint256 entranceFeeRate,
            uint256 streamingFeeRate,
            uint256 performanceFeeRate,
            uint256 redeemingDelay
        ) = abi.decode(initialConfiguration, (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        ));
        seFeeClaimingPeriod(configuration, feeClaimingPeriod);
        setWithdrawPeriod(configuration, withdrawPeriod);
        setEntranceFeeRate(configuration, entranceFeeRate)
        setStreamingFeeRate(configuration, streamingFeeRate);
        setPerformanceFeeRate(configuration, performanceFeeRate);
    }

    function setWithdrawPeriod(FundConfiguration storage configuration, uint256 period) internal {
        configuration.withdrawPeriod = period;
    }

    function seFeeClaimingPeriod(FundConfiguration storage configuration, uint256 period) internal {
        configuration.feeClaimingPeriod = period;
    }

    function setEntranceFeeRate(FundConfiguration storage configuration, uint256 newRate) internal {
        require(newRate < 10**18 * 100, "streaming fee rate must be less than 100%");
        configuration.entranceFeeRate = newRate;
    }

    function setStreamingFeeRate(FundConfiguration storage configuration, uint256 newRate) internal {
        require(newRate < 10**18 * 100, "streaming fee rate must be less than 100%");
        configuration.entranceFeeRate = newRate;
    }

    function setPerformanceFeeRate(FundConfiguration storage configuration, uint256 newRate) internal {
        require(newRate < 10**18 * 100, "performance fee rate must be less than 100%");
        configuration.performanceFeeRate = newRate;
    }
}