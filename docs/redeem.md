# REDEEMING

[TOC]

## Defines

- $ManagementFee = PerformanceFee + StreamingFee + EntranceFee$

- $NAV = MarginBalance(fund) - ManagementFee $



## Steps

### When not stopped

**position size of fund is not 0**

1. [Trader] asks to redeem $X$ shares;
   $$
   RedeemingShareBalance_{trader} = RedeemingShareBalance_{trader} + X
   $$

2. [Trader] updates slippage $S$ (override previous setting);
   $$
   RedeemingSlippage_{trader} = S
   $$

3. [Keeper] bids redeeming $X'$ shares from Trader;
   $$
   Slippage = MarkPrice \times RedeemingSlippage_{trader} \times X'
   $$

   $$
   Position_{fund} = Position_{fund} -\frac{Position_{fund} \times X'}{TotalShareSupply}
   $$

   $$
   WithdrawableCollateral_{trader} = WithdrawableCollateral_{trader} + \frac{NAV \times X'}{TotalShareSupply} - Slippage
   $$

   $$
   ShareBalance_{trader} = ShareBalance_{trader} - X'
   $$

   $$
   TotalShareSupply = TotalShareSupply - X'
   $$

   $$
   RedeemingShareBalance_{trader} = RedeemingShareBalance_{trader} - X'
   $$



4. Loop 3 until $RedeemingShareBalance_{trader} = 0$

5. [Trader] is able to withdraws collaterals up to $WithdrawableCollateral_{trader}$.



**position size of fund is 0**

1. [Trader] asks to redeem X shares;

2. [Trader] is able to directly withdraws collaterals equaled to $CollateralToReturn$;
   $$
   CollateralToReturn = \frac{NAV \times X}{TotalShareSupply}
   $$

   $$
   ShareBalance_{trader} = ShareBalance_{trader} - X'
   $$

   $$
   TotalShareSupply = TotalShareSupply - X'
   $$

### When stopped

[Admin] will set $redeemingShareBalance_{fund} = totalShareBalance$ on stop operation;

1. [Keeper] bids $X'$ shares for fund account;
   $$
   Slippage = MarkPrice \times RedeemingSlippage_{fund} \times X'
   $$

   $$
   Position_{fund} = Position_{fund} -\frac{Position_{fund} \times X'}{RedeemingSlippage_{fund}}
   $$

   $$
   CollateralToFund = CollateralToFund + \frac{NAV \times X'}{RedeemingSlippage_{fund}} - Slippage
   $$

   $$
   RedeemingShareBalance_{fund} = RedeemingShareBalance_{fund} - X'
   $$

2. [Trader] is not able to settle until $redeemingShareBalance_{fund} = 0$;

3. [Trader] is able to withdraw collateral using steps in **position size of fund is 0**.



