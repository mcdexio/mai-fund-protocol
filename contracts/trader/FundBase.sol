// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../interface/IPerpetual.sol";
import "../interface/IDelegate.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";

import "../component/Account.sol";
import "../component/Collateral.sol";
import "../component/Configuration.sol";
import "../component/ERC20Wrapper.sol";
import "../component/ManagementFee.sol";
import "../component/Property.sol";
import "../component/Auction.sol";

contract FundBase is
    Initializable,
    ContextUpgradeSafe,
    ReentrancyGuardUpgradeSafe,
    PausableUpgradeSafe,
    StoppableUpgradeSafe,
    PerpetualWrapper,
    Account,
    Auction,
    Collateral,
    Configuration,
    ERC20Wrapper,
    ManagementFee,
    Property,
    Settlement
{
    using SafeMath for uint256;
    using LibMathEx for uint256;

    address private _manager;

    event Received(address indexed sender, uint256 amount);
    
    event Create(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event Purchase(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event RequestToRedeem(address indexed trader, uint256 shareAmount, uint256 slippage);
    event CancelRedeem(address indexed trader, uint256 shareAmount);
    event Withdraw(address indexed trader, uint256 amount);
    event Settle(address indexed trader, uint256 shareAmount);
    event Redeem(address indexed trader, uint256 shareAmount, uint256 collateralReturned);
    event BidShare(address indexed bidder, address indexed account, uint256 shareAmount, uint256 slippage);

    /**
     * @notice only accept ether from pereptual when collateral is ether. otherwise, revert.
     */
    receive() external payable {
        require(collateral() == address(0), "this contract does not accept ether");
        require(_msgSender() == address(_perpetual), "only receive ethers from perpetual");
        emit Received(msg.sender, msg.value);
    }

    /**
     * @dev     Initialize function for upgradable proxy.
     *          Decimal of erc20 will be verified if available in implementation.
     * @param   name                Name of fund share erc20 token.
     * @param   symbol              Symbol of fund share erc20 token.
     * @param   collateralDecimals  Collateral decimal.
     * @param   perpetual           Address of perpetual contract.
     * @param   mananger            Address of fund mananger.
     * @param   capacity            Max net asset value of a fund.
     */
    function initialize(
        string calldata name,
        string calldata symbol,
        uint8 collateralDecimals,
        address perpetual,
        address mananger,
        uint256 cap
    )
        external
        virtual
        initializer
    {
        __Context_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Stoppable_init_unchained();
        __Pausable_init_unchained();
        __PerpetualWrapper_init_unchained(perpetual);
        __Collateral_init_unchained(_collateral(), collateralDecimals);
        __ERC20Capped_init_unchained(name, symbol);
        __ERC20Wrapper_init_unchained(cap);
        __FundBase_init_unchained();
    }

    function __FundBase_init_unchained(IPerpetual perpetual, address manager)
        internal
        initializer
    {
        require(manager != address(0), "address of manager cannot be 0");
        _manager = manager;
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
        whenNotStopped
        nonReentrant
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(totalSupply() == 0, "share supply is not 0");
        uint256 collateralRequired = initialNetAssetValue.wmul(shareAmount);
        // pay collateral
        _pullCollateralFromUser(msg.sender, collateralRequired);
        _pushCollateralToPerpetual(collateralRequired);
        // get share
        _mintShareBalance(msg.sender, shareAmount);
        _updateFeeState(0, initialNetAssetValue);

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
        whenNotStopped
        nonReentrant
    {
        require(minimalShareAmount > 0, "share amount must be greater than 0");
        (
            uint256 netAssetValue,
            uint256 feeBeforePurchase
        ) = _netAssetValueAndFee();
        require(netAssetValue > 0, "nav should be greater than 0");

        uint256 netAssetValuePerShare = netAssetValue.wdiv(totalSupply());
        uint256 entranceFeePerShare = _entranceFee(netAssetValuePerShare);
        require(
            netAssetValuePerShare.add(entranceFeePerShare) <= netAssetValuePerShareLimit,
            "nav per share exceeds limit"
        );

        uint256 collateralPaid = minimalShareAmount.wmul(netAssetValuePerShareLimit);
        uint256 shareAmount = collateralPaid.wdiv(netAssetValuePerShare.add(entranceFeePerShare));
        require(shareAmount >= minimalShareAmount, "minimal share amount is not reached");

        uint256 entranceFee = entranceFeePerShare.wmul(shareAmount);
        require(netAssetValue.add(collateralPaid).sub(entranceFee) <= _capacity, "max capacity reached");
        // require(netAssetValuePerShare <= netAssetValuePerShareLimit, "unit nav exceeded limit");
        // pay collateral + fee, collateral -> perpetual, fee -> fund
        _pullCollateralFromUser(msg.sender, collateralPaid);
        _pushCollateralToPerpetual(collateralPaid);
        // get share
        _mintShareBalance(msg.sender, shareAmount);
        // - update manager status
        _updateFeeState(entranceFee.add(feeBeforePurchase), netAssetValuePerShare);

        emit Purchase(msg.sender, netAssetValuePerShare, shareAmount);
    }

    /**
     * @notice  Request to redeem share for collateral with a slippage.
     *          An off-chain keeper will bid the underlaying position then push collateral back to redeeming trader.
     * @param   shareAmount At least amount of shares token received by user.
     * @param   slippage    NAV price limit to protect trader's dealing price.
     */
    function redeem(uint256 shareAmount, uint256 slippage)
        external
        whenNotPaused
        whenNotStopped
        nonReentrant
    {
        // steps:
        //  1. update redeeming amount in account
        //  2.. create order, push order to list
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount <= _balances[msg.sender], "insufficient share to redeem");
        require(_canRedeem(msg.sender), "cannot redeem now");
        _setRedeemingSlippage(msg.sender, slippage);
        if (_positionSize() > 0) {
            _increaseRedeemingShareBalance(msg.sender, shareAmount);
        } else {
            _redeemImmediately(msg.sender, shareAmount);
        }
        emit Redeem(msg.sender, shareAmount, slippage);
    }

    /**
     * @notice  Like 'redeem' method but only available on stopped status.
     * @param   shareAmount At least amount of shares token received by user.
     */
    function settle(uint256 shareAmount)
        external
        whenNotPaused
        whenStopped
        nonReentrant
    {
        // steps:
        //  1. update redeeming amount in account
        //  2.. create order, push order to list
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount <= _balances[msg.sender], "insufficient share to redeem");
        require(_redeemingBalances[_self()] == 0, "cannot redeem now");
        _redeemImmediately(msg.sender, shareAmount);
        emit Settle(msg.sender, shareAmount);
    }

    /**
     * @notice  Withdraw redeemed collateral.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function withdrawCollateral(uint256 collateralAmount)
        external
        nonReentrant
        whenNotPaused
    {
        _decreaseWithdrawableCollateral(msg.sender, collateralAmount);
        _pushCollateralToUser(payable(msg.sender), collateralAmount);
        emit Withdraw(msg.sender, collateralAmount);
    }

    /**
     * @notice  Cancel redeeming share.
     * @param   shareAmount Amount of redeeming share to cancel.
     */
    function cancelRedeem(uint256 shareAmount)
        external
        whenNotPaused
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(_redeemingBalances[msg.sender] > 0, "no share to redeem");
        _decreaseRedeemingShareBalance(msg.sender, shareAmount);
        emit CancelRedeem(msg.sender, shareAmount);
    }

    /**
     * @notice  Take underlaying position from fund. Size of position to bid is measured by the ratio
     *          of share amount and total share supply.
     * @dev     size = position size * share / total share supply.
     * @param   trader      Amount of collateral to withdraw.
     * @param   shareAmount Amount of share balance to bid.
     * @param   priceLimit  Price limit of dealing price. Calculated differently for long and short.
     * @param   side        Side of underlaying position held by fund margin account.
     */
    function bidRedeemingShare(
        address trader,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        external
        nonReentrant
        whenNotPaused
        whenNotStopped
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount <= _redeemingBalances[trader], "insufficient shares to bid");
        // update fee status
        ( uint256 netAssetValue, uint256 fee ) = _netAssetValueAndFee();
        _updateFeeState(fee, netAssetValue.wdiv(totalSupply()));
        // bid shares
        uint256 slippage = _redeemingSlippages[trader];
        uint256 slippageLoss = _bidShare(shareAmount, priceLimit, side, slippage);
        // this is the finally collateral returned to user.
        // calculate collateral to return
        uint256 collateralToReturn = netAssetValue.wfrac(shareAmount, totalSupply()).sub(slippageLoss);
        // withdraw collateral from perp
        _pullCollateralFromPerpetual(collateralToReturn);
        _increaseWithdrawableCollateral(trader, collateralToReturn);
        _decreaseRedeemingShareBalance(trader, shareAmount);
        _burnShareBalance(trader, shareAmount);
        // emit Redeem(trader, shareAmount, collateralToReturn);
        emit BidShare(msg.sender, trader, shareAmount, slippage);
    }

    /**
     * @notice  Almost be the same with bidRedeemingShare but only works when stopped.
     * @param   shareAmount Amount of share balance to bid.
     * @param   priceLimit  Price limit of dealing price. Calculated differently for long and short.
     * @param   side        Side of underlaying position held by fund margin account.
     */
    function bidSettledShare(
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        external
        nonReentrant
        whenNotPaused
        whenStopped
    {
        address account = _self();
        require(shareAmount > 0, "share amount must be greater than 0");
        uint256 redeemingShareBalance = _redeemingBalances[account];
        require(shareAmount <= redeemingShareBalance, "insufficient shares to bid");

        // ( uint256 netAssetValue, ) = _netAssetValueAndFee();
        uint256 slippage = _redeemingSlippages[account];
        uint256 slippageLoss = _bidShare(shareAmount, priceLimit, side, slippage);
        // uint256 collateralToReturn = netAssetValue.wfrac(shareAmount, totalSupply()).sub(slippageLoss);
        // _pullCollateralFromPerpetual(collateralToReturn);
        _decreaseRedeemingShareBalance(account, shareAmount);
        // emit Settle(shareAmount);
        emit BidShare(msg.sender, account, shareAmount, slippageLoss);
    }


    function _redeemImmediately(address account, uint256 shareAmount)
        internal
        returns (uint256 collateralToReturn)
    {
        ( uint256 netAssetValue, uint fee ) = _netAssetValueAndFee();
        _updateFeeState(fee, netAssetValue.wdiv(totalSupply()));
        collateralToReturn = netAssetValue.wfrac(shareAmount, totalSupply());
        _burnShareBalance(account, shareAmount);
        _pullCollateralFromPerpetual(collateralToReturn);
        _pushCollateralToUser(payable(account), collateralToReturn);
    }
}