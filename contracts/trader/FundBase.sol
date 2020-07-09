// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../external/openzeppelin-upgrades/contracts/Initializable.sol";

import "../interface/IPerpetual.sol";
import "../interface/IDelegate.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";

import "../storage/FundStorage.sol";
import "../component/FundAccount.sol";
import "../component/FundCollateral.sol";
import "../component/FundConfiguration.sol";
import "../component/FundERC20Wrapper.sol";
import "../component/FundFee.sol";
import "../component/FundProperty.sol";
import "./FundManagement.sol";


contract FundBase is
    FundStorage,
    FundAccount,
    FundCollateral,
    FundConfiguration,
    FundERC20Wrapper,
    FundFee,
    FundProperty,
    Initializable
{
    using SafeMath for uint256;
    using LibMathEx for uint256;

    event Received(address indexed sender, uint256 amount);
    event Create(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event Purchase(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event RequestToRedeem(address indexed trader, uint256 shareAmount, uint256 slippage);
    event CancelRedeeming(address indexed trader, uint256 shareAmount);
    event Redeem(address indexed trader, uint256 netAssetValue, uint256 shareAmount);


    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @dev Initialize function for upgradable proxy.
     */
    function initialize(
        string calldata name,
        string calldata symbol,
        address collataral,
        uint8 collataralDecimals,
        address perpetual,
        address maintainer
    )
        external
        initializer
    {
        _name = name;
        _symbol = symbol;
        _maintainer = maintainer;
        _creator = msg.sender;
        _perpetual = IPerpetual(perpetual);
        FundCollateral.initialize(collataral, collataralDecimals);
    }

    function setDelegator(address delegate) external {
        IDelegate(delegate).setDelegator(address(_perpetual), _maintainer);
    }

    function unsetDelegator(address delegate) external {
        IDelegate(delegate).unsetDelegator(address(_perpetual));
    }

    /**
     * @dev Call once, when NAV is 0 (position size == 0).
     * @param shareAmount           Amount of shares to purchase.
     * @param initialNetAssetValue  Initial NAV defined by creator.
     */
    function create(uint256 shareAmount, uint256 initialNetAssetValue)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(_totalSupply == 0, "share supply is not 0");
        uint256 collateralRequired = initialNetAssetValue.wmul(shareAmount);
        // pay collateral
        pullCollateralFromUser(msg.sender, collateralRequired);
        pushCollateralToPerpetual(collateralRequired);
        // get share
        increaseShareBalance(msg.sender, shareAmount);
        updateFeeState(0, initialNetAssetValue);

        emit Create(msg.sender, initialNetAssetValue, shareAmount);
    }

    /**
     * @dev Purchase share, Total collataral required = amount x unit net value.
     * @param shareAmount           Amount of shares to purchase.
     * @param netAssetValueLimit    NAV price limit to protect trader's dealing price.
     */
    function purchase(uint256 shareAmount, uint256 netAssetValueLimit)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        (
            uint256 totalAssetValue,
            uint256 feeBeforePurchase
        ) = calculateFee();
        uint256 netAssetValue = totalAssetValue.wdiv(_totalSupply);
        require(netAssetValue <= netAssetValueLimit, "unit net value exceeded limit");

        uint256 collateralRequired = netAssetValue.wmul(shareAmount);
        uint256 entranceFee = calculateEntranceFee(collateralRequired);
        // pay collateral + fee, collateral -> perpetual, fee -> fund
        pullCollateralFromUser(msg.sender, collateralRequired.add(entranceFee));
        pushCollateralToPerpetual(collateralRequired);
        // get share
        increaseShareBalance(msg.sender, shareAmount);
        // - update manager status
        updateFeeState(entranceFee.add(feeBeforePurchase), netAssetValue);

        emit Purchase(msg.sender, netAssetValue, shareAmount);
    }

    function requestToRedeem(uint256 shareAmount, uint256 slippage)
        external
        whenNotPaused
    {
        // steps:
        //  1. update redeeming amount in account
        //  2.. create order, push order to list

        require(shareAmount > 0, "amount must be greater than 0");
        require(slippage < LibConstant.RATE_UPPERBOUND, "slippage must be less then 100%");
        require(canRedeem(msg.sender), "cannot redeem now");

        // update user account
        increaseRedeemingAmount(msg.sender, shareAmount, slippage);
        emit RequestToRedeem(msg.sender, shareAmount, slippage);

        if (positionSize() == 0) {
            redeem(msg.sender, shareAmount, 0);
        }
    }

    function cancelRedeeming(uint256 shareAmount)
        external
        whenNotPaused
    {
        require(_redeemingBalances[msg.sender] > 0, "no share to redeem");
        decreaseRedeemingAmount(msg.sender, shareAmount);
        emit CancelRedeeming(msg.sender, shareAmount);
    }

    function takeRedeemingShare(
        address trader,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        external
        whenNotPaused
    {
        // order
        require(shareAmount <= _redeemingBalances[trader], "insufficient shares to take");
        // trading price and loss amount equivalent to slippage
        LibTypes.MarginAccount memory fundMarginAccount = marginAccount();
        require(fundMarginAccount.side == side, "unexpected side");
        uint256 redeemPercentage = shareAmount.wdiv(_totalSupply);
        // TODO: align to tradingLotSize
        uint256 redeemAmount = fundMarginAccount.size.wmul(redeemPercentage);
        LibTypes.Side redeemingSide = fundMarginAccount.side == LibTypes.Side.LONG?
            LibTypes.Side.SHORT : LibTypes.Side.LONG;
        uint256 slippage = _redeemingSlippage[trader];
        (
            uint256 tradingPrice,
            uint256 priceLoss
        ) = calculateTradingPrice(fundMarginAccount.side, slippage);
        validatePrice(side, tradingPrice, priceLimit);
        _perpetual.tradePosition(
            self(),
            msg.sender,
            redeemingSide,
            tradingPrice,
            redeemAmount
        );
        uint256 slippageValue = priceLoss.wmul(redeemAmount);
        redeem(trader, shareAmount, slippageValue);
    }

    /**
     * @dev Redeem shares.
     */
    function redeem(address trader, uint256 shareAmount, uint256 slippageValue)
        internal
        nonReentrant
    {
        // steps:
        //  1. calculate fee.
        //  2. caluclate fee excluded nav
        //  3. collateral return = nav * share amount
        //  4. push collateral -> user
        //  4. push fee -> maintainer
        // 6. streaming fee + performance fee -> maintainer

        require(shareAmount > 0, "amount must be greater than 0");
        // - calculate decreased amount
        (
            uint256 totalAssetValue,
            uint256 fee
        ) = calculateFee();
        uint256 netAssetValue = totalAssetValue.wdiv(_totalSupply);
        // note the loss amount is caused by slippage set by user.
        uint256 collateralToReturn = netAssetValue.wmul(shareAmount).sub(slippageValue);
        // pay share
        decreaseRedeemingAmount(trader, shareAmount);
        decreaseShareBalance(trader, shareAmount);
        // get collateral
        pullCollateralFromPerpetual(collateralToReturn);
        pushCollateralToUser(payable(trader), collateralToReturn);
        // - decrease total supply
        updateFeeState(fee, netAssetValue);

        emit Redeem(trader, netAssetValue, shareAmount);
    }

    function calculateFee()
        internal
        returns (uint256 assetValue, uint256 fee)
    {
        assetValue = totalAssetValue();
        // streaming fee, performance fee excluded
        uint256 streamingFee = calculateStreamingFee(assetValue);
        assetValue = assetValue.sub(streamingFee);
        uint256 performanceFee = calculatePerformanceFee(assetValue);
        assetValue = assetValue.sub(performanceFee);
        fee = streamingFee.add(performanceFee);
    }

    function validatePrice(LibTypes.Side side, uint256 price, uint256 priceLimit) internal pure {
        if (side == LibTypes.Side.LONG) {
            require(price <= priceLimit, "price too high for long");
        } else {
            require(price >= priceLimit, "price too low for short");
        }
    }

    function calculateTradingPrice(LibTypes.Side side, uint256 slippage)
        internal
        returns (uint256 tradingPrice, uint256 priceLoss)
    {
        uint256 markPrice = _perpetual.markPrice();
        priceLoss = markPrice.wmul(slippage);
        tradingPrice = side == LibTypes.Side.LONG? markPrice.add(priceLoss): markPrice.sub(priceLoss);
    }
}