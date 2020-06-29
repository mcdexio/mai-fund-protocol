pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

library LibFundAccount {

    using SafeMath for uint256;

    struct FundAccount {
        uint256 shareBalance;
        uint256 immatureShareBalance;
        uint256 immatureTotalAssetValue;
        uint256 redeemingShareBalance;
        // first entry time, for fee
        uint256 firstEntryTime;
        // last entry time, for withdraw cooldown
        uint256 lastEntryTime;
    }

    /**
     * @dev All share balance owned by a account (share balance + immature)
     *
     * @param account Account of share owner.
     * @return Total share balance.
     */
    function availableShareBalance(FundAccount storage account) internal view returns (uint256) {
        return account.shareBalance.add(account.immatureShareBalance);
    }

    /**
     * @dev Share balance to redeem. Before actually sold, the share will still be active.
     *
     * @param account Account of share owner.
     * @return Amount of redeemable share balance.
     */
    function redeemableShareBalance(FundAccount storage account) internal view returns (uint256) {
        return account.shareBalance.sub(redeemingShareBalance);
    }

    /**
     * @dev Purchase share, add to immature share balance.
     *      Called by user.
     *
     * @param account       Account of share owner.
     * @param netAssetValue NAV of current fund, price per unit.
     * @param shareAmount   Amount of share to purchase.
     * @param timestamp     Timestamp of purchasing.
     */
    function purchase(
        FundAccount storage account,
        uint256 netAssetValue,
        uint256 shareAmount,
        uint256 timestamp
    )
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        // update balance type
        adjustShareBalance(account);
        // update immature part
        account.immatureTotalAssetValue = account.immatureShareBalance
            .add(netAssetValue.wmul(shareAmount));
        account.immatureShareBalance = account.immatureShareBalance.add(shareAmount);
        // firstEntryTime == 0 means no immature share balance
        if (firstEntryTime == 0) {
            firstEntryTime = timestamp;
        }
        // always update last entry time
        lastEntrytime = timestamp;
    }

    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by user.
     *
     * @param account       Account of share owner.
     * @param shareAmount   Amount of share to redeem.
     */
    function requestToRedeem(FundAccount storage account, uint256 shareAmount) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount <= redeemableShareBalance(account), "no enough share to redeem");
        // set max amount of redeeming amount
        account.redeemingShareBalance = account.redeemingShareBalance.add(shareAmount);
    }

    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by market maker.
     *
     * @param account       Account of share owner.
     * @param shareAmount   Amount of share to redeem.
     *
     * @return decreasedImmatureShareBalance    Amount decreased from immature share balance.
     * @return decreasedShareBalance            Amount decreased from share balance.
     */
    function redeem(FundAccount storage account, uint256 shareAmount)
        internal
        returns (uint256 decreasedImmatureShareBalance, uint256 decreasedShareBalance)
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount < account.redeemingShareBalance, "share amount exceeds limit");
        // udpate balance type
        adjustShareBalance(account);
        // calculate deltas
        decreasedImmatureShareBalance = min(shareAmount, account.immatureShareBalance);
        decreasedShareBalance = shareAmount.sub(decreasedImmatureShareBalance);
        // update account,
        // fees of immatureShareBalance and redeemingShareBalance are claimed in different algorithms
        account.shareBalance = account.shareBalance.sub(decreasedShareBalance);
        account.immatureShareBalance = account.immatureShareBalance.sub(decreasedImmatureShareBalance);
        account.redeemingShareBalance = account.redeemingShareBalance.sub(shareAmount);
        if (account.immatureShareBalance == 0) {
            resetImmatureShareBalance();
        }
    }

    /**
     * @dev Ajust share balance from immature to mature (share balance).
     *
     * @param account       Account of share owner.
     */
    function adjustShareBalance(FundAccount storage account) internal {
        // no fee claimed since the first purchase and adjust happens
        if (account.firstEntryTime < account.manager.lastFeeTimestamp) {
            return;
        }
        account.shareBalance = account.shareBalance.add(account.immatureShareBalance);
        account.immatureShareBalance = 0;
        resetImmatureShareBalance();
    }

    function resetImmatureShareBalance() internal {
        account.immatureTotalAssetValue = 0;
        account.firstEntryTime = 0;
    }

    function transferShareBalance(
        FundAccount storage accountFrom,
        FundAccount storage accountTo,
        uint256 shareAmount
    )
        internal
    {
        require(shareAmount <= accountFrom.shareBalance, "insufficient share balance");
        uint256 amountToTransfer = shareAmount;
        adjustShareBalance(accountFrom);
        adjustShareBalance(accountTo);

        uint256 immatureNetAssetValue;
        if (accountFrom.immatureShareBalance > 0) {
            immatureNetAssetValue = accountFrom.immatureTotalAssetValue
                .wdiv(accountFrom.immatureShareBalance);
        }
        (
            uint256 decreasedImmatureShareBalance,
            uint256 decreasedShareBalance
        ) = redeem(accountFrom, shareAmount);

        if (decreasedImmatureShareBalance > 0) {
            purchase(accountTo, immatureNetAssetValue, decreasedImmatureShareBalance);
        }
        if (decreasedShareBalance > 0) {
            accountTo.shareBalance = accountTo.shareBalance.add(shareBalance);
        }
    }
}