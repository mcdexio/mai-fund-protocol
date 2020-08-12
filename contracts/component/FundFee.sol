// SPDX-License-Identifier: UNLICENSED
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
     * @notice  Calculate purchase fee. nav * amount * feerate
     * @param   purchasedAssetValue   Total asset value to purchase.
     * @return  Amount of purchase fee.
     */
    function _entranceFee(uint256 purchasedAssetValue)
        internal
        view
        virtual
        returns (uint256)
    {
        if (_entranceFeeRate == 0) {
            return 0;
        }
        return purchasedAssetValue.wmul(_entranceFeeRate);
    }

    /**
     * @notice  Claim streaming fee.
     * @dev     Assume that 1 year == 365 day
     * @param   netAssetValue   Total asset value.
     * @return  Amount of streaming fee.
     */
    function _streamingFee(uint256 netAssetValue)
        internal
        view
        virtual
        returns (uint256)
    {
        // _lastFeeTime == 0 => no initial checkpoint. fee = 0
        if (_lastFeeTime == 0 || _streamingFeeRate == 0) {
            return 0;
        }
        uint256 feePerYear = netAssetValue.wmul(_streamingFeeRate);
        uint256 timeElapsed = LibUtils.currentTime().sub(_lastFeeTime);
        return feePerYear.wfrac(timeElapsed, LibConstant.SECONDS_PER_YEAR);
    }

    /**
     * @notice  Calculate performance fee. mature part and immature part are calculated separately.
     * @param   netAssetValue   Amount of total asset value, streaming fee excluded.
     * @return  Amount of performance fee.
     */
    function _performanceFee(uint256 netAssetValue)
        internal
        view
        virtual
        returns (uint256)
    {
        if (_performanceFeeRate == 0) {
            return 0;
        }
        uint256 maxAssetValue = _maxNetAssetValuePerShare.wmul(_totalSupply);
        if (netAssetValue <= maxAssetValue) {
            return 0;
        }
        return netAssetValue.sub(maxAssetValue).wmul(_performanceFeeRate);
    }

    /**
     * @notice  Update fee state, make a checkpoint for next fee.
     * @param   fee                   Amount of Fee.
     * @param   netAssetValuePerShare Value of net asset.
     */
    function _updateFeeState(uint256 fee, uint256 netAssetValuePerShare)
        internal
    {
        if (netAssetValuePerShare > _maxNetAssetValuePerShare) {
            _maxNetAssetValuePerShare = netAssetValuePerShare;
        }
        _totalFeeClaimed = _totalFeeClaimed.add(fee);
        _lastFeeTime = LibUtils.currentTime();
    }
}