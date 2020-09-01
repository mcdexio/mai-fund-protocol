// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";

import "../component/Auction.sol";
import "../component/Collateral.sol";
import "../component/Context.sol";
import "../component/Settlement.sol";
import "../component/Stoppable.sol";


contract Core is
    Initializable,
    Context,
    Status,
    Auction,
    Collateral,
    Settlement,
    PausableUpgradeSafe,
    ReentrancyGuardUpgradeSafe
{
    using SafeMath for uint256;
    using LibMathEx for uint256;
    using SafeCast for int256;

    bool internal _isMarginSettled;
    mapping(address => uint256) internal _withdrawableCollaterals;

    event Received(address indexed sender, uint256 amount);
    event Create(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event Purchase(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event Redeem(address indexed trader, uint256 shareAmount, uint256 slippage);
    event Settle(address indexed trader, uint256 shareAmount);
    event CancelRedeem(address indexed trader, uint256 shareAmount);
    event Withdraw(address indexed trader, uint256 collateralAmount);
    event BidShare(address indexed bidder, address indexed account, uint256 shareAmount, uint256 slippage);
    event SetParameter(bytes32 key, int256 value);

    /**
     * @notice only accept ether from pereptual when collateral is ether. otherwise, revert.
     */
    receive() external payable {
        require(!_isCollateralERC20(), "ether not acceptable");
        require(_msgSender() == _perpetualAddress(), "sender must be perpetual");
        emit Received(_msgSender(), msg.value);
    }

    function __Core_init(
        string calldata name,
        string calldata symbol,
        uint8 collateralDecimals,
        address perpetual,
        uint256 cap
    )
        internal
        initializer
    {
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Capped_init_unchained(cap);
        __ERC20Redeemable_init_unchained();
        __MarginAccount_init_unchained(perpetual);
        __Collateral_init_unchained(_collateral(), collateralDecimals);
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Stoppable_init_unchained();
        __Core_init_unchained();
    }

    function __Core_init_unchained()
        internal
        initializer
    {

    }

    // =================================== Admin Methods ===================================
    // from 14404
    modifier onlyOwner() {
        require(_msgSender() == _owner(), "caller must be owner");
        _;
    }

    /**
     * @notice  Set value of configuration entry.
     * @param   key   Name string of entry to set.
     * @param   value Value of entry to set.
     */
    function setParameter(bytes32 key, int256 value)
        public
        virtual
        onlyOwner
    {
        if (key == "redeemingLockPeriod") {
            _setRedeemingLockPeriod(value.toUint256());
        } else if (key == "drawdownHighWaterMark") {
            _setDrawdownHighWaterMark(value.toUint256());
        } else if (key == "leverageHighWaterMark") {
            _setLeverageHighWaterMark(value.toUint256());
        } else if (key == "entranceFeeRate") {
            _setEntranceFeeRate(value.toUint256());
        } else if (key == "streamingFeeRate") {
            _setStreamingFeeRate(value.toUint256());
        } else if (key == "performanceFeeRate") {
            _setPerformanceFeeRate(value.toUint256());
        } else if (key == "settledRedeemingSlippage") {
            _setRedeemingSlippage(_self(), value.toUint256());
        } else {
            revert("unrecognized key");
        }
        emit SetParameter(key, value);
    }
    // 15735 (+1331)

    /**
     * @notice  Call by admin, or by anyone when shutdown conditions are met.
     * @dev     No way back.
     */
    function shutdown()
        external
        whenNotStopped
    {
        require(_msgSender() == _owner() || _canShutdown(), "caller must be owner or cannot shutdown");
        // claim fee until shutting down
        _netAssetValue();
        _redeemingBalances[_self()] = totalSupply();
        // enter shutting down mode.
        _stop();
        emit Shutdown();
    }
    // 16749    (+1014)

    /**
     * @notice  Approve perpetual as spender of collateral.
     * @param   rawCollateralAmount Approval amount.
     */
    function approvePerpetual(uint256 rawCollateralAmount)
        external
        onlyOwner
    {
        _approvalTo(address(_perpetual), rawCollateralAmount);
    }

    /**
     * @notice Pause the fund.
     */
    function pause()
        external
        onlyOwner
    {
        _pause();
    }

    /**
     * @dev Unpause the fund.
     */
    function unpause()
        external
        onlyOwner
    {
        _unpause();
    }
    // 17553    (+804)

    // =================================== User Methods ===================================
    /**
     * @notice  Purchase share, Total collataral required == amount * nav per share.
     *          Since the transfer mechanism of ether and erc20 is totally different,
     *          the received amount wiil not be deterministic but only a mininal amount promised.
     * @param   collateralAmount    Amount of collateral paid to purchase.
     * @param   minimalShareAmount  At least amount of shares token received by user.
     * @param   pricePerShareLimit  NAV price limit to protect trader's dealing price.
     */
    function purchase(uint256 collateralAmount, uint256 minimalShareAmount, uint256 pricePerShareLimit)
        external
        payable
        whenNotPaused
        whenNotStopped
        nonReentrant
    {
        require(minimalShareAmount > 0, "amount is 0");
        uint256 netAssetValuePerShare;
        if (totalSupply() == 0) {
            require(pricePerShareLimit >= _maxNetAssetValuePerShare, "nav too low");
            netAssetValuePerShare = pricePerShareLimit;
            _maxNetAssetValuePerShare = pricePerShareLimit;
        } else {
            uint256 netAssetValue = _netAssetValue();
            require(netAssetValue > 0, "nav is 0");
            netAssetValuePerShare = _netAssetValuePerShare(netAssetValue);
            require(netAssetValuePerShare <= pricePerShareLimit, "nav exceeded");
        }
        uint256 entranceFee = _entranceFee(collateralAmount);
        uint256 shareAmount = collateralAmount.sub(entranceFee).wdiv(netAssetValuePerShare);
        require(shareAmount >= minimalShareAmount, "min share not met");
        // pay collateral + fee, collateral -> perpetual, fee -> fund
        _pullFromUser(_msgSender(), collateralAmount);
        _deposit(_toRawAmount(collateralAmount));
        _mint(_msgSender(), shareAmount);
        // - update manager status
        _updateFee(entranceFee);

        emit Purchase(_msgSender(), netAssetValuePerShare, shareAmount);
    }
    // 7616     +1878

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
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= balanceOf(_msgSender()), "amount excceeded");
        require(_canRedeem(_msgSender()), "cannot redeem now");
        _setRedeemingSlippage(_msgSender(), slippage);
        if (_marginAccount().size > 0) {
            _increaseRedeemingShareBalance(_msgSender(), shareAmount);
        } else {
            _redeemImmediately(_msgSender(), shareAmount);
        }
        emit Redeem(_msgSender(), shareAmount, slippage);
    }
    // 9927     +2,311 (_redeemImmediately included)

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
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= balanceOf(_msgSender()), "amount excceeded");
        require(_redeemingBalances[_self()] == 0, "cannot redeem now");
        _redeemImmediately(_msgSender(), shareAmount);
        emit Settle(_msgSender(), shareAmount);
    }
    // 10402    +475 (_redeemImmediately excluded)

    /**
     * @notice  Cancel redeeming share.
     * @param   shareAmount Amount of redeeming share to cancel.
     */
    function cancelRedeem(uint256 shareAmount)
        external
        whenNotPaused
        whenNotStopped
    {
        require(shareAmount > 0, "amount is 0");
        _decreaseRedeemingShareBalance(_msgSender(), shareAmount);
        emit CancelRedeem(_msgSender(), shareAmount);
    }
    // 10907    +505

    /**
     * @notice  Withdraw collateral from fund.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function withdrawCollateral(uint256 collateralAmount)
        external
        whenNotPaused
        nonReentrant
    {
        _decreaseWithdrawableCollateral(_msgSender(), collateralAmount);
        _pushToUser(payable(_msgSender()), collateralAmount);
        emit Withdraw(_msgSender(), collateralAmount);
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
        whenNotPaused
        whenNotStopped
        nonReentrant
    {
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= _redeemingBalances[trader], "amount excceeded");
        uint256 netAssetValue = _netAssetValue();
        // bid shares
        uint256 slippageLoss = _bidRedeemingShare(trader, shareAmount, priceLimit, side);
        // this is the finally collateral returned to user.
        uint256 collateralToReturn = netAssetValue.wfrac(shareAmount, totalSupply())
            .sub(slippageLoss, "slippage too high");
        _burn(trader, shareAmount);
        _withdraw(_toRawAmount(collateralToReturn));
        _increaseWithdrawableCollateral(trader, collateralToReturn);
    }
    // 13931    +3024

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
        whenNotPaused
        whenStopped
        nonReentrant
    {
        address account = _self();
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= _redeemingBalances[account], "amount excceeded");
        _bidRedeemingShare(account, shareAmount, priceLimit, side);
    }
    // 14396    +465

    /**
     * @notice Settle margin account of fund.
     */
    function settleMarginAccount()
        external
        whenNotPaused
        whenStopped
        nonReentrant
    {
        // clean all positions and withdraw
        require(_isMarginSettled == false, "already settled");
        _settle();
        _isMarginSettled = true;
    }

    /**
     * @dev Code shared by bidRedeemingShare and bidSettledShare.
     */
    function _bidRedeemingShare(
        address trader,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        internal
        returns (uint256 slippageLoss)
    {
        slippageLoss = _bidShare(shareAmount, priceLimit, side, _redeemingSlippages[trader]);
        _decreaseRedeemingShareBalance(trader, shareAmount);
        emit BidShare(_msgSender(), trader, shareAmount, slippageLoss);
    }

    /**
     * @notice  Increase collateral amount which can be withdraw by user.
     * @param   trader      Address of share owner.
     * @param   amount      Amount of collateral to increase.
     */
    function _increaseWithdrawableCollateral(address trader, uint256 amount)
        internal
    {
        _withdrawableCollaterals[trader] = _withdrawableCollaterals[trader].add(amount);
        emit IncreaseWithdrawableCollateral(trader, amount);
    }

    /**
     * @notice  Decrease collateral amount which can be withdraw by user.
     * @param   trader      Address of share owner.
     * @param   amount      Amount of collateral to decrease.
     */
    function _decreaseWithdrawableCollateral(address trader, uint256 amount)
        internal
    {
        _withdrawableCollaterals[trader] = _withdrawableCollaterals[trader].sub(amount, "amount exceeded");
        emit DecreaseWithdrawableCollateral(trader, amount);
    }

    /**
     * @notice  Redeem and get collateral immediately.
     */
    function _redeemImmediately(address account, uint256 shareAmount)
        internal
        returns (uint256 collateralToReturn)
    {
        collateralToReturn = _netAssetValue().wfrac(shareAmount, totalSupply());
        _burn(account, shareAmount);
        if (!_isMarginSettled) {
            _withdraw(_toRawAmount(collateralToReturn));
        }
        _pushToUser(payable(account), collateralToReturn);
    }

    /**
     * @notice  Override net asset value, update fee.
     */
    function _netAssetValue()
        internal
        virtual
        override
        returns (uint256)
    {
        uint256 netAssetValue = super._netAssetValue();
        if (!stopped()) {
            netAssetValue = _updateFeeState(netAssetValue);
        }
        return netAssetValue;
    }

    uint256[18] private __gap;
}