pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LibFundStorage.sol";
import "./LibMathExt.sol";

library LibFundCalculator {
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathExt for uint256;
    using LibFundStorage for LibFundStorage.FundStorage;

    function getMarginBalance(LibFundStorage.FundStorage storage fundStorage)
        internal
        view
        returns (uint256)
    {
        int256 marginBalance = fundStorage.perpetual.marginBalance(this.address);
        require(marginBalance > 0, "marginBalance must be greater than 0");
        return marginBalance.toUint256();
    }

    function getNetAssetValue(LibFundStorage.FundStorage storage fundStorage)
        internal
        view
        returns (uint256)
    {
        if (fundStorage.totalShareSupply == 0) {
            return 0;
        }
        return getMarginBalance(fundStorage).wdiv(fundStorage.totalShareSupply);
    }

    function getLeverage(LibFundStorage.FundStorage storage fundStorage)
        internal
        view
        returns (uint256)
    {
        uint256 margin = fundStorage.perpetual.positionMargin();
        uint256 marginBalance = getMarginBalance(fundStorage);
        return margin.wdiv(marginBalance);
    }
}