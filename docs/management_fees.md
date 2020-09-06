# MANAGEMENT FEE

Management fee is a major incentive for social traders to maintain their fund and improve trading strategies.

There are three different types of extra fees that may arise during the interaction with the MFP (Mai Fund Protocol): entrance fee, streaming fee and performance fee. Each fee rate can be set between [0% - 100%) individually.

For one wants to become a fund manager (which is called social trader in MFP) is able to chose different combinations of  fee parameters to build customized management models to attract traders with different purposes.

Currently, the fund managed by contract strategies (which is called auto trader in MFP) is completely fee-free.

-----

## Entrance Fee

The entrance fee is a one-time cost on purchasing shares of a fund. It is a extra fee base on current NAV (net asset value) per share and amount of share to purchase.
$$
EntranceFee = NAVunit \times PurchasingAmount \times EntranceFeeRate
$$

For example: assume the NAV per share of fund is Ξ200, and the entrance fee rate is 0.1%. A trader have to pay for Ξ200 plus Ξ0.2 (Ξ200 * 0.01%)  to get 1 share.

-----

## Streaming Fee

Streaming fee is determined by NAV and the length of time since fund creation. No matter the NAV is increasing or not, manager will receive streaming fee over time.

Note that charging streaming fee will gradually **REDUCE** the NAV of fund, which may finally lead to the emergency shutdown.

Streaming fee is calculated by:
$$
StreamingFee = \frac{NAV \times StreamingFeeRate \times TimeElapsedSinceLastFee}{365 \times 86400}
$$
Every time before share purchasing, the streaming fee will be settle for all existing funds first.

*In implementation of contract, we assume 365 days in a year for convenience.*

For example:  assume on time T a fund is created with NAV Ξ200000000, and the streaming fee rate is set to 31.536% (which means 0.000001% / second).  On T + 100 seconds when a user wants to purchase some shares worth Ξ200000000, a Ξ200 (Ξ200000000 * 0.000001% * 100) streaming fee of will be charged first. Then on T + 200, the streaming fee will be Ξ399.9998  ( (Ξ200000000 - 200 + Ξ200000000) * 0.000001% * 100).

-----

## Performance Fee

Performance fee may be a highly motivating for fund managers to improve their trading strategies because it can only be charged when NAV per share increased.

It works as below:
$$
PerformaceFee = (NAV_{unit} - NAV_{max}) \times TotalSupply \times PerformaceFeeRate
$$

$$
NAV_{max} =
\begin{cases}
NAV_{unit},&NAV_{unit} > NAV_{max}
\cr
NAV_{max},&otherwise
\end{cases}
$$

In contract, the max NAV is called HWM (high water mark) of NAV, which is a monotone increasing value. 

There are some constrains on max NAV:

- NAV is update lazily on every functions which require the real-time NAV value;
- NAV may not match the curve of real mark price without manually or automatically updated;
- Update NAV to a higher value not only means more profit on performance fee, but also higer risk on drawdown.

For example: assume a 20% performance fee rate, the NAV per share of fund is Ξ200 and has been recorded as the max NAV. When NAV per share goes up to Ξ400 per share, the manager will receive Ξ40 ( (Ξ400 - Ξ200) * 20% ) as performance fee; when the NAV comes to Ξ500 the manager will get Ξ10 ( (Ξ500 - Ξ400) * 20% ).