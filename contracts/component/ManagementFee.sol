// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";
import "./ERC20Wrapper.sol";
import "./Stoppable.sol";
import "./Time.sol";

contract ManagementFee is Initializable, StoppableUpgradeSafe, ERC20Wrapper, Time {

    using SafeMath for uint256;
    using LibMathEx for uint256;

    uint256 private _totalFeeClaimed;
    uint256 private _maxNetAssetValuePerShare;
    uint256 private _lastFeeTime;
    uint256 private _entranceFeeRate;
    uint256 private _streamingFeeRate;
    uint256 private _performanceFeeRate;

    // Getters
    function totalFeeClaimed()
        public
        view
        returns (uint256)
    {
        return _totalFeeClaimed;
    }

    function maxNetAssetValuePerShare()
        public
        view
        returns (uint256)
    {
        return _maxNetAssetValuePerShare;
    }

    function lastFeeTime()
        public
        view
        returns (uint256)
    {
        return _lastFeeTime;
    }


    function entranceFeeRate() external view returns (uint256) {
        return _entranceFeeRate;
    }

    function streamingFeeRate() external view returns (uint256) {
        return _streamingFeeRate;
    }

    function performanceFeeRate() external view returns (uint256) {
        return _performanceFeeRate;
    }

    /**
     * @notice  Set entrance fee rete.
     * @param   newRate Rate of entrance fee. 0 < rate <= 100%
     */
    function _setEntranceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _entranceFeeRate = newRate;
    }

    /**
     * @notice  Set streaming fee rete.
     * @param   newRate Rate of streaming fee. 0 < rate <= 100%
     */
    function _setStreamingFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "streaming fee rate must be less than 100%");
        _streamingFeeRate = newRate;
    }

    /**
     * @notice  Set performance fee rete.
     * @param   newRate Rate of performance fee. 0 < rate <= 100%
     */
    function _setPerformanceFeeRate(uint256 newRate) internal {
        require(newRate <= LibConstant.RATE_UPPERBOUND, "performance fee rate must be less than 100%");
        _performanceFeeRate = newRate;
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
        if (stopped()) {
            return;
        }
        if (netAssetValuePerShare > _maxNetAssetValuePerShare) {
            _maxNetAssetValuePerShare = netAssetValuePerShare;
        }
        _totalFeeClaimed = _totalFeeClaimed.add(fee);
        _lastFeeTime = _now();
    }
}