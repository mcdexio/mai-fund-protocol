pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LibFundUtils.sol";

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
    function increaseShareBalance(
        FundAccount storage account,
        uint256 netAssetValue,
        uint256 shareAmount,
        uint256 timestamp
    )
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        // update balance
        account.shareBalance = account.shareBalance.add(shareAmount);
        // firstEntryTime == 0 means no immature share balance
        lastEntrytime = timestamp;
    }

    function canRedeem(FundAccount storage account, uint256 lockPeriod) internal {
        return account.lastEntryTime.add(lockPeriod) < LibFundUtils.currentTime();
    }

    /**
     * @dev Redeem share balance, to prevent redeemed amount exceed total amount.
     *      Called by user.
     *
     * @param account       Account of share owner.
     * @param shareAmount   Amount of share to redeem.
     */
    function increaseRedeemingAmount(FundAccount storage account, uint256 shareAmount) internal {
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
    function decreaseRedeemingAmount(FundAccount storage account, uint256 shareAmount) internal {
        require(shareAmount > 0, "share amount must be greater than 0");
        // set max amount of redeeming amount
        account.redeemingShareBalance = account.redeemingShareBalance.add(shareAmount);
        require(account.redeemableShareBalance <= account.shareBalance, "redeeming shares exceeds total shares");
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
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount < account.redeemingShareBalance, "share amount exceeds limit");
        // calculate deltas
        account.shareBalance = account.shareBalance.sub(shareAmount);
        account.redeemingShareBalance = account.redeemingShareBalance.sub(shareAmount);
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