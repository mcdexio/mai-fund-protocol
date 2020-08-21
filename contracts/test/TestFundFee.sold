// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/FundFee.sol";
import "./TestFundConfiguration.sol";

contract TestFundFee is FundFee, TestFundConfiguration {

    uint256 private _useless;

    function foo() external {
        _useless = _useless + 1;
    }

    function setTotalSupply(uint256 totalSupply) external {
        _totalSupply = totalSupply;
    }

    function getEntranceFeePublic(uint256 purchasedAssetValue) external view returns (uint256) {
        return _entranceFee(purchasedAssetValue);
    }

    function getStreamingFeePublic(uint256 netAssetValue) external view returns (uint256 fee, uint256 timestamp) {
        return (_streamingFee(netAssetValue), now);
    }

    function getPerformanceFeePublic(uint256 netAssetValue) external view returns (uint256) {
        return _performanceFee(netAssetValue);
    }

    function updateFeeStatePublic(uint256 fee, uint256 netAssetValuePerShare) external returns (uint256) {
        _updateFeeState(fee, netAssetValuePerShare);
        return now;
    }

}
