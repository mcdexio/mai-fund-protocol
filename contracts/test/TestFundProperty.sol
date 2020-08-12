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
    address private _mockSelf;
    uint256 private _mockStreamingFee;
    uint256 private _mockPerformanceFee;

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

    function setSelf(address mockSelf)
        external
    {
        _mockSelf = mockSelf;
    }

    function _self()
        internal
        view
        virtual
        override
        returns (address)
    {
        return _mockSelf;
    }

    function setStreamingFee(uint256 streamingFee)
        external
    {
        _mockStreamingFee = streamingFee;
    }

    function _streamingFee(uint256)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return _mockStreamingFee;
    }

    function setPerformanceFee(uint256 performanceFee)
        external
    {
        _mockPerformanceFee = performanceFee;
    }

    function _performanceFee(uint256)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return _mockPerformanceFee;
    }

    function setMaxNetAssetValuePerShare(uint256 maxNetAssetValuePerShare)
        external
    {
        _maxNetAssetValuePerShare = maxNetAssetValuePerShare;
    }

    function marginAccountPublic()
        external
        view
        returns (LibTypes.MarginAccount memory account)
    {
        return _marginAccount();
    }

    function positionSizePublic()
        external
        view
        returns (uint256)
    {
        return _positionSize();
    }


  function getTotalAssetValuePublic()
        external
        returns (uint256)
    {
        return _totalAssetValue();
    }

    function getNetAssetValueAndFeePublic()
        external
        returns (uint256 netAssetValue, uint256 managementFee)
    {
        return _netAssetValueAndFee();
    }

    function getNetAssetValuePerShareAndFeePublic()
        external
        returns (uint256 netAssetValuePerShare, uint256 managementFee)
    {
        return _netAssetValuePerShareAndFee();
    }

    function getLeveragePublic()
        external
        returns (int256)
    {
        return _leverage();
    }

    function getDrawdownPublic()
        external
        returns (uint256)
    {
        return _drawdown();
    }

    function getPositionSizePublic()
        external
        view
        returns (uint256)
    {
        return _positionSize();
    }
}

