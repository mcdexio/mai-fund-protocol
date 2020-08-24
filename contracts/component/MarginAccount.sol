// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

import "../interface/IPerpetual.sol";
import "./Context.sol";

interface IOwnable {
    function owner() external view returns (address);
}

/**
 * @title   MarginAccount 
 * @notice  Handle all interactions with underlaying perpetual.
 */
contract MarginAccount is Initializable, Context {

    IPerpetual internal _perpetual;

    function __MarginAccount_init_unchained(address perpetualAddress)
        internal
        initializer
    {
        require(perpetualAddress != address(0), "invalid perpetual address");
        _perpetual = IPerpetual(perpetualAddress);
    }

    function _owner()
        internal
        view
        virtual
        returns (address)
    {
        return IOwnable(_perpetual.globalConfig()).owner();
    }

    function _perpetualAddress()
        internal
        view
        virtual
        returns (address)
    {
        return address(_perpetual);
    }

    function _approveCollateral(uint256 rawCollateralAmount)
        internal
    {
        IERC20 collateral = IERC20(_perpetual.collateral());
        collateral.safeApprove(address(_perpetual), rawCollateralAmount);
    }

    function _deposit(uint256 rawCollateralAmount)
        internal
        payable
    {
        _perpetual.deposit{ value: msg.value }(rawCollateralAmount);
    }

    function _withdraw(uint256 rawCollateralAmount)
        internal
    {
        _perpetual.withdraw(rawCollateralAmount);
    }

    /**
     * @notice  Return margin account of fund.
     * @return  account   Margin account structure.
     */
    function _marginAccount()
        internal
        view
        virtual
        returns (LibTypes.MarginAccount memory account)
    {
        account = _perpetual.getMarginAccount(_self());
    }

    /**
     * @notice  Return total collateral amount, including unclaimed fee.
     * @dev     This is NOT a view function because [marginBalance]
     * @return  Value of total collateral in fund.
     */
    function _totalAssetValue()
        internal
        virtual
        returns (uint256)
    {
        int256 marginBalance = _perpetual.marginBalance(_self());
        require(marginBalance >= 0, "marginBalance must be possitive");
        return marginBalance.toUint256();
    }

    function _collateral()
        internal
        view
        virtual
        returns (address)
    {
        return _perpetual.collateral();
    }

    function _markPrice()
        internal
        virtual
        returns (uint256)
    {
        return _perpetual.markPrice();
    }

    /**
     * @notice bid share from redeeming or shutdown account.
     * @param   side            Side of taker wants to bid.
     * @param   price           Bidding price.
     * @param   positionAmount  Amount of position to bid.
     */
    function _tradePosition(
        LibTypes.Side side,
        uint256 price,
        uint256 positionAmount
    )
        internal
    {
        uint256 lotSize = _perpetual.getGovernance().lotSize;
        uint256 alignedAmount = positionAmount.sub(positionAmount.mod(lotSize));
        (
            uint256 takerOpened,
            uint256 makerOpened
        ) = _perpetual.tradePosition(
            _msgSender(),
            _self(),
            side,
            price,
            alignedAmount
        );
        if (makerOpened > 0) {
            require(_perpetual.isIMSafe(_msgSender()), "caller initial margin unsafe");
        } else {
            require(_perpetual.isSafe(_msgSender()), "caller margin unsafe");
        }
        if (takerOpened > 0) {
            require(_perpetual.isIMSafe(_self()), "fund initial margin unsafe");
        } else {
            require(_perpetual.isSafe(_self()), "fund margin unsafe");
        }
    }
}