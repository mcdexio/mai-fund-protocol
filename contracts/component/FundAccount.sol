// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "../storage/FundStorage.sol";

/**
 * @title Implemetation of operations on fund account.
 */
contract FundAccount is FundStorage {

    using SafeMath for uint256;

    event IncreaseShareBalance(address indexed trader, uint256 shareAmount);
    event DecreaseShareBalance(address indexed trader, uint256 shareAmount);
    event IncreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);
    event DecreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);
    event MintShareBalance(address indexed trader, uint256 shareAmount);
    event BurnShareBalance(address indexed trader, uint256 shareAmount);
    event IncreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event DecreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event SetRedeemingSlippage(address indexed trader, uint256 slippage);

    /**
     * @notice  Share balance to redeem.
     * @dev     Before actually sold (redeemed), the share will still be active.
     * @param   trader  Address of share owner.
     * @return Amount of redeemable share balance.
     */
    function _redeemableShareBalance(address trader)
        internal
        view
        returns (uint256)
    {
        if (!_canRedeem(trader)) {
            return 0;
        }
        return _balances[trader].sub(_redeemingBalances[trader]);
    }

    /**
     * @notice  Increase share balance.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to purchase.
     */
    function _increaseShareBalance(address trader, uint256 shareAmount)
        internal
    {
        _balances[trader] = _balances[trader].add(shareAmount);
        emit IncreaseShareBalance(trader, shareAmount);
    }

    /**
     * @notice  Decrease share balance.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to purchase.
     */
    function _decreaseShareBalance(address trader, uint256 shareAmount)
        internal
    {
        // update balance
        _balances[trader] = _balances[trader].sub(shareAmount, "insufficient share balance");
        emit DecreaseShareBalance(trader, shareAmount);
    }

    /**
     * @notice  Increase share balance, also increase the total supply.
     * @dev     Will update purchase time.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to mint.
     */
    function _mintShareBalance(address trader, uint256 shareAmount)
        internal
    {
        _increaseShareBalance(trader, shareAmount);
        _lastPurchaseTimes[trader] = _now();
        _totalSupply = _totalSupply.add(shareAmount);

        emit MintShareBalance(trader, shareAmount);
    }

    /**
     * @notice  Decrease share balance,  also decrease the total supply.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to burn.
     */
    function _burnShareBalance(address trader, uint256 shareAmount)
        internal
    {
        _decreaseShareBalance(trader, shareAmount);
        _totalSupply = _totalSupply.sub(shareAmount, "insufficient share balance");

        emit BurnShareBalance(trader, shareAmount);
    }

    /**
     * @dev     After purchasing, user have to wait for a period to redeem.
     *          Note that new purchase will refresh the time point.
     * @param   trader      Address of share owner.
     * @return  True if shares are unlocked for redeeming.
     */
    function _canRedeem(address trader)
        internal
        view
        returns (bool)
    {
        if (_redeemingLockPeriod == 0) {
            return true;
        }
        return _lastPurchaseTimes[trader].add(_redeemingLockPeriod) < _now();
    }

    /**
     * @notice  Set redeeming slippage, a fixed float in decimals 18, 0.01 ether == 1%.
     * @param   trader      Address of share owner.
     * @param   slippage    Slipage percent of redeeming rate.
     */
    function _setRedeemingSlippage(address trader, uint256 slippage)
        internal
    {
        if (slippage == _redeemingSlippages[trader]) {
            return;
        }
        require(slippage < LibConstant.RATE_UPPERBOUND, "slippage must be less then 100%");
        _redeemingSlippages[trader] = slippage;
        emit SetRedeemingSlippage(trader, slippage);
    }

    /**
     * @notice  Redeem share balance, to prevent redeemed amount exceed total amount.
     * @dev     Slippage will overwrite previous setting.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to redeem.
     */
    function _increaseRedeemingShareBalance(address trader, uint256 shareAmount)
        internal
    {
        require(shareAmount <= _redeemableShareBalance(trader), "no enough share to redeem");
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader].add(shareAmount);
        emit IncreaseRedeemingShareBalance(trader, shareAmount);
    }

    /**
     * @notice  Redeem share balance, to prevent redeemed amount exceed total amount.
     * @param   trader       Address of share owner.
     * @param   shareAmount   Amount of share to redeem.
     */
    function _decreaseRedeemingShareBalance(address trader, uint256 shareAmount)
        internal
    {
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader]
            .sub(shareAmount, "insufficient redeeming share balance");
        emit DecreaseRedeemingShareBalance(trader, shareAmount);
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
        _withdrawableCollaterals[trader] = _withdrawableCollaterals[trader]
            .sub(amount, "insufficient withdrawable collateral");
        emit DecreaseWithdrawableCollateral(trader, amount);
    }
}