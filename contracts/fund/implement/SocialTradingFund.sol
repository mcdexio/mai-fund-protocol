// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../SettleableFund.sol";
import "../Getter.sol";

interface IDelegatable {
    function setDelegator(address perpetual, address newDelegator) external;
    function isDelegator(address trader, address perpetual, address target) external view returns (bool);
}

/**
 * @title   Social trading fund, managed by a social trader.
 *          A social trader is able trade for fund but cannot withdraw from fund.
 */
contract SocialTradingFund is
    Initializable,
    SettleableFund,
    Getter
{
    using SafeMath for uint256;

    address internal _manager;

    event SetManager(address indexed oldManager, address indexed newManager);
    event WithdrawManagementFee(address indexed maintainer, uint256 totalFee);

    function initialize(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 collateralDecimals,
        address perpetualAddress,
        uint256 tokenCap
    )
        external
        initializer
    {
        __SettleableFund_init(tokenName, tokenSymbol, collateralDecimals, perpetualAddress, tokenCap);
        __SocialTradingFund_init_unchained();
    }

    function __SocialTradingFund_init_unchained()
        internal
        initializer
    {
    }

    /**
     * @dev Manager of fund.
     */
    function manager()
        public
        view
        returns (address)
    {
        return _manager;
    }

    /**
     * @dev Calculate incentive fee (streaming fee + performance fee)
     * @return totalFee IncentiveFee gain since last claiming.
     */
    function managementFee()
        public
        returns (uint256)
    {
        _updateNetAssetValue();
        return _totalFeeClaimed;
    }

    /**
     * @notice  Set fund manager and delegator to an account.
     * @param   newManager      Address of manager.
     * @param   exchangeAddress Address of exchange.
     */
    function setManager(address newManager, address exchangeAddress)
        public
        onlyOwner
        nonReentrant
    {
        if (_manager != newManager) {
            _withdrawManagementFee(managementFee());
            emit SetManager(_manager, newManager);
            _manager = newManager;
        }
        IDelegatable delegatable = IDelegatable(exchangeAddress);
        if (!delegatable.isDelegator(newManager, address(_perpetual), _self())) {
            delegatable.setDelegator(address(_perpetual), newManager);
        }
    }

    /**
     * @notice  In extreme case, there will not be enough collateral (may be liquidated) to withdraw.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function withdrawManagementFee(uint256 collateralAmount)
        public
        nonReentrant
        whenNotPaused
        whenNotInState(FundState.EMERGENCY)
    {
        _withdrawManagementFee(collateralAmount);
    }

    /**
     * @notice  Usually manager needn't manually call update interface, except willing to claim
     *          performance fee based on current nav per share.
     *          But the side effect is that next performance fee claiming will become harder --
     *          the maxNetValueAssetPerShare is increased.
     */
    function updateManagementFee()
        public
        whenNotPaused
        whenInState(FundState.NORMAL)
    {
        _updateNetAssetValue();
    }

    /**
     * @dev     In extreme case, there will not be enough collateral (may be liquidated) to withdraw.
     * @param   collateralAmount    Amount of collateral to withdraw.
     */
    function _withdrawManagementFee(uint256 collateralAmount)
        internal
    {
        _updateNetAssetValue();
        if (_totalFeeClaimed == 0 || collateralAmount == 0 || _manager == address(0)) {
            return;
        }
        _totalFeeClaimed = _totalFeeClaimed.sub(collateralAmount, "insufficient fee");
        uint256 rawCollateralAmount = _toRawAmount(collateralAmount);
        if (_state == FundState.NORMAL) {
            _withdraw(rawCollateralAmount);
        }
        _pushToUser(payable(_manager), rawCollateralAmount);
        emit WithdrawManagementFee(_manager, collateralAmount);
    }

    uint256[19] private __gap;
}