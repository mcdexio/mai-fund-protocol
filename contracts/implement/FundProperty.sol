// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../external/LibTypes.sol";
import "../storage/FundStorage.sol";
import "../lib/LibMathEx.sol";

contract FundProperty is FundStorage {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for uint256;

    /**
     * @dev Return address of self.
     */
    function self() internal view returns (address) {
        return address(this);
    }

    /**
     * @dev Return total asset value.
     * @return Value of total assets in fund.
     */
    function totalAssetValue() internal returns (uint256) {
        int256 marginBalance = _perpetual.marginBalance(address(this));
        require(marginBalance > 0, "marginBalance must be greater than 0");
        return marginBalance.toUint256();
    }

    /**
     * @dev Return net asset value.
     * @return Net value of assets in fund.
     */
    function netAssetValue() internal returns (uint256) {
        return _totalSupply == 0? 0: totalAssetValue().wdiv(_totalSupply);
    }

    /**
     * @dev Return leverage of perpetual.
     * @return Net value of assets in fund.
     */
    function leverage() internal returns (uint256) {
        uint256 margin = _perpetual.positionMargin(self());
        return margin.wdiv(totalAssetValue());
    }

    function marginAccount() internal view returns (LibTypes.MarginAccount memory account) {
        account = _perpetual.getMarginAccount(self());
    }
}