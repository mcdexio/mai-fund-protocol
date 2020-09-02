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
    uint256 internal _settledNetAssetValue;
    mapping(address => uint256) internal _withdrawableCollaterals;

    event Received(address indexed sender, uint256 amount);
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
        __ERC20CappedRedeemable_init_unchained(cap);
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
        } else if (key == "cap") {
            _setCap(value.toUint256());
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
        uint256 netAssetValue = _netAssetValue();
        if (_marginAccount().size > 0) {
            _redeemingBalances[_self()] = totalSupply();
        } else {
            _settledNetAssetValue = netAssetValue;
        }
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
        address account = _msgSender();
        // steps:
        //  1. update redeeming amount in account
        //  2.. create order, push order to list
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= balanceOf(account), "amount excceeded");
        require(_canRedeem(account), "cannot redeem now");
        _setRedeemingSlippage(account, slippage);
        if (_marginAccount().size > 0) {
            _increaseRedeemingShareBalance(account, shareAmount);
        } else {
            uint256 collateralToReturn = _netAssetValue().wfrac(shareAmount, totalSupply());
            _burn(account, shareAmount);
            _withdraw(_toRawAmount(collateralToReturn));
            _pushToUser(payable(account), collateralToReturn);
        }
        emit Redeem(account, shareAmount, slippage);
    }

    /**
     * @notice  Withdraw collateral from fund.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function withdrawCollateral(uint256 collateralAmount)
        external
        whenNotPaused
        nonReentrant
    {
        _withdrawableCollaterals[_msgSender()] = _withdrawableCollaterals[_msgSender()]
            .sub(collateralAmount, "amount exceeded");
        _pushToUser(payable(_msgSender()), collateralAmount);
        emit Withdraw(_msgSender(), collateralAmount);
    }

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
        uint256 slippageLoss = _bidShare(shareAmount, priceLimit, side, _redeemingSlippages[trader]);
        _decreaseRedeemingShareBalance(trader, shareAmount);
        // this is the finally collateral returned to user.
        uint256 collateralToReturn = netAssetValue.wfrac(shareAmount, totalSupply())
            .sub(slippageLoss, "slippage too high");
        _burn(trader, shareAmount);
        _withdraw(_toRawAmount(collateralToReturn));
        _withdrawableCollaterals[trader] = _withdrawableCollaterals[trader].add(collateralToReturn);
        emit BidShare(_msgSender(), trader, shareAmount, slippageLoss);
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
        whenNotPaused
        whenStopped
        nonReentrant
    {
        address account = _self();
        require(_redeemingBalances[account] > 0, "no share");
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= _redeemingBalances[account], "amount excceeded");
        uint256 slippageLoss = _bidShare(shareAmount, priceLimit, side, _redeemingSlippages[account]);
        _decreaseRedeemingShareBalance(account, shareAmount);
        if (_redeemingBalances[account] == 0) {
            _settledNetAssetValue = _netAssetValue();
        }
        emit BidShare(_msgSender(), account, shareAmount, slippageLoss);
    }

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
        _redeemingBalances[_self()] = 0;
        _settledNetAssetValue = _netAssetValue();
        _isMarginSettled = true;
        _settle();
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
        require(_redeemingBalances[_self()] == 0, "cannot redeem now");
        address account = _msgSender();
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= balanceOf(account), "amount excceeded");
        uint256 collateralToReturn = _settledNetAssetValue.wfrac(shareAmount, totalSupply());
        _settledNetAssetValue = _settledNetAssetValue.sub(collateralToReturn);
        _burn(account, shareAmount);
        if (!_isMarginSettled) {
            _withdraw(_toRawAmount(collateralToReturn));
        }
        _pushToUser(payable(account), collateralToReturn);
        emit Settle(account, shareAmount);
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