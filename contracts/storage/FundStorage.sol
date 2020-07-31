// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

// import "../lib/LibEnumarableMap.sol";
import "../interface/IPerpetual.sol";
import "./Stoppable.sol";
import "./ERC20Storage.sol";


contract FundStorage is
    ERC20Storage,
    Pausable,
    Stoppable,
    Initializable,
    ReentrancyGuard
{
    // underlaying perpetual.
    address internal _collateral;
    uint256 internal _scaler;
    // fee state
    uint256 internal _totalFeeClaimed;
    uint256 internal _maxNetAssetValuePerShare;
    uint256 internal _lastFeeTime;
    // configurations
    uint256 internal _capacity;
    uint256 internal _shuttingDownSlippage;
    uint256 internal _drawdownHighWaterMark;
    uint256 internal _leverageHighWaterMark;
    uint256 internal _redeemingLockPeriod;
    uint256 internal _entranceFeeRate;
    uint256 internal _streamingFeeRate;
    uint256 internal _performanceFeeRate;

    // accounts
    mapping(address => uint256) internal _redeemingBalances;
    mapping(address => uint256) internal _redeemingSlippage;
    mapping(address => uint256) internal _lastPurchaseTime;

    // dependencies
    IPerpetual internal _perpetual;
    // Manager of fund, responsing for rebalance / trading strategy.
    address internal _manager;

    function capacity() external view returns (uint256) {
        return _capacity;
    }

    function totalFeeClaimed() external view returns (uint256) {
        return _totalFeeClaimed;
    }

    function maxNetAssetValuePerShare() external view returns (uint256) {
        return _maxNetAssetValuePerShare;
    }

    function lastFeeTime() external view returns (uint256) {
        return _lastFeeTime;
    }

    function redeemingLockPeriod() external view returns (uint256) {
        return _redeemingLockPeriod;
    }

    function drawdownHighWaterMark() external view returns (uint256) {
        return _drawdownHighWaterMark;
    }

    function leverageHighWaterMark() external view returns (uint256) {
        return _leverageHighWaterMark;
    }

    function entranceFeeRate() external view returns (uint256) {
        return _entranceFeeRate;
    }

    function streamingFeeRate() external view returns (uint256) {
        return _streamingFeeRate;
    }

    function performanceFeeRate() external view returns (uint256) {
        return _performanceFeeRate;
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

    function manager() external view returns (address) {
        return _manager;
    }
}