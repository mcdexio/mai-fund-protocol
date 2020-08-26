// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../lib/LibConstant.sol";
import "./Context.sol";

/**
 * @title Implemetation of operations on fund account.
 */
contract ERC20Redeemable is ERC20CappedUpgradeSafe, Context {

    using SafeMath for uint256;

    // using fixed decimals 18
    uint8 constant private FUND_SHARE_ERC20_DECIMALS = 18;

    uint256 internal _redeemingLockPeriod;

    mapping(address => uint256) internal _lastPurchaseTimes;
    mapping(address => uint256) internal _redeemingBalances;
    mapping(address => uint256) internal _redeemingSlippages;

    event Purchase(address indexed trader, uint256 shareAmount, uint256 lastPurchaseTime);
    event IncreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);
    event DecreaseRedeemingShareBalance(address indexed trader, uint256 shareAmount);
    event IncreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event DecreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event SetRedeemingSlippage(address indexed trader, uint256 slippage);

    function __ERC20Redeemable_init_unchained()
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
        if (!_canRedeem(trader)) {
            return 0;
        }
        return balanceOf(trader).sub(_redeemingBalances[trader]);
    }

    /**
     * @notice  Set redeeming lock period.
     * @param   period  Lock period in seconds.
     */
    function _setRedeemingLockPeriod(uint256 period) internal {
        _redeemingLockPeriod = period;
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
        require(slippage < LibConstant.RATE_UPPERBOUND, "slippage out of range");
        _redeemingSlippages[trader] = slippage;
        emit SetRedeemingSlippage(trader, slippage);
    }

    /**
     * @notice  Increase share balance, also increase the total supply.
     * @dev     Will update purchase time.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to mint.
     */
    function _mint(address trader, uint256 shareAmount)
        internal
        virtual
        override
    {
        super._mint(trader, shareAmount);
        _lastPurchaseTimes[trader] = _now();
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
     * @notice  Redeem share balance, to prevent redeemed amount exceed total amount.
     * @dev     Slippage will overwrite previous setting.
     * @param   trader      Address of share owner.
     * @param   shareAmount Amount of share to redeem.
     */
    function _increaseRedeemingShareBalance(address trader, uint256 shareAmount)
        internal
    {
        require(shareAmount <= _redeemableShareBalance(trader), "exceeded amount");
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
        _redeemingBalances[trader] = _redeemingBalances[trader].sub(shareAmount, "insufficient balance");
        emit DecreaseRedeemingShareBalance(trader, shareAmount);
    }

    /**
     * @dev Hook to check redeemable amount before transfer && update purchase time.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(from == address(0) || to == address(0) || amount <= _redeemableShareBalance(from), "insufficient balance");
        // this will affect receipient's _lastPurchaseTime.
        // to prevent early redeeming through transfer
        // but there is a side effect: if a account continously purchase && transfer shares to another account.
        // the target account may be blocked by such unexpeced manner.
        if (amount > 0 && _lastPurchaseTimes[from] > _lastPurchaseTimes[to]) {
            _lastPurchaseTimes[to] = _lastPurchaseTimes[from];
        }
    }

    uint256[16] private __gap;
}