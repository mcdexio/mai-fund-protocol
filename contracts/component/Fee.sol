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

    uint256 internal _totalFeeClaimable;
    uint256 internal _historicMaxNetAssetValuePerShare;
    uint256 internal _lastFeeTime;
    uint256 internal _entranceFeeRate;
    uint256 internal _streamingFeeRate;
    uint256 internal _performanceFeeRate;

    /**
     * @dev     Set entrance fee rate.
     * @param   newRate Rate of entrance fee. 0 < rate <= 100%
     */
    function _setEntranceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "rate too large");
        _entranceFeeRate = newRate;
    }

    /**
     * @dev     Set streaming fee rate.
     * @param   newRate Rate of streaming fee. 0 < rate <= 100%
     */
    function _setStreamingFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "rate too large");
        _streamingFeeRate = newRate;
    }

    /**
     * @dev     Set performance fee rate.
     * @param   newRate Rate of performance fee. 0 < rate <= 100%
     */
    function _setPerformanceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "rate too large");
        _performanceFeeRate = newRate;
    }

    /**
     * @dev     Calculate purchase fee. nav * amount * feerate
     * @param   collateralAmount   Total collateral spent for purchasing shares.
     * @return  Amount of purchase fee.
     */
    function _entranceFee(uint256 collateralAmount)
        internal
        view
        virtual
        returns (uint256)
    {
        if (_entranceFeeRate == 0) {
            return 0;
        }
        return collateralAmount.wfrac(
            _entranceFeeRate,
            LibConstant.UNSIGNED_ONE.add(_entranceFeeRate)
        );
    }

    /**
     * @dev     Claim streaming fee. Assume that 1 year == 365 days
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
     * @dev     Calculate performance fee. Return 0 if current nav is less then max nav since fund launched.
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
        uint256 _maxNetAssetValue = _historicMaxNetAssetValuePerShare.wmul(totalSupply());
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
    {
        _totalFeeClaimable = _totalFeeClaimable.add(fee);
        _lastFeeTime = _now();
    }

    /**
     * @dev     Update max asset value per share, for drawdown and performance fee calculating.
     * @param   netAssetValuePerShare   Value of net asset.
     */
    function _updateHistoricMaxNetAssetValuePerShare(uint256 netAssetValuePerShare)
        internal
    {
        if (netAssetValuePerShare > _historicMaxNetAssetValuePerShare) {
            _historicMaxNetAssetValuePerShare = netAssetValuePerShare;
        }
    }

    uint256[14] private __gap;
}