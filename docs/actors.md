# ACTORS

There are for kind of actors in MFP (Mai Fund Protocol), administrator, manager, keeper and traders.

## Administrator

MFP shares the same aministrator with perpetual contract (defined in global config).

Administrator of fund is able to modify parameters of system to control risk and profits.

Check [] for all available parameters.

## Manager

Manager in MFP is the one providing trading strategy, making profit from margin trading with collateral deposited in margin account of fund.

Traders is able to choose strategies provided by hard-coded contract or expert traders. Different strategies work in different ways, but all of them accomplish their goals by adjusting the leverage and side of the margin account of fund.

For a social trading fund, the manager would be an experienced trader, trading like any user through Mai Protocol V2 but with collateral from fund's margin instead of his own.

For a auto trading fund, a keeper will do the rebalance job for fund according to the output of a contract strategy, to keep fund work.

## Keeper

Because of the mechanism of blockchain and the limited liquidity, immediately rebalance and redeem in most cases are not possible. In MFP, when share holders want to leave (redeem), the keeper could take underlaying positions belongs to the redeemer with a slippage, then let the redeemers exit from fund.

Any trader is able to call methods for keeper. The slippage is the main incentive for trader to become a keeper.

## Trader (User)

One who deposits collateral to fund is referred as a trader (or user) in MFP.

Traders needs to choose when to enter and exit. Both manager and keeper can alse be trader of fund.
