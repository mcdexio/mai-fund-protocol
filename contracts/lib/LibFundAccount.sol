// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LibUtils.sol";

library LibFundAccount {

    using SafeMath for uint256;

    struct Account {
        uint256 shareBalance;
        uint256 redeemingShareBalance;
        // last entry time, for withdraw cooldown
        uint256 lastEntryTime;
    }

    /**
     * @dev Share balance to redeem. Before actually sold, the share will still be active.
     *
     * @param account Account of share owner.
     * @return Amount of redeemable share balance.
     */
    function redeemableShareBalance(Account storage account) internal view returns (uint256) {
        return account.shareBalance.sub(account.redeemingShareBalance);
    }

    /**
     * @dev Purchase share, add to immature share balance.
     *      Called by user.
     *
     * @param account       Account of share owner.
     * @param shareAmount   Amount of share to purchase.
     */
    function increaseShareBalance(
        Account storage account,
        uint256 shareAmount
    )
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        // update balance
        account.shareBalance = account.shareBalance.add(shareAmount);
        account.lastEntryTime = LibUtils.currentTime();
    }

    function canRedeem(Account storage account, uint256 lockPeriod) internal view returns (bool) {
        return account.lastEntryTime.add(lockPeriod) < LibUtils.currentTime();
    }

    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by user.
     *
     * @param account       Account of share owner.
     * @param shareAmount   Amount of share to redeem.
     */
    function increaseRedeemingAmount(Account storage account, uint256 shareAmount) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount <= redeemableShareBalance(account), "no enough share to redeem");
        // set max amount of redeeming amount
        account.redeemingShareBalance = account.redeemingShareBalance.add(shareAmount);
    }


    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by user.
     *
     * @param account       Account of share owner.
     * @param shareAmount   Amount of share to redeem.
     */
    function decreaseRedeemingAmount(Account storage account, uint256 shareAmount) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        // set max amount of redeeming amount
        account.redeemingShareBalance = account.redeemingShareBalance.add(shareAmount);
        require(account.redeemingShareBalance <= account.shareBalance, "redeeming shares exceeds total shares");
    }

    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by market maker.
     *
     * @param account       Account of share owner.
     * @param shareAmount   Amount of share to redeem.
     */
    function redeem(Account storage account, uint256 shareAmount)
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount < account.redeemingShareBalance, "share amount exceeds limit");
        // calculate deltas
        account.shareBalance = account.shareBalance.sub(shareAmount);
        account.redeemingShareBalance = account.redeemingShareBalance.sub(shareAmount);
    }

    function transferShareBalance(
        Account storage sender,
        Account storage recipient,
        uint256 shareAmount
    )
        internal
    {
        require(shareAmount > 0, "amount must be greater than 0");
        require(shareAmount <= redeemableShareBalance(sender), "insufficient share balance to transfer");
        sender.shareBalance = sender.shareBalance.sub(shareAmount);
        recipient.shareBalance = recipient.shareBalance.add(shareAmount);
    }
}