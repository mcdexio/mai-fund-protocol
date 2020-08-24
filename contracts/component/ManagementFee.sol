// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";
import "./Context.sol";
import "./ERC20Tradable.sol";

contract ManagementFee is Context, ERC20Tradable {

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
     * @notice  Set entrance/streaming/performance fee rete.
     * @param   entranceFeeRate     Rate of entrance fee. 0 < rate <= 100%
     * @param   streamingFeeRate    Rate of streaming fee. 0 < rate <= 100%
     * @param   performanceFeeRate  Rate of performance fee. 0 < rate <= 100%
     */
    function _setFeeRates(
        uint256 entranceFeeRate,
        uint256 streamingFeeRate,
        uint256 performanceFeeRate
    )
        internal
    {
        require(newRatentranceFeeRatee <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        require(streamingFeeRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        require(performanceFeeRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _entranceFeeRate = entranceFeeRate;
        _streamingFeeRate = streamingFeeRate;
        _performanceFeeRate = performanceFeeRate;
        emit SetFeeRates(entranceFeeRate, streamingFeeRate, performanceFeeRate);
    }

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
        uint256 timeElapsed = _now().sub(_lastFeeTime);
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
        uint256 maxAssetValue = _maxNetAssetValuePerShare.wmul(totalSupply());
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
        _lastFeeTime = _now();
    }
}