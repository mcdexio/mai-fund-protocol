// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

// import "../lib/LibEnumarableMap.sol";
import "../interface/IPerpetual.sol";
import "./ERC20Storage.sol";

contract FundStorage is ERC20Storage {
    // underlaying perpetual.
    address internal _collateral;
    uint256 internal _scaler;
    // state
    uint256 internal _totalFeeClaimed;
    uint256 internal _maxNetAssetValue;
    uint256 internal _lastPassiveClaimingTime;
    uint256 internal _lastActiveClaimingTime;

    // configurations
    uint256 internal _redeemingLockdownPeriod;
    uint256 internal _feeClaimingPeriod;
    uint256 internal _minimalRedeemingPeriod;
    uint256 internal _entranceFeeRate;
    uint256 internal _streamingFeeRate;
    uint256 internal _performanceFeeRate;

    // accounts
    mapping(address => uint256) internal _redeemingBalances;
    mapping(address => uint256) internal _redeemingSlippage;
    mapping(address => uint256) internal _lastPurchaseTime;

    // dependencies
    address internal _factory;
    address internal _maintainer;
    IPerpetual internal _perpetual;
}