// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../interface/IPerpetual.sol";
import "../lib/LibTypes.sol";
import "../component/Status.sol";

contract TestStatus is Status {
    address private _mockSelf;
    uint256 private _mockStreamingFee;
    uint256 private _mockPerformanceFee;

    constructor(string memory name, string memory symbol, uint256 cap, address perpetual) public {
        __ERC20_init_unchained(name, symbol);
        __ERC20Capped_init_unchained(cap);
        __ERC20Redeemable_init_unchained();
        _perpetual = IPerpetual(perpetual);
    }

    function totalFeeClaimed() external view returns (uint256) {
        return _totalFeeClaimed;
    }

    function setTotalFeeClaimed(uint256 __totalFeeClaimed)
        external
    {
        _totalFeeClaimed = __totalFeeClaimed;
    }

    function mint(address trader, uint256 shareAmount)
        external
    {
        _mint(trader, shareAmount);
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

    function _performanceFee(uint256, uint256)
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

    function marginAccount()
        external
        view
        returns (LibTypes.MarginAccount memory account)
    {
        return _marginAccount();
    }

    function netAssetValue()
        external
        virtual
        returns (uint256)
    {
        // claimed fee excluded
        return _netAssetValue();
    }

    function netAssetValueEx()
        external
        virtual
        returns (uint256)
    {
        // claimed fee excluded
        return _updateFeeState(_netAssetValue());
    }


    function netAssetValuePerShare(uint256 __netAssetValue)
        external
        view
        virtual
        returns (uint256)
    {
        return _netAssetValuePerShare(__netAssetValue);
    }

    function managementFee(uint256 assetValue)
        external
        view
        virtual
        returns (uint256)
    {
        return _managementFee(assetValue);
    }

    function leverage()
        external
        returns (int256)
    {
        return _leverage(_updateFeeState(_netAssetValue()));
    }

    function drawdown()
        external
        returns (uint256)
    {
        return _drawdown(_updateFeeState(_netAssetValue()));
    }

    function updateFeeState(uint256 netAssetValueBeforeUpdating)
        external
        returns (uint256)
    {
        return _updateFeeState(netAssetValueBeforeUpdating);
    }
}

