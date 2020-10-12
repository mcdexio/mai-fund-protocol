// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./LibMathEx.sol";
import "../interface/IPerpetual.sol";

library LibTargetCalculator {

    using SafeCast for uint256;
    using SafeMath for uint256;
    using LibMathEx for int256;
    using SafeCast for int256;
    using SignedSafeMath for int256;

    function signedSize(IPerpetual perpetual)
        internal
        view
        returns (int256)
    {
        LibTypes.MarginAccount memory marginAccount = perpetual.getMarginAccount(address(this));
        int256 size = marginAccount.size.toInt256();
        return marginAccount.side == LibTypes.Side.SHORT? size.neg(): size;
    }

    /**
     * @notice  Get amount / side to rebalance.
     *          To compact with _tradePosition, side is reversed.
     *          delta is, eg:
     *           - expected = 1,  current = 1  -->  no adjust
     *           - expected = 2,  current = 1  -->  2 -  1 =  1,   LONG for 1
     *           - expected = 0,  current = 1  -->  0 -  1 = -1,   SHORT for 1
     *           - expected = 0,  current = -1  -->  0 -  -1 = 1,   LONG for 1
     *           - expected = -1, current = 1  --> -1 -  1 = -2,   SHORT for 2
     *           - expected = 2,  current = -1 -->  2 - -1 =  3,   LONG for 3
     *           - expected = -2, current = -1 --> -2 - -1 = -1,   SHORT for 1
     *           ...
     * @return  amount  Amount of positions needed for rebalance to target leverage.
     * @return  side    Side of positions needed for rebalance to target leverage.
     */
    function calculateRebalanceTarget(
        IPerpetual perpetual,
        uint256 netAssetValue,
        int256 nextTargetLeverage
    )
        public
        returns (uint256 amount, LibTypes.Side side)
    {
        uint256 markPrice = perpetual.markPrice();
        require(markPrice != 0, "mark price is 0");
        int256 currentSize = signedSize(perpetual);
        int256 targetMargin = netAssetValue.toInt256().wmul(nextTargetLeverage);
        int256 targetSize = targetMargin.wdiv(markPrice.toInt256());
        int256 target = targetSize.sub(currentSize);
        amount = target.abs().toUint256();
        side = target > 0? LibTypes.Side.LONG: LibTypes.Side.SHORT;
    }

}