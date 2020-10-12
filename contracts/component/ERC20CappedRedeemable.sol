// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

import "../lib/LibConstant.sol";
import "./Context.sol";

/**
 * @title Implemetation of operations on fund account.
 */
contract ERC20CappedRedeemable is Initializable, ERC20UpgradeSafe, Context {

    using SafeMath for uint256;

    // using fixed decimals 18
    uint8 constant private FUND_SHARE_ERC20_DECIMALS = 18;

    uint256 internal _cap;
    uint256 internal _redeemingLockPeriod;

    mapping(address => uint256) internal _lastPurchaseTimes;
    mapping(address => uint256) internal _redeemingBalances;
    mapping(address => uint256) internal _redeemingSlippages;

    event IncreaseRedeemingShareBalance(address indexed trader, uint256 amount);
    event DecreaseRedeemingShareBalance(address indexed trader, uint256 amount);
    event IncreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event DecreaseWithdrawableCollateral(address indexed trader, uint256 amount);
    event SetRedeemingSlippage(address indexed trader, uint256 slippage);

    function __ERC20CappedRedeemable_init_unchained(uint256 cap)
        internal
        initializer
    {
        require(cap > 0, "cap is 0");
        _cap = cap;
        _setupDecimals(FUND_SHARE_ERC20_DECIMALS);
    }

    /**
     * @dev     Set a new cap.
     */
    function _setCap(uint256 newCap)
        internal
    {
        require(newCap != _cap, "same cap");
        _cap = newCap;
    }

    /**
     * @dev     Before actually sold (redeemed), the share will still belong to redeeming account.
     * @param   trader  Address of share owner.
     * @return  Amount of redeemable share balance.
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
     * @dev     Set redeeming lock period.
     * @param   period  Lock period in seconds.
     */
    function _setRedeemingLockPeriod(uint256 period) internal {
        _redeemingLockPeriod = period;
    }

    /**
     * @dev     Set redeeming slippage, a fixed float in decimals 18, 0.01 ether == 1%.
     * @param   trader      Address of share owner.
     * @param   slippage    Slippage percent of redeeming rate.
     */
    function _setRedeemingSlippage(address trader, uint256 slippage)
        internal
    {
        if (slippage == _redeemingSlippages[trader]) {
            return;
        }
        require(slippage < LibConstant.RATE_UPPERBOUND, "slippage too large");
        _redeemingSlippages[trader] = slippage;
        emit SetRedeemingSlippage(trader, slippage);
    }

    /**
     * @dev     Increase share balance, also increase the total supply. update purchase time.
     * @param   trader      Address of share owner.
     * @param   amount      Amount of share to mint.
     */
    function _mint(address trader, uint256 amount)
        internal
        virtual
        override
    {
        super._mint(trader, amount);
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
     * @dev     Redeem share balance, to prevent redeemed amount exceed total amount.
     *          Slippage will overwrite previous setting.
     * @param   trader  Address of share owner.
     * @param   amount  Amount of share to redeem.
     */
    function _increaseRedeemingShareBalance(address trader, uint256 amount)
        internal
    {
        require(amount <= _redeemableShareBalance(trader), "amount exceeded");
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader].add(amount);
        emit IncreaseRedeemingShareBalance(trader, amount);
    }

    /**
     * @dev     Redeem share balance, to prevent redeemed amount exceed total amount.
     * @param   trader       Address of share owner.
     * @param   amount   Amount of share to redeem.
     */
    function _decreaseRedeemingShareBalance(address trader, uint256 amount)
        internal
    {
        // set max amount of redeeming amount
        _redeemingBalances[trader] = _redeemingBalances[trader].sub(amount, "amount exceeded");
        emit DecreaseRedeemingShareBalance(trader, amount);
    }

    /**
     * @dev Hook to check redeemable amount before transfer and update purchase time.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) { // When minting tokens
            require(totalSupply().add(amount) <= _cap, "cap exceeded");
        }

        require(from == address(0) || to == address(0) || amount <= _redeemableShareBalance(from), "amount exceeded");
        // this will affect recipient's _lastPurchaseTime.
        // to prevent early redeeming through transfer
        // but there is a side effect: if an account continuously purchases and transfers shares to another account.
        // the target account may be blocked by such unexpected manner.
        if (amount > 0 && _lastPurchaseTimes[from] > _lastPurchaseTimes[to]) {
            _lastPurchaseTimes[to] = _lastPurchaseTimes[from];
        }
    }

    uint256[15] private __gap;
}