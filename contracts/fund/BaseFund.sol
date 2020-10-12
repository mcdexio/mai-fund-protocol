// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";

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

    event Received(address indexed sender, uint256 amount);
    event SetParameter(bytes32 key, int256 value);
    event Purchase(address indexed account, uint256 netAssetValue, uint256 shareAmount);
    event RequestToRedeem(address indexed account, uint256 shareAmount, uint256 slippage);
    event Redeem(address indexed account, uint256 shareAmount, uint256 returnedCollateral);
    event CancelRedeeming(address indexed account, uint256 shareAmount);
    event BidShare(address indexed bidder, address indexed account, uint256 shareAmount, uint256 slippage);

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
        address perpetualAddress,
        uint256 tokenCap
    )
        internal
        initializer
    {
        __Context_init_unchained();
        __ERC20_init_unchained(tokenName, tokenSymbol);
        __ERC20CappedRedeemable_init_unchained(tokenCap);
        __State_init_unchained();
        __MarginAccount_init_unchained(perpetualAddress);
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
        } else if (key == "globalRedeemingSlippage") {
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
     *          the received amount will not be deterministic but only a mininal amount promised.
     * @param   collateralAmount    Amount of collateral paid to purchase.
     * @param   shareAmountLimit    At least amount of share tokens received by user.
     * @param   priceLimit          NAV price limit to protect account's dealing price.
     */
    function purchase(uint256 collateralAmount, uint256 shareAmountLimit, uint256 priceLimit)
        external
        payable
        whenInState(FundState.NORMAL)
        whenNotPaused
        nonReentrant
    {
        require(collateralAmount > 0, "collateral is 0");
        require(priceLimit > 0, "price is 0");
        uint256 netAssetValuePerShare;
        if (totalSupply() == 0) {
            // when total supply is 0, nav per share cannot be determined by calculation.
            require(priceLimit >= _historicMaxNetAssetValuePerShare, "nav too low");
            netAssetValuePerShare = priceLimit;
            _historicMaxNetAssetValuePerShare = priceLimit;
        } else {
            // normal case
            uint256 netAssetValue = _updateNetAssetValue();
            require(netAssetValue > 0, "nav is 0");
            netAssetValuePerShare = _netAssetValuePerShare(netAssetValue);
            require(netAssetValuePerShare <= priceLimit, "price not met");
        }
        uint256 entranceFee = _entranceFee(collateralAmount);
        uint256 shareAmount = collateralAmount.sub(entranceFee).wdiv(netAssetValuePerShare);
        require(shareAmount >= shareAmountLimit, "share amount not met");
        // pay collateral + fee, collateral -> perpetual, fee -> fund
        uint256 rawcollateralAmount = _toRawAmount(collateralAmount);
        _pullFromUser(_msgSender(), rawcollateralAmount);
        _deposit(rawcollateralAmount);
        _mint(_msgSender(), shareAmount);
        // - update manager status
        _updateFee(entranceFee);

        emit Purchase(_msgSender(), netAssetValuePerShare, shareAmount);
    }

    /**
     * @notice  Set slippage when redeem share tokens.
     * @param   slippage    Slippage, a fixed point float, decimals == 18.
     */
    function setRedeemingSlippage(uint256 slippage)
        external
        whenNotPaused
        whenInState(FundState.NORMAL)
    {
        require(_redeemingSlippages[_msgSender()] != slippage, "same slippage");
        _setRedeemingSlippage(_msgSender(), slippage);
    }

    /**
     * @notice  Request to redeem share for collateral with a loss up to a slippage.
     *          An off-chain keeper will bid the underlaying position then push collateral to fund, then caller will be
     *          able to withdraw through `withdrawCollateral` method.
     *          Note that the slippage given will override existed value of the same account.
     *          This is to say, the slippage is by account, not by per redeem call.
     * @param   shareAmount At least amount of shares token received by user.
     */
    function redeem(uint256 shareAmount)
        external
        whenNotPaused
        whenInState(FundState.NORMAL)
        nonReentrant
    {
        address account = _msgSender();
        // steps:
        //  1. update redeem amount in account
        //  2.. create order, push order to list
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= balanceOf(account), "amount exceeded");
        require(_canRedeem(account), "cannot redeem now");
        if (_marginAccount().size > 0) {
            // have to wait for keeper to take redeemed shares (positions).
            _increaseRedeemingShareBalance(account, shareAmount);
            emit RequestToRedeem(account, shareAmount, _redeemingSlippages[account]);
        } else {
            // direct withdraw, no waiting, no slippage.
            uint256 collateralToReturn = _updateNetAssetValue().wfrac(shareAmount, totalSupply());
            _redeem(account, shareAmount, collateralToReturn);
        }
    }

    /**
     * @notice  Cancel redeem share.
     * @param   shareAmount Amount of redeem share to cancel.
     */
    function cancelRedeeming(uint256 shareAmount)
        external
        whenInState(FundState.NORMAL)
        whenNotPaused
    {
        require(shareAmount > 0, "amount is 0");
        _decreaseRedeemingShareBalance(_msgSender(), shareAmount);
        emit CancelRedeeming(_msgSender(), shareAmount);
    }

    /**
     * @notice  Take underlaying position from fund. Size of position to bid is measured by the ratio
     *          of share amount and total share supply. In redeeming, fund always CLOSE positions.
     &*
     *
     *          !!! Note that the side paramter is the expected trading direction for CALLER, not the fund's.
     *
     * @dev     size = position size * share / total share supply.
     * @param   account     Amount of collateral to withdraw.
     * @param   shareAmount Amount of share balance to bid.
     * @param   priceLimit  Price limit of dealing price. Calculated differently for long and short.
     * @param   side        Trading side for caller.
     */
    function bidRedeemingShare(
        address account,
        uint256 shareAmount,
        uint256 priceLimit,
        LibTypes.Side side
    )
        external
        whenInState(FundState.NORMAL)
        whenNotPaused
        nonReentrant
    {
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= _redeemingBalances[account], "amount exceeded");
        uint256 collateralToReturn = _updateNetAssetValue().wfrac(shareAmount, totalSupply());
        uint256 slippageLoss = _bidShare(shareAmount, priceLimit, side, _redeemingSlippages[account]);
        _decreaseRedeemingShareBalance(account, shareAmount);
        _redeem(account, shareAmount, collateralToReturn.sub(slippageLoss, "loss too high"));
        emit BidShare(_msgSender(), account, shareAmount, slippageLoss);
    }


    function _redeem(address account, uint256 shareAmount, uint256 collateralToReturn)
        internal
    {
        uint256 rawCollateralAmount = _toRawAmount(collateralToReturn);
        _burn(account, shareAmount);
        _withdraw(rawCollateralAmount);
        _pushToUser(payable(account), rawCollateralAmount);
        emit Redeem(account, shareAmount, collateralToReturn);
    }



    uint256[20] private __gap;
}
