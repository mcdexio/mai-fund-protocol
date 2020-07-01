pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LibFundCore.sol";
import "./LibMathExt.sol";

library LibFundProperty {
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathExt for uint256;
    using LibFundStorage for LibFundStorage.FundStorage;

    function totalAssetValue(LibFundCore storage core)
        internal
        view
        returns (uint256)
    {
        int256 marginBalance = core.perpetual.marginBalance(address(this));
        require(marginBalance > 0, "marginBalance must be greater than 0");
        return marginBalance.toUint256();
    }

    function netAssetValue(LibFundCore storage core)
        internal
        view
        returns (uint256)
    {
        if (shareTotalSupply == 0) {
            return 0;
        }
        return marginBalance(core).wdiv(core.shareTotalSupply);
    }

    function leverage(LibFundCore storage core)
        internal
        view
        returns (uint256)
    {
        uint256 margin = core.perpetual.positionMargin(address(this));
        uint256 marginBalance = marginBalance(core);
        return margin.wdiv(marginBalance);
    }
}