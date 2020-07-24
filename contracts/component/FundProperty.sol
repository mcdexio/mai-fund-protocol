// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../lib/LibTypes.sol";
import "../lib/LibMathEx.sol";
import "../storage/FundStorage.sol";

import "./FundFee.sol";

contract FundProperty is
    FundStorage,
    FundFee
{
    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;

    /**
     * @notice  Return address of self.
     */
    function self()
        internal
        view
        returns (address)
    {
        return address(this);
    }

    /**
     * @notice  Return margin account of fund.
     * @return  account   Margin account structure.
     */
    function getMarginAccount()
        internal
        view
        returns (LibTypes.MarginAccount memory account)
    {
        account = _perpetual.getMarginAccount(self());
    }

    /**
     * @notice  Return position size of margin account
     * @return  Size of position, 1e18.
     */
    function getPositionSize()
        internal
        view
        returns (uint256)
    {
        return _perpetual.getMarginAccount(self()).size;
    }

    /**
     * @notice  Return total collateral amount, including unclaimed fee.
     * @dev     This is NOT a view function because [marginBalance]
     * @return  Value of total collateral in fund.
     */
    function getTotalAssetValue()
        internal
        returns (uint256)
    {
        int256 marginBalance = _perpetual.marginBalance(self());
        require(marginBalance > 0, "marginBalance must be greater than 0");
        return marginBalance.toUint256();
    }

    /**
     * @notice  Get net asset value and fee.
     * @return netAssetValue    Net asset value.
     * @return managementFee    Fee to claimed by manager since last claiming.
     */
    function getNetAssetValueAndFee()
        internal
        returns (uint256 netAssetValue, uint256 managementFee)
    {
        // claimed fee excluded
        netAssetValue = getTotalAssetValue().sub(_totalFeeClaimed);
        // streaming totalFee, performance totalFee excluded
        uint256 streamingFee = getStreamingFee(netAssetValue);
        netAssetValue = netAssetValue.sub(streamingFee);
        uint256 performanceFee = getPerformanceFee(netAssetValue);
        netAssetValue = netAssetValue.sub(performanceFee);
        managementFee = streamingFee.add(performanceFee);
    }

    /**
     * @dev     Get net asset value per share and fee.
     * @return  netAssetValuePerShare   Net asset value per share.
     * @return  managementFee           Fee to claimed by manager since last claiming.
     */
    function getNetAssetValuePerShareAndFee()
        internal
        returns (uint256 netAssetValuePerShare, uint256 managementFee)
    {
        require(_totalSupply != 0, "no share supplied yet");
        (netAssetValuePerShare, managementFee) = getNetAssetValueAndFee();
        netAssetValuePerShare = netAssetValuePerShare.wdiv(_totalSupply);
    }

    /**
     * @dev     leverage = margin / (asset value - fee)
     * @return  Leverage of fund positon account.
     */
    function getLeverage()
        internal
        returns (int256)
    {
        uint256 markPrice = _perpetual.markPrice();
        LibTypes.MarginAccount memory account = getMarginAccount();
        uint256 value = markPrice.wmul(account.size);
        (uint256 netAssetValue, ) = getNetAssetValueAndFee();
        int256 leverage = value.wdiv(netAssetValue).toInt256();
        return account.side == LibTypes.Side.SHORT? leverage.neg(): leverage;
    }

    /**
     * @notice  Get drawdown to max net asset value per share in history.
     * @return  A percentage represents drawdown, fixed float in decimals 18.
     */
    function getDrawdown()
        internal
        returns (uint256)
    {
        (uint256 netAssetValuePerShare,) = getNetAssetValuePerShareAndFee();
        if (netAssetValuePerShare > _maxNetAssetValuePerShare) {
            return 0;
        }
        return _maxNetAssetValuePerShare.sub(netAssetValuePerShare).wdiv(_maxNetAssetValuePerShare);
    }
}