const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const MockPerpetual = artifacts.require('MockPerpetual.sol');
const TestFund = artifacts.require('TestFund.sol');

const TestPriceFeeder = artifacts.require('TestPriceFeeder.sol');
const PeriodicPriceBucket = artifacts.require('PeriodicPriceBucket.sol');
const TestRSITrendingStrategy = artifacts.require('TestRSITrendingStrategy.sol');
const AutoTraderFund = artifacts.require('AutoTraderFund.sol');

contract('FundAutoTrader', accounts => {
    var user1;
    var user2;
    var user3;
    var admin;

    var perpetual;
    var fund;
    var rsistg;

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

        feeder = await TestPriceFeeder.new();
        bucket = await PeriodicPriceBucket.new(feeder.address);
        rsistg = await TestRSITrendingStrategy.new(
            bucket.address,
            3600,
            3,
            [toWad(40), toWad(60)],
            [
                { begin: 0, end: 0, target: toWad(-1) },
                { begin: 0, end: 1, target: toWad(-1) },
                { begin: 0, end: 2, target: toWad(1) },
                { begin: 1, end: 0, target: toWad(-1) },
                { begin: 1, end: 1, target: toWad(0) },
                { begin: 1, end: 2, target: toWad(1) },
                { begin: 2, end: 0, target: toWad(-1) },
                { begin: 2, end: 1, target: toWad(1) },
                { begin: 2, end: 2, target: toWad(1) },
            ]
        );
        fund = await AutoTraderFund.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            "0x0000000000000000000000000000000000000000",
            18,
            deployer.perpetual.address,
            rsistg.address,
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

    const setValues = async (items) => {
        for (var i = 0; i < items.length; i++) {
            const item = items[i];
            // console.log(i, item, item[0], item[1]);
            await feeder.setPrice(item[0], item[1]);
            await bucket.updatePrice();
        }
    }

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

    it("normal case", async () => {

        bucket.addBucket(3600);
        await setValues([
            [10, 1595174400],
            [10, 1595178000],
            [11, 1595181600],
            [12, 1595185200],
            [10, 1595188800],
            [4, 1595192400],
            [6, 1595196000],
            [10, 1595199600],
        ])

        console.log(fromWad(await deployer.perpetual.markPrice.call()));

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });

        await rsistg.setTimestamp(1595185200);
        assert.equal(fromWad(await rsistg.getCurrentRSI()), 100);
        console.log("lv =>", fromWad(await fund.getCurrentLeverage.call()));
        console.log("nb =>", await fund.needRebalancing.call());
        var {amount, side} = await fund.calculateRebalancingTarget.call();

        console.log(fromWad(await deployer.perpetual.marginBalance.call(fund.address)));
        console.log(fromWad(amount), side);

        var user1 = accounts[2];
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await fund.rebalance(toWad(40000), toWad(300), side);

        console.log("lv =>", fromWad(await fund.getCurrentLeverage.call()));
        console.log("nb =>", await fund.needRebalancing.call());
        console.log(await deployer.perpetual.getMarginAccount(fund.address));
    });
});