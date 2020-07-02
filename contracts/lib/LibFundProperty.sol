// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LibFundCore.sol";
import "./LibMathEx.sol";

library LibFundProperty {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for uint256;

    function totalAssetValue(LibFundCore.Core storage core)
        internal
        returns (uint256)
    {
        int256 marginBalance = core.perpetual.marginBalance(address(this));
        require(marginBalance > 0, "marginBalance must be greater than 0");
        return marginBalance.toUint256();
    }

    function netAssetValue(LibFundCore.Core storage core)
        internal
        returns (uint256)
    {
        if (core.shareTotalSupply == 0) {
            return 0;
        }
        return totalAssetValue(core).wdiv(core.shareTotalSupply);
    }

    function leverage(LibFundCore.Core storage core)
        internal
        returns (uint256)
    {
        uint256 margin = core.perpetual.positionMargin(address(this));
        uint256 marginBalance = totalAssetValue(core);
        return margin.wdiv(marginBalance);
    }
}