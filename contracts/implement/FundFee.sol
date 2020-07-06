// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";
import "../lib/LibUtils.sol";

import "../storage/FundStorage.sol";

contract FundFee is FundStorage {

    using SafeMath for uint256;
    using LibMathEx for uint256;

    /**
     * @dev calculate purchase fee.
     * @param purchasedAssetValue   Total asset value to purchase.
     * @return Amount of purchase fee.
     */
    function calculateEntranceFee(uint256 purchasedAssetValue) internal view returns (uint256) {
        if (_entranceFeeRate == 0) {
            return 0;
        }
        return purchasedAssetValue.wmul(_entranceFeeRate);
    }

    /**
     * @dev Claim streaming fee.
     * @param totalAssetValue   Total asset value.
     * @return Amount of streaming fee.
     */
    function calculateStreamingFee(uint256 totalAssetValue) internal view returns (uint256) {
        if (_streamingFeeRate == 0) {
            return 0;
        }
        // time since last claiming
        uint256 feeRate = LibUtils.annualizedFeeRate(_streamingFeeRate, _lastPassiveClaimingTime);
        return totalAssetValue.wmul(feeRate);
    }

    /**
     * @dev Calculate performance fee. mature part and immature part are calculated separately.
     * @param totalAssetValue   Amount of total asset value, streaming fee excluded.
     * @return Amount of performance fee.
     */
    function calculatePerformanceFee(uint256 totalAssetValue) internal view returns (uint256) {
        if (_performanceFeeRate == 0) {
            return 0;
        }
        uint256 maxTotalAssetValue = _maxNetAssetValue.wmul(_totalSupply);
        if (totalAssetValue <= maxTotalAssetValue) {
            return 0;
        }
        return totalAssetValue.sub(maxTotalAssetValue).wmul(_performanceFeeRate);
    }

    /**
     * @dev Update fee state, make a checkpoint.
     * @param fee           Amount of Fee.
     * @param netAssetValue Value of net asset.
     */
    function updateFeeState(uint256 fee, uint256 netAssetValue) internal {
        if (netAssetValue > _maxNetAssetValue) {
            _maxNetAssetValue = netAssetValue;
        }
        _totalFeeClaimed = _totalFeeClaimed.add(fee);
        if (msg.sender == _maintainer) {
            _lastActiveClaimingTime = LibUtils.currentTime();
        } else {
            _lastPassiveClaimingTime = LibUtils.currentTime();
        }
    }
}