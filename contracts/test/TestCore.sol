// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../interface/IPerpetual.sol";
import "../lib/LibTypes.sol";
import "../component/Core.sol";

contract TestCore is Core {
    address private _mockSelf;
    uint256 private _mockStreamingFee;
    uint256 private _mockPerformanceFee;

    constructor(string memory name, string memory symbol, uint256 cap, address perpetualAddress) public {
        __ERC20_init_unchained(name, symbol);
        __ERC20CappedRedeemable_init_unchained(cap);
        __MarginAccount_init_unchained(perpetualAddress);
    }

    function totalFeeClaimable() external view returns (uint256) {
        return _totalFeeClaimable;
    }

    function setTotalFeeClaimed(uint256 __totalFeeClaimable)
        external
    {
        _totalFeeClaimable = __totalFeeClaimable;
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

    function _performanceFee(uint256)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return _mockPerformanceFee;
    }

    function setHistoricMaxNetAssetValuePerShare(uint256 historicMaxNetAssetValuePerShare)
        external
    {
        _historicMaxNetAssetValuePerShare = historicMaxNetAssetValuePerShare;
    }

    function netAssetValue()
        external
        virtual
        returns (uint256)
    {
        // claimed fee excluded
        return _updateNetAssetValue();
    }

    function netAssetValuePerShare(uint256 netAssetValue_)
        external
        view
        virtual
        returns (uint256)
    {
        return _netAssetValuePerShare(netAssetValue_);
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
        return _leverage(_updateNetAssetValue());
    }

    function drawdown()
        external
        returns (uint256)
    {
        return _drawdown(_updateNetAssetValue());
    }
}

