// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/LibUtils.sol";
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

    /**
     * @notice  Share balance to redeem.
     * @dev     Before actually sold (redeemed), the share will still be active.
     * @param   trader  Address of share owner.
     * @return Amount of redeemable share balance.
     */
    function redeemableShareBalance(address trader)
        internal
        view
        returns (uint256)
    {
        if (!canRedeem(trader)) {
            return 0;
        }
        return _balances[trader].sub(_redeemingBalances[trader]);
    }

    /**
     * @notice  Increase share balance.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to purchase.
     */
    function increaseShareBalance(address trader, uint256 shareAmount)
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        _balances[trader] = _balances[trader].add(shareAmount);

        emit IncreaseShareBalance(trader, shareAmount);
    }

    /**
     * @notice  Decrease share balance.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to purchase.
     */
    function decreaseShareBalance(address trader, uint256 shareAmount)
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
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
    function mintShareBalance(address trader, uint256 shareAmount)
        internal
    {
        increaseShareBalance(trader, shareAmount);
        _lastPurchaseTime[trader] = LibUtils.currentTime();
        _totalSupply = _totalSupply.add(shareAmount);

        emit MintShareBalance(trader, shareAmount);
    }

    /**
     * @notice  Decrease share balance,  also decrease the total supply.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to burn.
     */
    function burnShareBalance(address trader, uint256 shareAmount)
        internal
    {
        decreaseShareBalance(trader, shareAmount);
        _totalSupply = _totalSupply.sub(shareAmount);

        emit BurnShareBalance(trader, shareAmount);
    }

    /**
     * @dev     After purchasing, user have to wait for a period to redeem.
     *          Note that new purchase will refresh the time point.
     * @param   trader      Address of share owner.
     * @return  True if shares are unlocked for redeeming.
     */
    function canRedeem(address trader)
        internal
        view
        returns (bool)
    {
        if (_redeemingLockPeriod == 0) {
            return true;
        }
        return _lastPurchaseTime[trader].add(_redeemingLockPeriod) < LibUtils.currentTime();
    }

    /**
     * @notice  Redeem share balance, to prevent redeemed amount exceed total amount.
     * @dev     Slippage will overwrite previous setting.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to redeem.
     * @param   slippage    Slipage percent of redeeming price, fixed float in decimals 18.
     */
    function increaseRedeemingAmount(address trader, uint256 shareAmount, uint256 slippage)
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        require(shareAmount <= redeemableShareBalance(trader), "no enough share to redeem");
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader].add(shareAmount);
        _redeemingSlippage[trader] = slippage;

        emit IncreaseRedeemingShareBalance(trader, shareAmount);
    }

    /**
     * @notice  Redeem share balance, to prevent redeemed amount exceed total amount.
     * @param   trader       Address of share owner.
     * @param   shareAmount   Amount of share to redeem.
     */
    function decreaseRedeemingAmount(address trader, uint256 shareAmount)
        internal
    {
        require(shareAmount > 0, "share amount must be greater than 0");
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader]
            .sub(shareAmount, "insufficient redeeming share balance");

        emit DecreaseRedeemingShareBalance(trader, shareAmount);
    }
}