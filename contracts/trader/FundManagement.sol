// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../lib/LibConstant.sol";
import "../implement/FundConfiguration.sol";
import "../storage/FundStorage.sol";

interface IAdministration {
    function administrator() external view returns (address);
}

contract FundManagement is FundStorage, FundConfiguration {

    event SetConfigurationEntry(bytes32 key, bytes32 value);

    modifier onlyAdministrator() {
        require(msg.sender == IAdministration(_creator).administrator(), "caller must be the administrator");
        _;
    }

    function setConfigurationEntry(bytes32 key, bytes32 value) external onlyAdministrator {
        if (key == "feeClaimingPeriod") {
            setFeeClaimingPeriod(uint256(value));
        } else if (key == "redeemingLockdownPeriod") {
            setRedeemingLockdownPeriod(uint256(value));
        } else if (key == "entranceFeeRate") {
            setEntranceFeeRate(uint256(value));
        } else if (key == "streamingFeeRate") {
            setStreamingFeeRate(uint256(value));
        } else if (key == "performanceFeeRate") {
            setPerformanceFeeRate(uint256(value));
        } else {
            revert("unrecognized key");
        }
        emit SetConfigurationEntry(key, value);
    }

    /**
     * @dev Pause the fund.
     */
    function pause() external onlyAdministrator {
        _pause();
    }

    /**
     * @dev Unpause the fund.
     */
    function unpause() external onlyAdministrator {
        _unpause();
    }

    function shutdownOnMaxDrawdownReached() external onlyAdministrator {
        // uint256 netAssetValue = _core.getNetAssetValue();
        // uint256 maxNetAssetValue = _core.manager.maxNetAssetValue;
        // require(maxNetAssetValue > netAssetValue, "no drawdown");
        // require(
        //     maxNetAssetValue.sub(netAssetValue).wdiv(maxNetAssetValue) > _core.configuration.maxDrawdown,
        //     "max drawdown not reached"
        // );
        _shutdown();
    }

    function shutdown() external onlyAdministrator {
        _shutdown();
    }

    function _shutdown() internal {

    }
}