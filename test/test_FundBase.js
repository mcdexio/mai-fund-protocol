const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { getPerpetualComponents } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const MockPerpetual = artifacts.require('MockPerpetual.sol');
const TestFund = artifacts.require('TestFund.sol');

contract('FundBase', accounts => {
    var user1;
    var user2;
    var user3;
    var admin;

    var perpetual;
    var amm;
    var global;
    var feeder;
    var exchange;
    var testFund;
    var debug = false;

    const deploy = async () => {
        admin = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        const addresses = await getPerpetualComponents(
            "0x9f8b7f276F466c2eEB59B873Fd255Ab028D6a7fA",
            "0x49105758803D4BfDCd5673b15D77F6614DC26da7"
        );

        perpetual = addresses.perpetual;
        amm = addresses.amm;
        global = addresses.global;
        feeder = addresses.feeder;
        exchange = addresses.exchange;

        await feeder.setPrice("20000000000");
        await amm.updateIndex();
        if (!(await global.brokers(admin))) {
            await global.addBroker(admin);
        }

        testFund = await TestFund.new();
        await testFund.initialize(
            "Fund Share Token",
            "FST",
            "0x0000000000000000000000000000000000000000",
            18,
            perpetual.address,
            admin
        )
        await global.addComponent(perpetual.address, testFund.address);
    }

    before(deploy);

    var snapshotId;
    beforeEach(async () => {
        snapshotId = await createEVMSnapshot();
    });

    afterEach(async function () {
        await restoreEVMSnapshot(snapshotId);
    });

    const printFundState = async (feeder, fund, perpetual, user) => {
        if (!debug) {
            return;
        }
        const marginAccount = await perpetual.getMarginAccount(fund.address);
        console.log("  ┌───────────────────────────────┬─────────────────");
        console.log("  │ Oracle                        │                 ");
        console.log("  │    price                      │ $", (await feeder.latestAnswer()).div(new BN(1e8)).toString());
        console.log("  │    price (inversed)           │ $", (new BN(1e8)).div(await feeder.latestAnswer()).toString());
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fund                          │                 ");
        console.log("  │    TotalSupply                │  ", fromWad(await fund.totalSupply()));
        console.log("  │    NetAssetValue              │ Ξ", fromWad(await fund.getNetAssetValue.call()));
        console.log("  │    NetAssetValuePerShare      │ Ξ", fromWad(await fund.getNetAssetValuePerShare.call()));
        console.log("  │    PositionSize               │  ", fromWad(marginAccount.size));
        console.log("  │    PositionSide               │  ", marginAccount.side == 1? "SHORT": marginAccount.side == 2? "LONG": "FLAT");
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fee                           │                 ");
        console.log("  │    Manager                    │  ", await fund.manager());
        console.log("  │    FeeClaimed                 │  ", fromWad(await fund.totalFeeClaimed()));
        console.log("  │    LastFeeTime                │  ", (await fund.lastFeeTime()).toString());
        console.log("  └───────────────────────────────┴─────────────────");
        console.log("");
    };


    it("user purchase - redeem", async () => {
        await testFund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await testFund.balanceOf(admin)), 1);

        await testFund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await testFund.balanceOf(user1)), 1);

        await testFund.setDelegator(exchange.address);
        const delegateTrade = createTradingContext(perpetual, exchange, testFund, admin);

        await perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(feeder, testFund, perpetual, user1);
        // price + 10%
        await feeder.setPrice("40000000000");
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await testFund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(feeder, testFund, perpetual, user1);
    });

    it("user purchase - redeem (with entrance fee)", async () => {
        debug = false;
        await setConfigurationEntry(testFund, "entranceFeeRate", toWad(0.10));

        await testFund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await testFund.balanceOf(admin)), 1);
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.purchase(toWad(1), toWad(220), { from: user1, value: toWad(220) });
        assert.equal(fromWad(await testFund.balanceOf(user1)), 1);
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.setDelegator(exchange.address);
        const delegateTrade = createTradingContext(perpetual, exchange, testFund, admin);
        await perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(feeder, testFund, perpetual, user1);
        // price + 10%
        await feeder.setPrice("40000000000");
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await testFund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(feeder, testFund, perpetual, user1);
    });

    it("user purchase - redeem (with streaming fee)", async () => {
        debug = true;
        await setConfigurationEntry(testFund, "streamingFeeRate", toWad(0.10));

        await testFund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await testFund.balanceOf(admin)), 1);
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.purchase(toWad(1), toWad(220), { from: user1, value: toWad(220) });
        assert.equal(fromWad(await testFund.balanceOf(user1)), 1);
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.setDelegator(exchange.address);
        const delegateTrade = createTradingContext(perpetual, exchange, testFund, admin);
        await perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(feeder, testFund, perpetual, user1);
        // price + 10%
        await feeder.setPrice("40000000000");
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await testFund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(feeder, testFund, perpetual, user1);

        // 0.000006341989 =
        // 0.000005073598 +
        // 0.000001268391
    });

    it("user purchase - redeem (with performace fee)", async () => {
        debug = true;
        await setConfigurationEntry(testFund, "streamingFeeRate", toWad(0.10));

        await testFund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await testFund.balanceOf(admin)), 1);
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.purchase(toWad(1), toWad(220), { from: user1, value: toWad(220) });
        assert.equal(fromWad(await testFund.balanceOf(user1)), 1);
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.setDelegator(exchange.address);
        const delegateTrade = createTradingContext(perpetual, exchange, testFund, admin);
        await perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(feeder, testFund, perpetual, user1);
        // price + 10%
        await feeder.setPrice("40000000000");
        await printFundState(feeder, testFund, perpetual, user1);

        await testFund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await testFund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(feeder, testFund, perpetual, user1);

        // 0.000006341989 =
        // 0.000005073598 +
        // 0.000001268391
    });
});