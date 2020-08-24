// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "./ERC20Purchasable.sol";

/**
 * @title Implemetation of operations on fund account.
 */
contract ERC20Tradable is ERC20Purchasable {
    
    using SafeMath for uint256;

    // using fixed decimals 18
    uint8 constant private FUND_SHARE_ERC20_DECIMALS = 18;

    uint256 private _redeemingLockPeriod;

    mapping(address => uint256) private _lastPurchaseTimes;
    mapping(address => uint256) private _redeemingBalances;
    mapping(address => uint256) private _redeemingSlippages;
    mapping(address => uint256) private _withdrawableCollaterals;

    event Purchase(address indexed trader, uint256 shareAmount, uint256 lastPurchaseTime);
    event IncreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);
    event DecreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);
    event IncreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event DecreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event SetRedeemingSlippage(address indexed trader, uint256 slippage);

    function __ERC20Tradable_init_unchained(uint256 cap)
        internal
        initializer
    {
        _setupDecimals(FUND_SHARE_ERC20_DECIMALS);
    }

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
        return balanceOf(trader).sub(_redeemingBalances[trader]);
    }

    /**
     * @notice  Increase share balance, also increase the total supply.
     * @dev     Will update purchase time.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to mint.
     */
    function _purchase(address trader, uint256 shareAmount)
        internal
        virtual
    {
        _mint(trader, shareAmount);
        _lastPurchaseTimes[trader] = _now();
        emit Purchase(trader, shareAmount, _now());
    }

    /**
     * @notice  Decrease share balance,  also decrease the total supply.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to burn.
     */
    function _redeem(address trader, uint256 shareAmount)
        internal
    {
        _burn(trader, shareAmount);
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

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(amount <= _redeemableShareBalance(from), "insufficent balance to transfer");
        // this will affect receipient's _lastPurchaseTime.
        // to prevent early redeeming through transfer
        // but there is a side effect: if a account continously purchase && transfer shares to another account.
        // the target account may be blocked by such unexpeced manner.
        if (amount > 0 && _lastPurchaseTimes[from] > _lastPurchaseTimes[to]) {
            _lastPurchaseTimes[to] = _lastPurchaseTimes[from];
        }
    }
}