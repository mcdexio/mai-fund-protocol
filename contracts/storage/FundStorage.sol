// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// import "../lib/LibEnumarableMap.sol";
import "../interface/IPerpetual.sol";
import "./ERC20Storage.sol";

contract FundStorage is
    ERC20Storage,
    Pausable,
    ReentrancyGuard
{
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
    uint256 internal _entranceFeeRate;
    uint256 internal _streamingFeeRate;
    uint256 internal _performanceFeeRate;

    // accounts
    mapping(address => uint256) internal _redeemingBalances;
    mapping(address => uint256) internal _redeemingSlippage;
    mapping(address => uint256) internal _lastPurchaseTime;

    // dependencies
    address internal _creator;
    address internal _maintainer;
    IPerpetual internal _perpetual;

    function maxNetAssetValue() external view returns (uint256) {
        return _maxNetAssetValue;
    }

    function lastPassiveClaimingTime() external view returns (uint256) {
        return _lastPassiveClaimingTime;
    }

    function totalFeeClaimed() external view returns (uint256) {
        return _totalFeeClaimed;
    }

    function redeemingBalance(address account) external view returns (uint256) {
        return _redeemingBalances[account];
    }

    function redeemingSlippage(address account) external view returns (uint256) {
        return _redeemingSlippage[account];
    }

    function lastPurchaseTime(address account) external view returns (uint256) {
        return _lastPurchaseTime[account];
    }
}