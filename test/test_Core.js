const assert = require("assert");
const BN = require('bn.js');
const BigNumber = require('bignumber.js');
const { encodeInitializData, setParameter, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot, sleep, approximatelyEqual,
    checkEtherBalance
} = require("./utils.js");

const TestCore = artifacts.require('TestCore.sol');

contract('FundBase', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var deployer;
    var fund;
    var debug = false;

    const deploy = async () => {
        admin = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        deployer = await new PerpetualDeployer(accounts, true);
        await deployer.deploy();
        await deployer.initialize();
        await deployer.setIndex(200);
        await deployer.createPool();

        fund = await TestCore.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            18,
            deployer.perpetual.address,
            toWad(1000),
        )
        await deployer.globalConfig.addComponent(deployer.perpetual.address, fund.address);
    }

    before(deploy);

    var snapshotId;
    beforeEach(async () => {
        snapshotId = await createEVMSnapshot();
    });

    afterEach(async function () {
        await restoreEVMSnapshot(snapshotId);
    });

    const printFundState = async (deployer, fund, user) => {
        if (!debug) {
            return;
        }
        const marginAccount = await deployer.perpetual.getMarginAccount(fund.address);
        console.log("  ┌───────────────────────────────┬─────────────────");
        console.log("  │ Oracle                        │                 ");
        console.log("  │    Price                      │ $", (await deployer.priceFeeder.latestAnswer()).div(new BN(1e8)).toString());
        console.log("  │    Price (inversed)           │ $", (new BN(1e8)).div(await deployer.priceFeeder.latestAnswer()).toString());
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fund                          │                 ");
        console.log("  │    Leverage                   │  ", fromWad(await fund.leverage.call()));
        // console.log("  │    NeedRebalance              │  ", await fund.needRebalancing.call());
        console.log("  │    TotalSupply                │  ", fromWad(await fund.totalSupply()));
        console.log("  │    NetAssetValuePerShare      │ Ξ", fromWad(await fund.netAssetValue.call()));
        console.log("  │    PositionSize               │  ", fromWad(marginAccount.size));
        console.log("  │    PositionSide               │  ", marginAccount.side == SHORT? "SHORT": marginAccount.side == LONG? "LONG": "FLAT");
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fee                           │                 ");
        console.log("  │    FeeClaimed                 │  ", fromWad(await fund.totalFeeClaimed()));
        console.log("  │    LastFeeTime                │  ", (await fund.lastFeeTime()).toString());
        console.log("  └───────────────────────────────┴─────────────────");
        console.log("");
    };

    it("base info", async () => {
        assert.equal(await fund.name(), "Fund Share Token");
        assert.equal(await fund.symbol(), "FST");
        assert.equal(await fund.decimals(), 18);
        assert.equal(await fund.cap(), toWad(1000));
    });

    it("initialize", async () => {

        var fund = await TestCore.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            18,
            deployer.perpetual.address,
            toWad(1000),
        )
        await shouldThrows(
            fund.initialize(
                "Fund Share Token",
                "FST",
                18,
                deployer.perpetual.address,
                toWad(1000),
            ),
            "Contract instance has already been initialized"
        );

        var fund = await TestCore.new();
        await shouldThrows(
            fund.initialize(
                "Fund Share Token",
                "FST",
                18,
                "0x0000000000000000000000000000000000000000",
                toWad(1000),
            ),
            "zero perpetual address"
        );

        var fund = await TestCore.new();
        await shouldThrows(
            fund.initialize(
                "Fund Share Token",
                "FST",
                18,
                deployer.perpetual.address,
                toWad(0),
            ),
            "cap is 0"
        );
    });

    it("create", async () => {
        var fund = await TestCore.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            18,
            deployer.perpetual.address,
            toWad(1000),
        )
        await deployer.globalConfig.addComponent(deployer.perpetual.address, fund.address);
        await shouldThrows(fund.create(toWad(0), toWad(200), { value: toWad(200) }), "amount is 0");

        assert.ok((await fund.lastFeeTime()).toString() == 0);
        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.ok((await fund.lastFeeTime()).toString() != 0);
        assert.equal(fromWad(await fund.totalSupply()), 1);
        assert.equal(fromWad(await fund.netAssetValue.call()), 200);

        await shouldThrows(fund.create(toWad(1), toWad(200), { value: toWad(200) }), "alread created");
    });

    it("purchase", async () => {
        await shouldThrows(fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) }), "nav is 0");

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await shouldThrows(fund.purchase(toWad(1), toWad(199), { from: user1, value: toWad(199) }), "exceeded nav");
        await shouldThrows(fund.purchase(toWad(0), toWad(200), { from: user1, value: toWad(200) }), "amount is 0");
    });

    it("redeem - no position", async () => {
        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await shouldThrows(fund.redeem(toWad(0), toWad(0)), "amount is 0");
        await shouldThrows(fund.redeem(toWad(1), toWad(1)), "slippage out of range");

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setParameter(toBytes32("redeemingLockPeriod"), 6);
        await shouldThrows(fund.redeem(toWad(1), toWad(0.01)), "cannot redeem now");

        await sleep(6000);

        await checkEtherBalance(fund.redeem(toWad(1), toWad(0.2)), admin, toWad(-200));
        assert.equal(fromWad(await fund.redeemingSlippage(admin)), 0.2);
    });

    it("redeem - has position", async () => {
        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        assert.equal(fromWad(await fund.withdrawableCollateral(user1)), 0);
        await fund.redeem(toWad(1), toWad(0.01), { from: user1 });
        assert.equal(fromWad(await fund.withdrawableCollateral(user1)), 0);
        assert.equal(fromWad(await fund.redeemingBalance(user1)), 1);
        assert.equal(fromWad(await fund.redeemingSlippage(user1)), 0.01);
    });

    it("cancelRedeem", async () => {
        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        assert.equal(fromWad(await fund.withdrawableCollateral(user1)), 0);
        await fund.redeem(toWad(1), toWad(0.01), { from: user1 });
        assert.equal(fromWad(await fund.withdrawableCollateral(user1)), 0);
        assert.equal(fromWad(await fund.redeemingBalance(user1)), 1);
        assert.equal(fromWad(await fund.redeemingSlippage(user1)), 0.01);

        await fund.cancelRedeem(toWad(0.5), { from: user1 });
        assert.equal(fromWad(await fund.redeemingBalance(user1)), 0.5);
        assert.equal(fromWad(await fund.redeemingSlippage(user1)), 0.01);

        await shouldThrows(fund.cancelRedeem(toWad(0.51), { from: user1 }), "insufficient balance");
        await shouldThrows(fund.cancelRedeem(toWad(0), { from: user1 }), "amount is 0");

        await fund.cancelRedeem(toWad(0.5), { from: user1 });
        assert.equal(fromWad(await fund.redeemingBalance(user1)), 0);
        assert.equal(fromWad(await fund.redeemingSlippage(user1)), 0.01);

        await shouldThrows(fund.cancelRedeem(toWad(0), { from: user1 }), "amount is 0");
        await shouldThrows(fund.cancelRedeem(toWad(1), { from: user1 }), "insufficient balance");
    });

    it("withdrawCollateral", async () => {
        debug = true;

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await shouldThrows(fund.redeem(toWad(0), toWad(0)), "amount is 0");
        await shouldThrows(fund.redeem(toWad(1), toWad(1)), "slippage out of range");

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setParameter(toBytes32("redeemingLockPeriod"), 6);
        await shouldThrows(fund.redeem(toWad(1), toWad(0.01)), "cannot redeem now");

        await sleep(6000);

        await checkEtherBalance(fund.redeem(toWad(0.5), toWad(0.2)), admin, toWad(-100));
        assert.equal(fromWad(await fund.withdrawableCollateral(admin)), 0);
        assert.equal(fromWad(await fund.redeemingSlippage(admin)), 0.2);

        await shouldThrows(fund.redeem(toWad(0.6), toWad(0.2)), "excceeded amount");

        await checkEtherBalance(fund.redeem(toWad(0.5), toWad(0.2)), admin, toWad(-100));
        assert.equal(fromWad(await fund.redeemingSlippage(admin)), 0.2);
        assert.equal(fromWad(await fund.balanceOf(admin)), 0);
    });

    it("user purchase - redeem", async () => {

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);

        await printFundState(deployer, fund, user1);

        await fund.redeem(toWad(1), toWad(0), { from: user1 });

        console.log(await deployer.perpetual.getMarginAccount(user2));
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), SHORT, { from: user2 });

        await printFundState(deployer, fund, user1);
    });

    it("user purchase - redeem (with entrance fee)", async () => {
        debug = false;
        await fund.setParameter(toBytes32("entranceFeeRate"), toWad(0.10));

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);
        await printFundState(deployer, fund, user1);

        console.log("DEBUG", fromWad(await fund.netAssetValue.call()));
        await fund.purchase(toWad(1), toWad(220), { from: user1, value: toWad(220) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);
        await printFundState(deployer, fund, user1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user1);

        await fund.redeem(toWad(1), toWad(0), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(deployer, fund, user1);
    });

    it("user purchase - redeem (with streaming fee)", async () => {
        await fund.setParameter(toBytes32("streamingFeeRate"), toWad(0.31536)); // 0.000864 / day -> 0.00000001 / second

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);
        await printFundState(deployer, fund, user1);
        const lastFeeTimeA = Number((await fund.lastFeeTime()).toString());

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        const lastFeeTimeB = Number((await fund.lastFeeTime()).toString());
        assert.equal(fromWad(await fund.totalFeeClaimed()),  (lastFeeTimeB-lastFeeTimeA) * 0.00000001 * 200);

        // assert.equal(fromWad(await fund.balanceOf(user1)), 1);
        await printFundState(deployer, fund, user1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user1);

        await fund.redeem(toWad(1), toWad(0), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(deployer, fund, user1);

        // 0.000006341989 =
        // 0.000005073598 +
        // 0.000001268391
    });

    it("user purchase - redeem (with performace fee)", async () => {
        debug = true;
        await fund.setParameter(toBytes32("streamingFeeRate"), toWad(0.00));

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);
        await printFundState(deployer, fund, user1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);
        await printFundState(deployer, fund, user1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user1);

        await fund.redeem(toWad(1), toWad(0), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(deployer, fund, user1);

        // 0.000006341989 =
        // 0.000005073598 +
        // 0.000001268391
    });

    it("settle", async () => {
        // await fund.setRedeemingSlippage(fund.address, toWad(0.0));

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        var totalSupply = await fund.totalSupply();
        var totalSupply = await fund.totalSupply();

        await fund.shutdown();

        assert.ok(await fund.stopped());

        // forbidden
        await shouldThrows(fund.create(toWad(1), toWad(1)), "Stoppable: stopped");
        await shouldThrows(fund.purchase(toWad(1), toWad(0.01)), "Stoppable: stopped");
        await shouldThrows(fund.bidRedeemingShare(user1, toWad(1), toWad(1), 1), "Stoppable: stopped");

        assert.equal(fromWad(await fund.redeemingBalance(fund.address)), fromWad(totalSupply));
        await fund.bidSettledShare(toWad(2), toWad(0), SHORT);
        assert.equal(fromWad(await fund.redeemingBalance(fund.address)), 0);
        assert.equal(fromWad(await fund.totalSupply()), 2);
    });

    it("settle - 2", async () => {
        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(10000), {from: user3, value: toWad(10000)});

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.purchase(toWad(2), toWad(200), { from: user2, value: toWad(400) });
        assert.equal(fromWad(await fund.balanceOf(user2)), 2);

        assert.equal(fromWad(await fund.totalSupply()), 4);

        // 4 * 200 = 800
        // 400 / 0.005 = 80000
        await delegateTrade(admin, user3, 'sell', toWad(200), toWad(80000));

        var margin = await deployer.perpetual.getMarginAccount(fund.address);
        // console.log(margin);
        assert.equal(margin.side, LONG);
        assert.equal(fromWad(margin.size), 80000);

        // 0.01 = 0.005 x2
        await deployer.setIndex(100);
        // pnl = 0.01 - 0.005 * 80000 = +400
        assert.equal(fromWad(await deployer.perpetual.pnl.call(fund.address)), 400);

        await fund.shutdown();
        assert.ok(await fund.stopped());

        await shouldThrows(fund.redeem(toWad(1), toWad(0.001), { from: user1 }), "Stoppable: stopped");
        await shouldThrows(fund.settle(toWad(1), { from: user1 }), "cannot redeem now");

        await fund.bidSettledShare(toWad(4), toWad(0.01), LONG, { from: user3 });


        assert.equal(fromWad(await web3.eth.getBalance(fund.address)), 0);
        assert.equal(fromWad(await deployer.perpetual.marginBalance.call(fund.address)), 1200);
        // console.log(fromWad(await fund.balanceOf(admin)));
        await fund.settle(toWad(1), { from: admin });
        await fund.settle(toWad(1), { from: user1 });
        await fund.settle(toWad(2), { from: user2 });
        assert.equal(fromWad(await web3.eth.getBalance(fund.address)), 0);

        await shouldThrows(fund.settle(toWad(1), { from: admin }), "excceeded amount");
    });
});