// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "../component/ERC20CappedRedeemable.sol";

contract TestERC20CappedRedeemable is ERC20CappedRedeemable {
    event DoNothing();

    constructor(string memory name, string memory symbol, uint256 cap) public {
        __ERC20_init_unchained(name, symbol);
        __ERC20CappedRedeemable_init_unchained(cap);
    }

    function redeemingLockPeriod() external view returns (uint256) {
        return _redeemingLockPeriod;
    }

    function redeemingSlippage(address account) external view returns (uint256) {
        return _redeemingSlippages[account];
    }

    function lastPurchaseTime(address account) external view returns (uint256) {
        return _lastPurchaseTimes[account];
    }

    function redeemingBalance(address account) external view returns (uint256) {
        return _redeemingBalances[account];
    }

    function cap() external view returns (uint256) {
        return _cap;
    }

    function setCap(uint256 newCap) external {
        _setCap(newCap);
    }

    function setRedeemingLockPeriod(uint256 period)
        external
    {
        _setRedeemingLockPeriod(period);
    }

    function setRedeemingSlippage(address trader, uint256 slippage)
        public
    {
        _setRedeemingSlippage(trader, slippage);
    }

    function redeemableShareBalance(address trader)
        external
        view
        returns (uint256)
    {
        return _redeemableShareBalance(trader);
    }

    function mint(address trader, uint256 shareAmount)
        external
    {
        _mint(trader, shareAmount);
    }

    function burn(address trader, uint256 shareAmount)
        external
    {
        _burn(trader, shareAmount);
    }

    function canRedeem(address trader)
        external
        view
        returns (bool)
    {
        return _canRedeem(trader);
    }

    function increaseRedeemingShareBalance(address trader, uint256 shareAmount)
        external
    {
        _increaseRedeemingShareBalance(trader, shareAmount);
    }

    function decreaseRedeemingShareBalance(address trader, uint256 shareAmount)
        external
    {
        _decreaseRedeemingShareBalance(trader, shareAmount);
    }

    function doNothing()
        external
    {
        emit DoNothing();
    }
}
