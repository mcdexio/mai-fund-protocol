// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";

import "../lib/LibConstant.sol";
import "../lib/LibMathEx.sol";

import "../component/Context.sol";
import "./BaseFund.sol";

contract SettleableFund is
    Initializable,
    Context,
    BaseFund
{
    using SafeMath for uint256;
    using LibMathEx for uint256;
    using SafeCast for int256;

    uint256 internal _drawdownHighWaterMark;
    uint256 internal _leverageHighWaterMark;

    event Settle(address indexed account, uint256 shareAmount);

    function __SettleableFund_init(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 collateralDecimals,
        address perpetualAddress,
        uint256 tokenCap
    )
        internal
        initializer
    {
        __BaseFund_init(tokenName, tokenSymbol, collateralDecimals, perpetualAddress, tokenCap);
        __SettleableFund_init_unchained();
    }

    function __SettleableFund_init_unchained()
        internal
        initializer
    {
    }

    /**
     * @notice  Set value of configuration entry.
     * @param   key   Name string of entry to set.
     * @param   value Value of entry to set.
     */
    function setParameter(bytes32 key, int256 value)
        public
        virtual
        override
        onlyOwner
    {
        if (key == "drawdownHighWaterMark") {
            _setDrawdownHighWaterMark(value.toUint256());
        } else if (key == "leverageHighWaterMark") {
            _setLeverageHighWaterMark(value.toUint256());
        } else {
            super.setParameter(key, value);
            return;
        }
        emit SetParameter(key, value);
    }

    /**
     * @dev     Set drawdown high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm High water mark for drawdown.
     */
    function _setDrawdownHighWaterMark(uint256 hwm)
        internal
    {
        require(hwm <= LibConstant.MAX_DRAWDOWN, "too high hwm");
        _drawdownHighWaterMark = hwm;
    }

    /**
     * @dev     Set leverage high water mark. Exceeding hwm will cause emergency shutdown.
     * @param   hwm High water mark for drawdown.
     */
    function _setLeverageHighWaterMark(uint256 hwm)
        internal
    {
        require(hwm <= LibConstant.MAX_LEVERAGE, "too high hwm");
        _leverageHighWaterMark = hwm;
    }

    /**
     * @dev     Test can shutdown or not.
     *          1. This is NOT view because method in perpetual.
     *          2. shutdown conditions:
     *              - leverage reaches limit;
     *              - max drawdown reaches limit.
     * @return True if any condition is met.
     */
    function _canShutdown()
        internal
        virtual
        returns (bool)
    {
        if (_perpetualEmergency()) {
            return true;
        }
        uint256 netAssetValue = _updateNetAssetValue();
        if (_drawdown(netAssetValue) >= _drawdownHighWaterMark) {
            return true;
        }
        if (_leverage(netAssetValue).abs().toUint256() >= _leverageHighWaterMark) {
            return true;
        }
        return false;
    }

    /**
     * @notice  Call by admin, or by anyone when shutdown conditions are met.
     * @dev     No way back.
     */
    function setEmergency()
        public
        virtual
        whenInState(FundState.NORMAL)
    {
        require(_msgSender() == _owner() || _canShutdown(), "caller must be owner or cannot shutdown");
        if (_marginAccount().size > 0) {
            _redeemingBalances[_self()] = totalSupply();
        }
        _setEmergency();
    }

    /**
     * @notice  Call by admin, or by anyone when shutdown conditions are met.
     * @dev     No way back.
     */
    function setShutdown()
        public
        virtual
        whenInState(FundState.EMERGENCY)
        nonReentrant
    {
        require(_redeemingBalances[_self()] == 0, "redeem balance is not 0");
        uint256 totalAssetValue = _totalAssetValue();
        if (totalAssetValue > 0) {
            _withdraw(_toRawAmount(totalAssetValue));
        }
        _setShutdown();
    }
    // 16749    (+1014)

    /**
     * @notice  Almost be the same with bidRedeemShare but only works when stopped.
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
        whenInState(FundState.EMERGENCY)
        nonReentrant
    {
        address account = _self();
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= _redeemingBalances[account], "amount exceeded");
        uint256 slippageLoss = _bidShare(shareAmount, priceLimit, side, _redeemingSlippages[account]);
        _decreaseRedeemingShareBalance(account, shareAmount);
        emit BidShare(_msgSender(), account, shareAmount, slippageLoss);
    }

    /**
     * @notice  Settle margin account of fund.
     * @dev     perpetual -- collateral --> fund
     */
    function settleMarginAccount()
        external
        whenNotPaused
        whenInState(FundState.EMERGENCY)
        nonReentrant
    {
        // settle and withdraw to fund.
        _settle();
        _redeemingBalances[_self()] = 0;
    }

    /**
     * @notice  Like 'redeem' method but only available on stopped status.
     * @param   shareAmount At least amount of shares token received by user.
     */
    function settle(uint256 shareAmount)
        external
        whenNotPaused
        whenInState(FundState.SHUTDOWN)
        nonReentrant
    {
        address account = _msgSender();
        require(shareAmount > 0, "amount is 0");
        require(shareAmount <= balanceOf(account), "amount exceeded");
        uint256 collateralSettled = _internalBalanceOf(_self()).sub(_totalFeeClaimed);
        uint256 collateralToReturn = collateralSettled.wfrac(shareAmount, totalSupply());
        _burn(account, shareAmount);
        _pushToUser(payable(account), _toRawAmount(collateralToReturn));
        emit Settle(account, shareAmount);
    }

    uint256[18] private __gap;
}