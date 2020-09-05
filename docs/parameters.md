# PARAMETERS

*Parameters below will be available for all fund contracts if not mentioned*

## redeemingLockPeriod

This item is the least duration between last purchasing and redeeming, counted in seconds and applied on single trader.

Setting redeemingLockPeriod to 0 means there will be no time limit for redeeming.

For example:

A purchased 10 shares at time T. Then the earliest time for A to be able to redeem his share for collateral will be T + [redeemingLockPeriod].

Note that every purchase will refresh the duration.



## entranceFeeRate, streamingFeeRate and performanceFeeRate

Set fee rates, no greater than 100%.

Check [management_fee.md](./management_fee.md) for details.



## globalRedeemSlippage

Redeem slippage of underlaying position when fund contract is shutting down.



## cap

Max supply of fund share token.

Cap can be lower than current total supply, which means no new purchase on shares until total supply is below cap.



## drawdownHighWaterMark

A risk parameter to control max loss on drawdown, no greater than 50%.

Max drawdown in system is calculated every time when fee and net asset value updated, or manually by user.

When current drawdown reaches value of drawdownHighWaterMark, the fund contract is able to be shutdown by any one.



## leverageHighWaterMark

A risk parameter to control max leverage of fund margin, ranged from [-10, +10].

Leverage in system is calculated every time when fee and net asset value updated, or manually by user.

When current leverage reaches value of leverageHighWaterMark, the fund contract is able to be shutdown by any one.

*Both drawdownHighWaterMark and leverageHighWaterMark will be affect by mark price and fee. A manually update not only brings fund manager higher performance fee but also higher water mark, makes a possible greater drawdown in the future.*



## rebalanceSlippage [ AutoTradingFund only ]

Slippage applied on rebalance operation.



## rebalanceTolerance[ AutoTradingFund only ]

For fund contract, any purchase will lower the leverage of fund's margin, and changes of mark price may also affect the leverage.

To avoid frequently adjustment on position, the rebalanceTolerance is introduced as the max threshold of diff between actual leverage and target leverage.

For example, rebalanceTolerance is set to 0.5, and current leverage is 1.0, then no rebalance will be needed when leverage goes up to 1.5+ or down to 0.5-.



## setManager [ SocialTradingFund only ]

Set manager of SocialTradingFund.

This will send all claimed fee to previous manager if possible.

And the new manager will be set as the delegator of fund margin account, overriding the previous.