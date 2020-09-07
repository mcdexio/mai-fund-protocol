# INTERFACE

## ERC20

The Fund itself has a fully ERC20 compatible interface. Check [ERC20](https://eips.ethereum.org/EIPS/eip-20) for details.

Moreover, the fund is extended with **ERC20Capped** supplied by openzeppelin, which makes it limited in max supply.



## Core

These methods are shared among implementations of fund.

```
function setParameter(bytes32 key, int256 value)
```

Update configurations of fund.

Inputs:

- `key` Name of configuration entry.
- `value` Value to set.

```
function shutdown()
```

Shutdown fund contract.

*This method is not only available to administrator, but also can be call by anyone in some case, see [settlement](./settlement.md) for details.*

```
function approvePerpetual(uint256 rawCollateralAmount)
```

Approve perpetual contract as spender for underlaying ERC20 collateral. No need when using ether.

Inputs:

- `rawCollateralAmount` Amount of collateral to approve, in ERC20 collateral's decimals.

```
function pause()
```

Pause normal function of fund contract.

```
function unpause()
```

Resume from paused status.

```
function purchase(
	uint256 collateralAmount,
	uint256 minimalShareAmount,
	uint256 pricePerShareLimit
)
```

Purchase shares of fund.

As the net asset value is decreasing over time when the streaming fee rate is not 0, the amount of shares could be purchased with a fixed amount collaterals will not be deterministic too. Trader can specify minimal share amount and highest price to avoid unexpected loss.

Inputs:

- `collateralAmount` Total amount of collaterals paid.
- `minimalShareAmount` Minimal share amount asked by trader. Transaction will fail if not met.
- `pricePerShareLimit` Max price per share that trader can afford . Transaction will fail if not met.

```
function setRedeemingSlippage(uint256 slippage)
```

Slippage when redeeming shares. This is a setting within scope of account. Only the last setting takes effect and will affect all the redeeming shares.

Inputs:
- `slippage` Slippage when keeper bids shares. The higher the slippage is, the more likely the keeper is to bid for the shares.

```
function redeem(uint256 shareAmount)
```

Redeem collaterals back with shares of fund.

The result of redeem method is different according to current positions held by fund margin account: user will get collateral back immediately if fund currently has no position; otherwise, user has to wait for keeper who bids for redeeming shares, then get collateral sent by keeper.

Inputs:

- `shareAmount` Amount of share to redeem.

```
function settle(uint256 shareAmount)
```

Emergency version of `redeem` , only available when fund contract is shutdown and all positions are sold.

It always returns collateral immediately.

```
function cancelRedeem(uint256 shareAmount)
```

Cancel redeeming shares.

Inputs:

- `shareAmount` Amount of redeeming shares to cancel.

```
function withdrawCollateral(uint256 collateralAmount)
```

Withdraw redeemed collaterals from fund contract.

Inputs:

- `collateralAmount` Amount of collateral to withdraw.

```
 function bidRedeemingShare(
     address trader,
     uint256 shareAmount,
     uint256 priceLimit,
     LibTypes.Side side
 )
```

Caller will take redeeming shares from trader, gain profits from the slippage supplied by trader redeeming shares.

Inputs:

- `trader` Address of user wants to redeem shares.
- `shareAmount` Amount of share to bid.
- `priceLimit` Bidding price for underlaying positions.
- `side` Expected side of position to bid.

```]
function bidSettledShare(
    uint256 shareAmount,
    uint256 priceLimit,
    LibTypes.Side side
)
```

Basically, it works the same as `bidRedeemingShare`, but only available when shutdown.

It will not modify `withdrawableCollaterals` of trader. Trader need to call `settle` to withdraw collaterals.

```
function settleMarginAccount()
```

Settle margin account of fund. Only should be called when the perpetual entered emergency status and successfully settled all the positions.



## AutoTradingFund

```
function inversed()
```

Indicates if calling fund is a inverse contract.

```
function strategy()
```

Get contract address of current strategy.

```
function rebalancingSlippage()
```

Get slippage of trading in rebalancing. The slippage will be calculated by mark price when rebalancing happens.

```
function rebalancingTolerance()
```

Get tolerance of rebalancing which is the max bias between current leverage and target leverage.

For example, assume that current leverage is 1.5x, the tolerance is 0.5. When leverage goes up to 2.0X or down to 1.0X, no rebalance will be triggered.

This parameter is designed to resist frequent rebalance due to small changes in the fund's NAV.

```
function needRebalancing()
```

Return true if rebalance is needed.

```
function rebalance(
	uint256 maxPositionAmount,
	uint256 priceLimit,
	LibTypes.Side side
)
```

Caller of rebalance trades position with fund towards target leverage given by strategy.

Inputs:

- `maxPositionAmount` Max position amount call want to trade. Dealing amount may be less due to lot size.
- `priceLimit` Max price.
- `side` Expected side of position.

```
function calculateRebalancingTarget()
```

Calculate amount and side towards target leverage.



## SocialTradingFund

    \- [Ext] manager
    \- [Ext] managementFee #
    \- [Ext] setManager #
       \- modifiers: onlyOwner
    \- [Ext] withdrawManagementFee #
```
function manager()
```

Return address of fund manager.

```
function managementFee()
```

Return total management fee claimed from fund.

```
function withdrawManagementFee(uint256 collateralAmount)
```

Withdraw management fee from fund. Anyone can call this method but fee will be transferred to current manager of fund.

```
function setManager(address newManager, address exchangeAddress)
```

Set fund manager and set new manager as delegator of exchange.

If previous manager is not address(0), fee will be claimed to previous one before new manager is set.