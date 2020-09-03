// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/Fee.sol";

contract TestFee is Fee {

    uint256 private _useless;

    constructor() public {
        __ERC20CappedRedeemable_init_unchained(1000e18);
    }

    function foo() external {
        _useless = _useless + 1;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function maxNetAssetValuePerShare() external view returns (uint256) {
        return _maxNetAssetValuePerShare;
    }

    function lastFeeTime() external view returns (uint256) {
        return _lastFeeTime;
    }

    function totalFeeClaimed() external view returns (uint256) {
        return _totalFeeClaimed;
    }

    function feeRates()
        external
        view
        returns (uint256, uint256, uint256)
    {
        return (_entranceFeeRate, _streamingFeeRate, _performanceFeeRate);
    }

    function setEntranceFeeRate(uint256 newRate)
        external
    {
        _setEntranceFeeRate(newRate);
    }

    function setStreamingFeeRate(uint256 newRate)
        external
    {
        _setStreamingFeeRate(newRate);
    }

    function setPerformanceFeeRate(uint256 newRate)
        external
    {
        _setPerformanceFeeRate(newRate);
    }

    function entranceFee(uint256 purchasedAssetValue) external view returns (uint256) {
        return _entranceFee(purchasedAssetValue);
    }

    function streamingFee(uint256 netAssetValue) external view returns (uint256 fee, uint256 timestamp) {
        return (_streamingFee(netAssetValue), now);
    }

    function performanceFee(uint256 netAssetValue) external view returns (uint256) {
        return _performanceFee(netAssetValue);
    }

    function updateFee(uint256 fee) external returns (uint256) {
        return _updateFee(fee);
    }

    function updateMaxNetAssetValuePerShare(uint256 netAssetValuePerShare) external {
        _updateMaxNetAssetValuePerShare(netAssetValuePerShare);
    }
}
