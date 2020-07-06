// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/LibUtils.sol";

import "../storage/FundStorage.sol";

contract FundAccount is FundStorage {

    using SafeMath for uint256;

    event IncreaseShareBalance(address indexed trader, uint256 shareAmount);
    event DecreaseShareBalance(address indexed trader, uint256 shareAmount);
    event IncreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);
    event DecreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);

    event TransferShareBalance(address indexed sender, address indexed recipient, uint256 shareAmount);

    /**
     * @dev Share balance to redeem. Before actually sold, the share will still be active.
     *
     * @param trader Address of share owner.
     * @return Amount of redeemable share balance.
     */
    function redeemableShareBalance(address trader) internal view returns (uint256) {
        return _balances[trader].sub(_redeemingBalances[trader]);
    }

    /**
     * @dev Purchase share, add to immature share balance.
     *      Called by user.
     *
     * @param trader        Address of share owner.
     * @param shareAmount   Amount of share to purchase.
     */
    function increaseShareBalance(address trader, uint256 shareAmount) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        // update balance
        _balances[trader] = _balances[trader].add(shareAmount);
        _totalSupply = _totalSupply.add(shareAmount);
        _lastPurchaseTime[trader] = LibUtils.currentTime();

        emit IncreaseShareBalance(trader, shareAmount);
    }

    function decreaseShareBalance(address trader, uint256 shareAmount) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        // update balance
        _balances[trader] = _balances[trader].sub(shareAmount);
        _totalSupply = _totalSupply.sub(shareAmount);

        emit DecreaseShareBalance(trader, shareAmount);
    }


    function canRedeem(address trader) internal view returns (bool) {
        if (_redeemingLockdownPeriod == 0) {
            return true;
        }
        return _lastPurchaseTime[trader].add(_redeemingLockdownPeriod) < LibUtils.currentTime();
    }

    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by user.
     *
     * @param trader       Address of share owner.
     * @param shareAmount   Amount of share to redeem.
     */
    function increaseRedeemingAmount(address trader, uint256 shareAmount, uint256 slippage) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount <= redeemableShareBalance(trader), "no enough share to redeem");
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader].add(shareAmount);
        _redeemingSlippage[trader] = slippage;

        emit IncreaseRedeemingShareBalance(trader, shareAmount);
    }


    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by user.
     *
     * @param trader       Address of share owner.
     * @param shareAmount   Amount of share to redeem.
     */
    function decreaseRedeemingAmount(address trader, uint256 shareAmount) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader].sub(shareAmount);

        emit DecreaseRedeemingShareBalance(trader, shareAmount);
    }
}