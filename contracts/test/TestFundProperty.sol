// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../interface/IPerpetual.sol";
import "../lib/LibTypes.sol";
import "../component/FundProperty.sol";

import "./TestFundConfiguration.sol";

contract TestFundProperty is
    FundProperty,
    TestFundConfiguration
{
    address private _self;
    uint256 private _streamingFee;
    uint256 private _performanceFee;

    constructor(address perpetual) public {
        _perpetual = IPerpetual(perpetual);
    }

    function setTotalFeeClaimed(uint256 totalFeeClaimed)
        external
    {
        _totalFeeClaimed = totalFeeClaimed;
    }

    function setTotalSupply(uint256 totalSupply)
        external
    {
        _totalSupply = totalSupply;
    }

    function setSelf(address fakeSelf)
        external
    {
        _self = fakeSelf;
    }

    function self()
        internal
        view
        virtual
        override
        returns (address)
    {
        return _self;
    }

    function setStreamingFee(uint256 streamingFee)
        external
    {
        _streamingFee = streamingFee;
    }

    function getStreamingFee(uint256)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return _streamingFee;
    }

    function setPerformanceFee(uint256 performanceFee)
        external
    {
        _performanceFee = performanceFee;
    }

    function getPerformanceFee(uint256)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return _performanceFee;
    }

    function setMaxNetAssetValuePerShare(uint256 maxNetAssetValuePerShare)
        external
    {
        _maxNetAssetValuePerShare = maxNetAssetValuePerShare;
    }

    function getMarginAccountPublic()
        external
        view
        returns (LibTypes.MarginAccount memory account)
    {
        return getMarginAccount();
    }

    function getPositionSizePublic()
        external
        view
        returns (uint256)
    {
        return getPositionSize();
    }


  function getTotalAssetValuePublic()
        external
        returns (uint256)
    {
        return getTotalAssetValue();
    }

    function getNetAssetValueAndFeePublic()
        external
        returns (uint256 netAssetValue, uint256 managementFee)
    {
        return getNetAssetValueAndFee();
    }

    function getNetAssetValuePerShareAndFeePublic()
        external
        returns (uint256 netAssetValuePerShare, uint256 managementFee)
    {
        return getNetAssetValuePerShareAndFee();
    }

    function getLeveragePublic()
        external
        returns (int256)
    {
        return getLeverage();
    }

    function getDrawdownPublic()
        external
        returns (uint256)
    {
        return getDrawdown();
    }
}

