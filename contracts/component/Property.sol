// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibTypes.sol";
import "../lib/LibMathEx.sol";
import "./ERC20Wrapper.sol";
import "./PerpetualWrapper.sol";
import "./ManagementFee.sol";

contract Property is Initializable, ERC20Wrapper, PerpetualWrapper, ManagementFee {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;

    /**
     * @dev     leverage = margin / (asset value - fee)
     * @return  Leverage of fund positon account.
     */
    function leverage()
        public
        virtual
        returns (int256)
    {
        uint256 markPrice = _markPrice();
        LibTypes.MarginAccount memory account = _marginAccount();
        uint256 value = markPrice.wmul(account.size);
        (uint256 netAssetValue, ) = _netAssetValueAndFee();
        int256 currentLeverage = value.wdiv(netAssetValue).toInt256();
        return account.side == LibTypes.Side.SHORT? currentLeverage.neg(): currentLeverage;
    }

    /**
     * @notice  Return net asset value per share.
     * @return  Net asset value per share.
     */
    function netAssetValuePerShare()
        public
        returns (uint256)
    {
        ( uint256 netAssetValue, ) = _netAssetValueAndFee;
        return _netAssetValuePerShareAndFee(netAssetValue);
    }

    /**
     * @notice  Get net asset value and fee.
     * @return netAssetValue    Net asset value.
     * @return managementFee    Fee to claimed by manager since last claiming.
     */
    function _netAssetValueAndFee()
        internal
        virtual
        returns (uint256 netAssetValue, uint256 managementFee)
    {
        uint256 totalAssetValue = _totalAssetValue();
        // claimed fee excluded
        netAssetValue = totalAssetValue.sub(totalFeeClaimed(), "total asset value less than fee");
        if (!stopped() || totalSupply() == 0) {
            // streaming totalFee, performance totalFee excluded
            uint256 streamingFee = _streamingFee(netAssetValue);
            netAssetValue = netAssetValue.sub(streamingFee, "incorrect streaming fee rate");
            uint256 performanceFee = _performanceFee(netAssetValue);
            netAssetValue = netAssetValue.sub(performanceFee, "incorrect performance fee rate");
            managementFee = streamingFee.add(performanceFee);
        }
    }

    function _netAssetValuePerShareAndFee(uint256 netAssetValue)
        internal
        virtual
        returns (uint256)
    {
        if (totalSupply() == 0 || netAssetValue == 0) {
            return 0;
        }
        return netAssetValue.wdiv(totalSupply());
    }

    /**
     * @notice  Get drawdown to max net asset value per share in history.
     * @return  A percentage represents drawdown, fixed float in decimals 18.
     */
    function _drawdown()
        internal
        virtual
        returns (uint256)
    {
        if (totalSupply() == 0) {
            return 0;
        }
        uint256 currentNetAssetValuePerShare = netAssetValuePerShare();
        uint256 netAssetValuePerShareHWM = maxNetAssetValuePerShare();
        if (netAssetValuePerShareHWM <= currentNetAssetValuePerShare) {
            return 0;
        }
        return netAssetValuePerShareHWM.sub(currentNetAssetValuePerShare).wdiv(netAssetValuePerShareHWM);
    }
}