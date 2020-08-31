# CONTRACTS

- [CONTRACTS](#contracts)
  - [Core.sol](#coresol)
    - [ERC20Redeemable.sol](#erc20redeemablesol)
    - [MarginAccount.sol](#marginaccountsol)
    - [Fee.sol](#feesol)
    - [Status.sol](#statussol)
    - [Collateral.sol](#collateralsol)
    - [Auction.sol](#auctionsol)
    - [Settlement.sol](#settlementsol)
  - [Getter.sol](#gettersol)
  - [SocialTradingFund.sol](#socialtradingfundsol)
  - [AutoTradingFund.sol](#autotradingfundsol)


Mai Fund Protocol mainly works in two different way: auto trading by in-contract strategy or manual trading by fund manager.

Therefore we introduce two smart contract implemetations: AutoTradingFund and SocialTradingFund.


-----

## Core.sol

Core is the base of fund, implements every basic methods to interactive with fund.

It is consists of many smaller component:

### ERC20Redeemable.sol

ERC20Redeemable is a extended erc20, inherited from ERC20CappedUpgradeSafe (a standard erc20 with amount cap) provided by openzeppelin.

ERC20Redeemable adds some members to store user's redeeeming status.

### MarginAccount.sol

MarginAccount is a helper of performing operation on fund's margin account, such as getting margin balance, mark price
and perpetual status.

### Fee.sol

Fee is the management fee calculator.

It marks the amount of fee charged from participants' activities, and updated on every purchase / redeem.

Currently, management fee includes:

- entrance fee
- streaming fee
- performance fee

Check [management_fee.md](./fee.md) for details.

### Status.sol

Status assembles ERC20Redeemable, MarginAccount and Fee component, providing some primary status of fund.

### Collateral.sol

Collateral handles all things about underlaying collateral, which should be the same to perpetual's.

Since every fund may accept different collateral with different decimals, the Collateral.sol need to do conversion before deposit / withdraw.

### Auction.sol

When user wants to redeem from a fund contract, a periodic-running share bidder will take over the underlaying positions and pay collterals to user.

Auction.sol contains methods for share biddings.

### Settlement.sol

Settlement defines method to determine when a fund contract should be shutdown for emergency situation:

- underlaying perpetual is in emergency / settled status.
- leverage > leverage high water mark
- drawdown > drawdown high water mark


All parts together form the Core.sol, the infrastructure of fund.

-----

## Getter.sol

Getter contrains read-only methods to retrieve basic properties of fund.

-----

## SocialTradingFund.sol

SocialTradingFund allows a fund manager performing delegate trading for a fund.

It is empowered by a new feature 'delegate trading' introduced in latest exchange contract.

A real trader (fund manager) will be set as the delegator of fund margin account. User deposited their collateral into the fund is acturally doing a copy trading according to the strategy provided by fund manager.

In this mode, a manager is able to choose any combination of fee parameters.

## AutoTradingFund.sol

AutoTradingFund accept a contract as target leverage indicator. When the target changed, anyone can rebalance the position of fund through calling 'rebalance' method.
