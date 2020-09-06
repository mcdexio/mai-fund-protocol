# CONTRACTS

Mai Fund Protocol mainly works in two different way: auto trading by in-contract strategy or manual trading by fund manager.

Therefore we introduce two smart contract implemetations: AutoTradingFund and SocialTradingFund.

-----

## Components

- Core.sol
  - ERC20CappedRedeemable.sol

  - Fee.sol

  - MarginAccount.sol
  - State.sol

### Core.sol

Core is the base of fund, containing states of fund and method to access backend (perpetual). It consists of several component:

### ERC20CappedRedeemable.sol

ERC20CappedRedeemable is a extended erc20, inherited from ERC20UpgradeSafe (a standard erc20 with amount cap) provided by openzeppelin.

ERC20CappedRedeemable adds some members to store user's redeeming status and cap of erc20. There is a interface for administrator to update the value of cap, that is the only difference to ERC20CappedUpgradeSafe from openzeppelin.

### MarginAccount.sol

MarginAccount is a wrapper to interact with fund's margin account, such as getting margin balance, mark price, perpetual status, ETC.

### Fee.sol

Fee is the management fee calculator.

It marks the amount of fee charged from participants' activities, and updated on every purchase / redeem.

Currently, management fee includes:

- entrance fee
- streaming fee
- performance fee

Check [management_fee.md](./fee.md) for details.

### State.sol

State defined three state for fund: normal, emergency and shutdown.

When a fund breaks the risk constrains or its underlaying perpetual is settled, the fund will be set into emergency state, waiting keeper to settle all the position hold by fund's margin, and then shutdown state.

### Collateral.sol

Collateral handles all things about underlaying collateral, which should be the same to perpetual's.

Since every fund may accept different collateral with different decimals, the Collateral.sol need to do conversion before deposit / withdraw.

### Auction.sol

When user wants to redeem from a fund contract, a periodic-running share bidder will take over the underlaying positions and pay collterals to user.

Auction.sol contains methods for share biddings.



## Funds

- AutoTradingFund.sol

  - SettleableFund.sol
    - BaseFund.sol
      - Core.sol
      - Auction.sol
      - Collateral.sol

  - Getter.sol

    

- SocialTradingFund.sol

  - SettleableFund.sol
    - BaseFund.sol
      - Core.sol
      - Auction.sol
      - Collateral.sol
  - Getter.sol

### Getter.sol

Getter contrains read-only methods to retrieve properties of fund.

### BaseFund.sol

Base fund contains all interface available in normal state. 

```
    - [Pub] setParameter #
       - modifiers: onlyOwner
    - [Ext] approvePerpetual #
       - modifiers: onlyOwner
    - [Ext] pause #
       - modifiers: onlyOwner
    - [Ext] unpause #
       - modifiers: onlyOwner
    - [Ext] purchase ($)
       - modifiers: whenInState(FundState.Normal),whenNotPaused,nonReentrant
    - [Ext] redeem #
       - modifiers: whenInState(FundState.Normal),whenInState,nonReentrant
    - [Ext] cancelRedeeming #
       - modifiers: whenInState(FundState.Normal),whenNotPaused
    - [Ext] bidRedeemingShare #
       - modifiers: whenInState(FundState.Normal),whenNotPaused,nonReentrant
```

### SettleableFund.sol

Inheriting from BaseFund, SettleableFund add methods that handles user's asset in emergency / shutdown state.

```
    - [Pub] setParameter #
       - modifiers: onlyOwner
    - [Pub] setEmergency #
       - modifiers: whenInState
    - [Pub] setShutdown #
       - modifiers: whenInState,nonReentrant
    - [Ext] bidSettledShare #
       - modifiers: whenNotPaused,whenInState,nonReentrant
    - [Ext] settleMarginAccount #
       - modifiers: whenNotPaused,whenInState,nonReentrant
    - [Ext] settle #
       - modifiers: whenNotPaused,whenInState,nonReentrant
```

### SocialTradingFund.sol

SocialTradingFund allows a fund manager performing delegate trading for a fund.

It is empowered by a new feature 'delegate trading' introduced in latest exchange contract.

A real trader (fund manager) will be set as the delegator of fund margin account. User deposited their collateral into the fund is actually doing a copy trading according to the strategy provided by fund manager.

In this mode, a manager is able to choose any combination of fee parameters.

### AutoTradingFund.sol

AutoTradingFund accept a contract as target leverage indicator. When the target changed, anyone can rebalance the position of fund through calling 'rebalance' method.

The strategy implementation should contains a `getNextTarget` method like:

```
interface ITradingStrategy {
    function getNextTarget() external returns (int256);
}
```

Its output should be a signed integer, where the absolute value of the integer represents the target leverage and the sign indicates the trading direction.