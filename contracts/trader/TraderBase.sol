pragma solidity 0.6.10;

import "@openzeppelin/contracts/utils/Pausable.sol";

import "./TraderDetails.sol";
import "./Fund.sol";

import "../lib/LibOrderbook.sol";
import "../lib/LibFundStorage.sol";
import "../lib/LibFundCalculator.sol";


interface IPerpetual {
    function getMarginAccount(address trader) public view returns (LibTypes.MarginAccount memory);

    function tradePosition(
        address taker,
        address maker,
        LibTypes.Side side,
        uint256 price,
        uint256 amount
    ) external returns (uint256, uint256);
}

contract TraderBase is Pausable {
    using LibFundStorage for LibFundStorage.FundStorage;
    using LibFundCalculator for LibFundStorage.FundStorage;

    LibFundStorage.FundStorage internal _fundStorage;
    LibOrderbook.ShareOrderbook private _redeemingOrders;
    IFundAdministration private _fundAdministration;

    event Create(address indexed trader, uint256 initialUnitNetValue, uint256 shareAmount);
    event Purchase(address indexed trader, uint256 netAssetValue, uint256 shareAmount);
    event RequestToRedeem(address indexed trader, uint256 shareAmount, uint256 slippage);
    event Redeem(address indexed trader, uint256 netAssetValue, uint256 shareAmount);

    constructor(string memory name, address perpetual, uint256 initialConfiguration)
        public
        TraderDetails(name, perpetual)
    {
        _fundStorage.initialize(name, perpetual, netValueUnit, initialConfiguration);
    }

    modifier onlyManager() {
        require(msg.sender == _fundStorage.manager.account, "caller must be the manager");
        _;
    }

    modifier onlyAdministrator() {
        require(msg.sender == _fundAdministration.administrator(), "caller must be the administrator");
        _;
    }

    /**
        for fund user:
            - purchase              (user)
            - redeem                (user)
            - withdraw              (user)
            - take                  (market maker)
            - shutdown              (anyone)
     */


    /**
     * @dev Call once, when net value is 0 (position size == 0).
     *
     * @param amount Amount of units (calculated as unit net value) to join, 10**18
     */
    function create(uint256 shareAmount, uint256 initialUnitNetValue) external override payable onlyManager whenNotPaused {
        // steps:
        //  1. get collateral required
        //  2. pull collateral
        //  3.
        require(amount > 0, "amount should not be 0");
        require(_fundStorage.totalShareSupply() == 0, "share supply must be 0");
        address trader = msg.sender;
        _fundStorage.purchase(trader, initialUnitNetValue, shareAmount);

        emit Create(msg.sender, initialUnitNetValue, shareAmount);
    }


    /**
     * @dev Total collataral required = amount x unit net value.
     *
     * @param amount Amount of units (calculated as unit net value) to join, 10**18
     */
    function purchase(uint256 shareAmount, uint256 netValueLimit) external override payable whenNotPaused {
        // steps:
        //   1. calculate net value of fund
        //      - unit net value
        //      - entrance fee
        //   2. pull collateral
        //   3. update trader's fund acccount
        //   4. deposit to fund's margin account

        // 1. get current net asset value, this will be the price per share.
        uint256 netAssetValue = _fundStorage.getNetAssetValue();
        require(unitNetValue <= netValueLimit, "unit net value exceeded limit");
        address trader = msg.sender;
        _fundStorage.purchase(trader, netAssetValue, shareAmount);

        emit Purchase(trader, netAssetValue, shareAmount);
    }

    function requestToRedeem(uint256 shareAmount, uint256 slippage) external override whenNotPaused {
        // steps:
        //   1. calculate price limit due to current mark price and slippagePercent
        //      - net value
        //      - high water mark -- performance fee
        //   2. push order to list
        require(shareAmount > 0, "amount must be greater than 0");
        require(slippage < ONE.mul(100), "slippage must be less then 100%");
        address trader = msg.sender;
        _fundStorage.requestToRedeem(trader, shareAmount);
        uint256 availableAt = LibFundUtils.currentTime()
            .add(_fundStorage.configuration.redeemingDelay);
        RedeemOrder memory newOrder = RedeemOrder({
            id: _redeemingOrders.getNextId(),
            trader: trader,
            shareAmount: shareAmount,
            slippage: slippage,
            availableAt: availableAt
        });
        _redeemingOrders.add(newOrder);
        emit RequestToRedeem(trader, shareAmount, slippage);
    }

    function cancel(uint256 id) external override whenNotPaused {
        require(_redeemingOrders.has(id), "order id not exist");
        RedeemOrder memory order = _redeemingOrders.getOrder(id);
    }

    function takeRedeemOrder(uint256 id) external override whenNotPaused {
        require(_redeemingOrders.has(id), "order id not exist");

        RedeemOrder memory order = _redeemingOrders.getOrder(id);
        require(order.availableAt < LibFundUtils.currentTime(), "order not available now");

        LibTypes.MarginAccount memory fundMarginAccount = perpetual.getMarginAccount(this.address);
        uint256 markPrice = _fundStorage.perpetual.markPrice();
        if (fundMarginAccount.side == Side.LONG) {
            markPrice = markPrice.wmul(ONE.add(order.slippage));
        } else {
            markPrice = markPrice.wmul(ONE.sub(order.slippage));
        }
        uint256 rate = order.shareAmount.wdiv(_fundStorage.totalShareSupply);
        // TODO: align to tradingLotSize
        uint256 positionAmount = fundMarginAccount.size.wmul(rate);
        perpetual.trade(
            this.address,
            msg.sender,
            fundMarginAccount.side.counterSide(),
            entryPrice,
            positionAmount
        );
        _fundStorage.redeem(order.owner, order.shareAmount);
    }

    /**
     * @dev Shutdown contract on drawdown.
     */
    function shutdownOnMaxDrawdownReached() external override {
        uint256 netAssetValue = _fundStorage.getNetAssetValue();
        uint256 maxNetAssetValue = _fundStorage.manager.maxNetAssetValue;
        require(maxNetAssetValue > netAssetValue, "no drawdown");
        require(
            maxNetAssetValue.sub(netAssetValue).wdiv(maxNetAssetValue) > _fundStorage.configuration.maxDrawdown,
            "max drawdown not reached"
        );
        _shutdown();
    }

    function shutdown() external override onlyAdministrator {
        _shutdown();
    }

    function _shutdown() internal {

    }

    function pause() external override onlyAdministrator {
        _pause();
    }

    function unpause() external override onlyAdministrator {
        _unpause();
    }
}