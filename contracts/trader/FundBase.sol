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
import "./FundAuction.sol";

contract FundBase is
    FundStorage,
    FundAccount,
    FundCollateral,
    FundConfiguration,
    FundERC20Wrapper,
    FundFee,
    FundProperty,
    FundAuction,
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
        require(msg.sender == address(_perpetual), "only receive ethers from perpetual");
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
        address mananger
    )
        external
        virtual
        initializer
    {
        _name = name;
        _symbol = symbol;
        _manager = mananger;
        _creator = msg.sender;
        _perpetual = IPerpetual(perpetual);
        FundCollateral.initialize(collataral, collataralDecimals);
    }

    function getCurrentLeverage()
        external
        returns (int256)
    {
        return getLeverage();
    }

    function getNetAssetValue()
        external
        returns (uint256)
    {
        (uint256 netAssetValue,) = getNetAssetValueAndFee();
        return netAssetValue;
    }

    function getNetAssetValuePerShare()
        external
        returns (uint256)
    {
        (uint256 netAssetValuePerShare,) = getNetAssetValuePerShareAndFee();
        return netAssetValuePerShare;
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
        mintShareBalance(msg.sender, shareAmount);
        updateFeeState(0, initialNetAssetValue);

        emit Create(msg.sender, initialNetAssetValue, shareAmount);
    }

    /**
     * @dev Purchase share, Total collataral required = amount x unit net value.
     * @param minimalShareAmount            At least amount of shares token received by user.
     * @param netAssetValuePerShareLimit    NAV price limit to protect trader's dealing price.
     */
    function purchase(uint256 minimalShareAmount, uint256 netAssetValuePerShareLimit)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(minimalShareAmount > 0, "share amount must be greater than 0");
        (
            uint256 netAssetValuePerShare,
            uint256 feeBeforePurchase
        ) = getNetAssetValuePerShareAndFee();
        require(netAssetValuePerShare > 0, "unit nav should be greater than 0");
        // require(netAssetValuePerShare <= netAssetValuePerShareLimit, "unit nav exceeded limit");
        require(netAssetValuePerShare <= netAssetValuePerShareLimit, "nav per share exceeds limit");
        uint256 collateralLimit = minimalShareAmount.wmul(netAssetValuePerShareLimit);
        uint256 entranceFee = getEntranceFee(collateralLimit);
        uint256 shareAmount = collateralLimit.sub(entranceFee).wdiv(netAssetValuePerShare);
        require(shareAmount >= minimalShareAmount, "minimal share amount is not reached");
        // pay collateral + fee, collateral -> perpetual, fee -> fund
        pullCollateralFromUser(msg.sender, collateralLimit);
        pushCollateralToPerpetual(collateralLimit);
        // get share
        mintShareBalance(msg.sender, shareAmount);
        // - update manager status
        updateFeeState(entranceFee.add(feeBeforePurchase), netAssetValuePerShare);

        emit Purchase(msg.sender, netAssetValuePerShare, shareAmount);
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

        if (getPositionSize() == 0) {
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

    function bidRedeemingShare(
        address trader,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        external
        whenNotPaused
    {
        uint256 slippageLoss = bidShare(trader, shareAmount, priceLimit, side);
        redeem(trader, shareAmount, slippageLoss);
    }

    /**
     * @dev Redeem shares.
     */
    function redeem(address trader, uint256 shareAmount, uint256 slippageLoss)
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
            uint256 netAssetValuePerShare,
            uint256 feeBeforeRedeem
        ) = getNetAssetValuePerShareAndFee();
        // note the loss amount is caused by slippage set by user.
        uint256 collateralToReturn = netAssetValuePerShare.wmul(shareAmount).sub(slippageLoss);
        // pay share
        decreaseRedeemingAmount(trader, shareAmount);
        burnShareBalance(trader, shareAmount);
        // get collateral
        pullCollateralFromPerpetual(collateralToReturn);
        pushCollateralToUser(payable(trader), collateralToReturn);
        // - decrease total supply
        updateFeeState(feeBeforeRedeem, netAssetValuePerShare);

        emit Redeem(trader, netAssetValuePerShare, shareAmount);
    }

    function bidShuttingDownShare(
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        external
        whenStopped
    {
        // order
        address fundAccount = self();
        bidShare(fundAccount, shareAmount, priceLimit, side);
        decreaseRedeemingAmount(fundAccount, shareAmount);
        burnShareBalance(fundAccount, shareAmount);
    }

}