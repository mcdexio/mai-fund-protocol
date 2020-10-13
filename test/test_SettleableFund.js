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

const TestSettleableFund = artifacts.require('TestSettleableFund.sol');

contract('TestSettleableFund', accounts => {

    const SHORT = 1;
    const LONG = 2;

    const NORMAL = 0;
    const EMERGENCY = 1;
    const SHUTDOWN = 2;

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

        fund = await TestSettleableFund.new();
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

    it("settle - 1", async () => {
        // await fund.setRedeemingSlippage(fund.address, toWad(0.0));
        assert.equal(await fund.state(), NORMAL);
        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(200), toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        var totalSupply = await fund.totalSupply();


        await fund.setEmergency();
        assert.equal(await fund.state(), EMERGENCY);

        // forbidden
        await shouldThrows(fund.purchase(toWad(200), toWad(1), toWad(0.01)), "bad state");
        await shouldThrows(fund.redeem(toWad(1), toWad(0)), "bad state");
        await shouldThrows(fund.bidRedeemingShare(user1, toWad(1), toWad(1), 1), "bad state");

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

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(200), toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.purchase(toWad(400), toWad(2), toWad(200), { from: user2, value: toWad(400) });
        assert.equal(fromWad(await fund.balanceOf(user2)), 2);

        assert.equal(fromWad(await fund.totalSupply()), 4);

        // 4 * 200 = 800
        // 400 / 0.005 = 80000
        await delegateTrade(admin, user3, 'sell', toWad(200), toWad(80000));

        var margin = await deployer.perpetual.getMarginAccount(fund.address);
        // console.log(margin);
        assert.equal(margin.side, LONG);
        assert.equal(fromWad(margin.size), 80000);

        await shouldThrows(fund.bidSettledShare(toWad(4), toWad(0.01), LONG, { from: user3 }), "bad state");

        // 0.01 = 0.005 x2
        await deployer.setIndex(100);
        // pnl = 0.01 - 0.005 * 80000 = +400
        assert.equal(fromWad(await deployer.perpetual.pnl.call(fund.address)), 400);

        await fund.setEmergency();
        await shouldThrows(fund.setEmergency(), "bad state");
        assert.equal(await fund.state(), EMERGENCY);

        await fund.bidSettledShare(toWad(4), toWad(0.01), LONG, { from: user3 });

        assert.equal(fromWad(await web3.eth.getBalance(fund.address)), 0);
        assert.equal(fromWad(await deployer.perpetual.marginBalance.call(fund.address)), 1200);

        console.log(fromWad(await fund.balanceOf(admin)));
        console.log(fromWad(await fund.netAssetValue.call()));

        await fund.setShutdown();
        assert.equal(await fund.state(), SHUTDOWN);

        await fund.settle(toWad(1), { from: admin });
        await fund.settle(toWad(1), { from: user1 });
        await fund.settle(toWad(2), { from: user2 });

        assert.equal(fromWad(await web3.eth.getBalance(fund.address)), 0);
        await shouldThrows(fund.settle(toWad(1), { from: admin }), "amount excceeded");
    });

    it("settle - 3", async () => {
        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(10000), {from: user3, value: toWad(10000)});

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(200), toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.purchase(toWad(400), toWad(2), toWad(200), { from: user2, value: toWad(400) });
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

        await deployer.perpetual.beginGlobalSettlement(toWad(0.01));

        await fund.setEmergency();
        // price
        // console.log(fromWad(await deployer.perpetual.markPrice.call()));
        await shouldThrows(fund.bidSettledShare(toWad(4), toWad(0.01), LONG, { from: user3 }), "perpetual emergency");
        await shouldThrows(fund.settleMarginAccount(), "wrong perpetual status");

        await deployer.perpetual.endGlobalSettlement();
        await fund.settleMarginAccount();

        await shouldThrows(fund.settle(toWad(1), { from: admin }), "bad state");

        await fund.setShutdown();

        await fund.settle(toWad(1), { from: admin });
        await fund.settle(toWad(1), { from: user1 });
        await fund.settle(toWad(2), { from: user2 });

        assert.equal(fromWad(await fund.netAssetValue.call()), 0);
        assert.equal(fromWad(await fund.totalSupply()), 0);
        assert.equal(fromWad(await web3.eth.getBalance(fund.address)), 0);
        await shouldThrows(fund.settle(toWad(1), { from: admin }), "amount excceeded");
    });

    it("settle - 4", async () => {
        await fund.setDelegator(deployer.exchange.address, admin);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(10000), {from: user3, value: toWad(10000)});

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(200), toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.purchase(toWad(400), toWad(2), toWad(200), { from: user2, value: toWad(400) });
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

        await fund.redeem(toWad(1), toWad(0.01), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0.01), LONG);

        await deployer.perpetual.beginGlobalSettlement(toWad(0.01));

        await fund.setEmergency();
        // price
        // console.log(fromWad(await deployer.perpetual.markPrice.call()));
        await shouldThrows(fund.bidSettledShare(toWad(4), toWad(0.01), LONG, { from: user3 }), "amount excceeded");
        await shouldThrows(fund.bidSettledShare(toWad(3), toWad(0.01), LONG, { from: user3 }), "perpetual emergency");
        await shouldThrows(fund.settleMarginAccount(), "wrong perpetual status");

        await deployer.perpetual.endGlobalSettlement();
        await fund.settleMarginAccount();
        await fund.setShutdown();

        await fund.settle(toWad(1), { from: admin });
        await shouldThrows(fund.settle(toWad(1), { from: user1 }), "amount excceeded");
        await fund.settle(toWad(2), { from: user2 });

        assert.equal(fromWad(await fund.netAssetValue.call()), 0);
        assert.equal(fromWad(await fund.totalSupply()), 0);
        assert.equal(fromWad(await web3.eth.getBalance(fund.address)), 0);
        await shouldThrows(fund.settle(toWad(1), { from: admin }), "amount excceeded");
    });
});