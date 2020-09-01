// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibTypes.sol";
import "../lib/LibMathEx.sol";

import "./ERC20Redeemable.sol";
import "./Fee.sol";
import "./MarginAccount.sol";

contract Status is ERC20Redeemable, Fee, MarginAccount {

    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;

    /**
     * @dev     Get net asset value.
     * @return  Net asset value.
     */
    function _netAssetValue()
        internal
        virtual
        returns (uint256)
    {
        // claimed fee excluded
        return _totalAssetValue().sub(_totalFeeClaimed, "total asset value less than fee");
    }

    /**
     * @dev     Get net asset value per share.
     * @return  Net asset value.
     */
    function _netAssetValuePerShare(uint256 netAssetValue)
        internal
        view
        virtual
        returns (uint256)
    {
        if (totalSupply() == 0 || netAssetValue == 0) {
            return 0;
        }
        return netAssetValue.wdiv(totalSupply());
    }

    /**
     * @dev     Get incremental management fee
     */
    function _managementFee(uint256 assetValue)
        internal
        view
        virtual
        returns (uint256)
    {
        uint256 streamingFee = _streamingFee(assetValue);
        assetValue = assetValue.sub(streamingFee);
        uint256 performanceFee = _performanceFee(assetValue, totalSupply());
        assetValue = assetValue.sub(performanceFee);
        return streamingFee.add(performanceFee);
    }

    /**
     * @dev     Get leverage, leverage = margin / (asset value - fee)
     * @return  Leverage of fund positon account.
     */
    function _leverage(uint256 netAssetValue)
        internal
        virtual
        returns (int256)
    {
        LibTypes.MarginAccount memory account = _marginAccount();
        if (account.size == 0) {
            return 0;
        }
        require(netAssetValue != 0, "nav is 0");
        uint256 marginValue = _markPrice().wmul(account.size);
        int256 currentLeverage = marginValue.wdiv(netAssetValue).toInt256();
        return account.side == LibTypes.Side.SHORT? currentLeverage.neg(): currentLeverage;
    }

    /**
     * @dev     Get drawdown to max net asset value per share in history.
     * @return  A percentage represents drawdown, fixed float in decimals 18.
     */
    function _drawdown(uint256 netAssetValue)
        internal
        view
        virtual
        returns (uint256)
    {
        if (totalSupply() == 0) {
            return 0;
        }
        uint256 netAssetValuePerShare = _netAssetValuePerShare(netAssetValue);
        if (netAssetValuePerShare >= _maxNetAssetValuePerShare) {
            return 0;
        }
        return _maxNetAssetValuePerShare.sub(netAssetValuePerShare).wdiv(_maxNetAssetValuePerShare);
    }

    function _updateFeeState(uint256 netAssetValueBeforeUpdating)
        internal
        virtual
        returns (uint256 netAssetValue)
    {
        if (_lastFeeTime == _now()) {
            return netAssetValueBeforeUpdating;
        }
        uint256 newFee = _managementFee(netAssetValueBeforeUpdating);
        netAssetValue = netAssetValueBeforeUpdating.sub(newFee);
        _updateFee(newFee);
        _updateMaxNetAssetValuePerShare(netAssetValue, totalSupply());
    }

    uint256[20] private __gap;
}