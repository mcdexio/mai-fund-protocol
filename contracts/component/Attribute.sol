// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibTypes.sol";
import "../lib/LibMathEx.sol";

import "./ERC20Tradable.sol";
import "./MarginAccount.sol";

contract Attribute is ManagementFee, MarginAccount {
    
    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using LibMathEx for int256;
    using LibMathEx for uint256;

    /**
     * @notice  Get net asset value and fee.
     * @return netAssetValue    Net asset value.
     * @return managementFee    Fee to claimed by manager since last claiming.
     */
    function _netAssetValue()
        internal
        virtual
        returns (uint256)
    {
        // claimed fee excluded
        return _totalAssetValue().sub(_totalFeeClaimed, "total asset value less than fee");
    }

    function _managementFee(uint256 assetValue) 
        internal
        virtual
        return (uint256)
    {
        uint256 streamingFee = _streamingFee(assetValue);
        assetValue = assetValue.sub(streamingFee, "incorrect streaming fee rate");
        uint256 performanceFee = _performanceFee(assetValue);
        assetValue = assetValue.sub(performanceFee, "incorrect performance fee rate");
        return streamingFee.add(performanceFee);
    }

    function _netAssetValuePerShare(uint256 netAssetValue)
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
     * @dev     leverage = margin / (asset value - fee)
     * @return  Leverage of fund positon account.
     */
    function _leverage(uint256 netAssetValue)
        internal
        virtual
        returns (int256)
    {
        LibTypes.MarginAccount memory account = _marginAccount();
        uint256 marginValue = _markPrice().wmul(account.size);
        int256 currentLeverage = marginValue.wdiv(netAssetValue).toInt256();
        return account.side == LibTypes.Side.SHORT? currentLeverage.neg(): currentLeverage;
    }
}