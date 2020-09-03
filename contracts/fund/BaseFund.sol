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
import "../component/Core.sol";

contract BaseFund is
    Initializable,
    Context,
    Core,
    Auction,
    Collateral,
    PausableUpgradeSafe,
    ReentrancyGuardUpgradeSafe
{
    using SafeMath for uint256;
    using LibMathEx for uint256;
    using SafeCast for int256;

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

    function __BaseFund_init(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 collateralDecimals,
        address perpetual,
        uint256 cap
    )
        internal
        initializer
    {
        __Context_init_unchained();
        __ERC20_init_unchained(tokenName, tokenSymbol);
        __ERC20CappedRedeemable_init_unchained(cap);
        __State_init_unchained();
        __MarginAccount_init_unchained(perpetual);
        __Collateral_init_unchained(_collateral(), collateralDecimals);
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __BaseFund_init_unchained();
    }

    function __BaseFund_init_unchained()
        internal
        initializer
    {
    }

    // =================================== Admin Methods ===================================
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

    // =================================== User Methods ===================================
    /**
     * @notice  Purchase share, Total collataral required == amount * nav per share.
     *          Since the transfer mechanism of ether and erc20 is totally different,
     *          the received amount wiil not be deterministic but only a mininal amount promised.
     * @param   collateralAmount    Amount of collateral paid to purchase.
     * @param   shareAmountLimit    At least amount of shares token received by user.
     * @param   pricePerShareLimit  NAV price limit to protect trader's dealing price.
     */
    function purchase(uint256 collateralAmount, uint256 shareAmountLimit, uint256 pricePerShareLimit)
        external
        payable
        whenInState(FundState.Normal)
        whenNotPaused
        nonReentrant
    {
        require(collateralAmount > 0, "collateral is 0");
        require(pricePerShareLimit > 0, "price is 0");
        uint256 netAssetValuePerShare;
        if (totalSupply() == 0) {
            // when total supply is 0, nav per share cannot be determined by calculation.
            require(pricePerShareLimit >= _maxNetAssetValuePerShare, "nav too low");
            netAssetValuePerShare = pricePerShareLimit;
            _maxNetAssetValuePerShare = pricePerShareLimit;
        } else {
            // normal case
            uint256 netAssetValue = _updateNetAssetValue();
            require(netAssetValue > 0, "nav is 0");
            netAssetValuePerShare = _netAssetValuePerShare(netAssetValue);
            require(netAssetValuePerShare <= pricePerShareLimit, "price not met");
        }
        uint256 entranceFee = _entranceFee(collateralAmount);
        uint256 shareAmount = collateralAmount.sub(entranceFee).wdiv(netAssetValuePerShare);
        require(shareAmount >= shareAmountLimit, "share amount not met");
        // pay collateral + fee, collateral -> perpetual, fee -> fund
        uint256 rawcollateralAmount = _toRawAmount(collateralAmount);
        _pullFromUser(_msgSender(), rawcollateralAmount);
        _deposit(_toRawAmount(rawcollateralAmount));
        _mint(_msgSender(), shareAmount);
        // - update manager status
        _updateFee(entranceFee);

        emit Purchase(_msgSender(), netAssetValuePerShare, shareAmount);
    }

    /**
     * @notice  Request to redeem share for collateral with a loss up to a slippage.
     *          An off-chain keeper will bid the underlaying position then push collateral to fund, then caller will be
     *          able to withdraw through `withdrawCollateral` method.
     *          Note that the slippage given will override existed value of the same account.
     *          This is to say, the slippage is by account, not by per redeem call.
     * @param   shareAmount At least amount of shares token received by user.
     * @param   slippage    NAV price limit to protect trader's dealing price.
     */
    function redeem(uint256 shareAmount, uint256 slippage)
        external
        whenNotPaused
        whenInState(FundState.Normal)
        nonReentrant
    {
        address account = _msgSender();
        // steps:
        //  1. update redeeming amount in account
        //  2.. create order, push order to list
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= balanceOf(account), "amount excceeded");
        require(_canRedeem(account), "cannot redeem now");

        _setRedeemingSlippage(_msgSender(), slippage);
        if (_marginAccount().size > 0) {
            // have to wait for keeper to take redeemed shares (positions).
            _increaseRedeemingShareBalance(account, shareAmount);
        } else {
            // direct withdraw, no waiting, no slippage.
            uint256 collateralToReturn = _updateNetAssetValue().wfrac(shareAmount, totalSupply());
            uint256 rawCollateralAmount = _toRawAmount(collateralToReturn);
            _burn(account, shareAmount);
            _withdraw(rawCollateralAmount);
            _pushToUser(payable(account), rawCollateralAmount);
        }

        emit Redeem(account, shareAmount, slippage);
    }

    /**
     * @notice  Cancel redeeming share.
     * @param   shareAmount Amount of redeeming share to cancel.
     */
    function cancelRedeem(uint256 shareAmount)
        external
        whenNotPaused
        whenInState(FundState.Normal)
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
        whenInState(FundState.Normal)
        nonReentrant
    {
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= _redeemingBalances[trader], "amount excceeded");
        uint256 netAssetValue = _updateNetAssetValue();
        uint256 slippageLoss = _bidShare(shareAmount, priceLimit, side, _redeemingSlippages[trader]);
        _decreaseRedeemingShareBalance(trader, shareAmount);
        uint256 collateralToReturn = netAssetValue.wfrac(shareAmount, totalSupply())
            .sub(slippageLoss, "slippage too high");
        _burn(trader, shareAmount);
        _withdraw(_toRawAmount(collateralToReturn));
        _withdrawableCollaterals[trader] = _withdrawableCollaterals[trader].add(collateralToReturn);
        emit BidShare(_msgSender(), trader, shareAmount, slippageLoss);
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
        _pushToUser(payable(_msgSender()), _toRawAmount(collateralAmount));
        emit Withdraw(_msgSender(), collateralAmount);
    }

    uint256[19] private __gap;
}