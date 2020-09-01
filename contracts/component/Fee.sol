// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";
import "./Context.sol";
import "./ERC20CappedRedeemable.sol";

/**
 * @title   Fee calculator and status updater.
 */
contract Fee is Context, ERC20CappedRedeemable {

    using SafeMath for uint256;
    using LibMathEx for uint256;

    uint256 internal _totalFeeClaimed;
    uint256 internal _maxNetAssetValuePerShare;
    uint256 internal _lastFeeTime;
    uint256 internal _entranceFeeRate;
    uint256 internal _streamingFeeRate;
    uint256 internal _performanceFeeRate;

    event SetFeeRates(
        uint256 entranceFeeRate,
        uint256 streamingFeeRate,
        uint256 performanceFeeRate
    );

    /**
     * @dev     Set entrance fee rete.
     * @param   newRate Rate of entrance fee. 0 < rate <= 100%
     */
    function _setEntranceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "too large rate");
        _entranceFeeRate = newRate;
    }

    /**
     * @dev     Set streaming fee rete.
     * @param   newRate Rate of streaming fee. 0 < rate <= 100%
     */
    function _setStreamingFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "too large rate");
        _streamingFeeRate = newRate;
    }

    /**
     * @dev     Set performance fee rete.
     * @param   newRate Rate of performance fee. 0 < rate <= 100%
     */
    function _setPerformanceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "too large rate");
        _performanceFeeRate = newRate;
    }

    /**
     * @dev     Calculate purchase fee. nav * amount * feerate
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
        return purchasedAssetValue.wfrac(_entranceFeeRate, LibConstant.UNSIGNED_ONE.add(_entranceFeeRate));
    }

    /**
     * @dev     Claim streaming fee. Assume that 1 year == 365 day
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
        uint256 timeElapsed = _now().sub(_lastFeeTime);
        return feePerYear.wfrac(timeElapsed, LibConstant.SECONDS_PER_YEAR);
    }

    /**
     * @dev     Calculate performance fee. mature part and immature part are calculated separately.
     * @param   netAssetValue   Amount of total asset value, streaming fee excluded.
     * @return  Amount of performance fee.
     */
    function _performanceFee(uint256 netAssetValue, uint256 totalSupply)
        internal
        view
        virtual
        returns (uint256)
    {
        if (_performanceFeeRate == 0) {
            return 0;
        }
        uint256 _maxNetAssetValue = _maxNetAssetValuePerShare.wmul(totalSupply);
        if (netAssetValue <= _maxNetAssetValue) {
            return 0;
        }
        return netAssetValue.sub(_maxNetAssetValue).wmul(_performanceFeeRate);
    }

    /**
     * @dev     Update fee amount.
     * @param   fee Amount of Fee.
     */
    function _updateFee(uint256 fee)
        internal
        returns (uint256)
    {
        _totalFeeClaimed = _totalFeeClaimed.add(fee);
        _lastFeeTime = _now();
        return _totalFeeClaimed;
    }

    /**
     * @dev     Update max asset value per share, for drawdown and performance fee calculating.
     * @param   netAssetValue   Value of net asset.
     * @param   totalSupply     Value of net asset.
     */
    function _updateMaxNetAssetValuePerShare(uint256 netAssetValue, uint256 totalSupply)
        internal
    {
        if (totalSupply == 0) {
            return;
        }
        uint256 netAssetValuePerShare = netAssetValue.wdiv(totalSupply);
        if (netAssetValuePerShare > _maxNetAssetValuePerShare) {
            _maxNetAssetValuePerShare = netAssetValuePerShare;
        }
    }

    uint256[14] private __gap;
}