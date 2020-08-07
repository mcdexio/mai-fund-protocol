const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const MockRSITrendingStrategy = artifacts.require('MockRSITrendingStrategy.sol');
const AutoTraderFund = artifacts.require('AutoTraderFund.sol');

contract('FundAutoTrader', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var perpetual;
    var fund;
    var rsistg;
    var skip;

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

        rsistg = await MockRSITrendingStrategy.new();
        fund = await AutoTraderFund.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            "0x0000000000000000000000000000000000000000",
            18,
            deployer.perpetual.address,
            rsistg.address,
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

    const setValues = async (items) => {
        for (var i = 0; i < items.length; i++) {
            const item = items[i];
            // console.log(i, item, item[0], item[1]);
            await feeder.setPrice(item[0], item[1]);
            await bucket.updatePrice();
        }
    }

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
        console.log("  │    Leverage                   │  ", fromWad(await fund.getCurrentLeverage.call()));
        console.log("  │    NeedRebalance              │  ", await fund.needRebalancing.call());
        console.log("  │    TotalSupply                │  ", fromWad(await fund.totalSupply()));
        console.log("  │    NetAssetValue              │ Ξ", fromWad(await fund.getNetAssetValue.call()));
        console.log("  │    NetAssetValuePerShare      │ Ξ", fromWad(await fund.getNetAssetValuePerShare.call()));
        console.log("  │    PositionSize               │  ", fromWad(marginAccount.size));
        console.log("  │    PositionSide               │  ", marginAccount.side == SHORT? "SHORT": marginAccount.side == LONG? "LONG": "FLAT");
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fee                           │                 ");
        console.log("  │    Manager                    │  ", await fund.manager());
        console.log("  │    FeeClaimed                 │  ", fromWad(await fund.totalFeeClaimed()));
        console.log("  │    LastFeeTime                │  ", (await fund.lastFeeTime()).toString());
        console.log("  └───────────────────────────────┴─────────────────");
        console.log("");
    };

    const printStrategy = (amount, side) => {
        const toSide = (side) => {
            switch (side.toString()) {
                case "0": return "stay";
                case "1": return "short";
                case "2": return "long";
            }
        }
        console.log("next, we should", toSide(side), "for", fromWad(amount));
    }

    it("normal case", async () => {

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });

        await rsistg.setNextTarget(toWad(1));

        var user1 = accounts[2];
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});

        await printFundState(deployer, fund, user1);
        // 100: 0 -> 1
        var {amount, side} = await fund.calculateRebalancingTarget.call();
        printStrategy(amount, side);

        await fund.rebalance(toWad(40000), toWad(0), side);
        await printFundState(deployer, fund, user1);

        // 50: 1 -> 1
        await rsistg.setNextTarget(toWad(1));

        // 11: 1 -> -1
        await rsistg.setNextTarget(toWad(-1));
        var {amount, side} = await fund.calculateRebalancingTarget.call();
        printStrategy(amount, side);

        await fund.rebalance(amount, toWad(100000), side);
        await printFundState(deployer, fund, user1);

        // -1 => 0
        await rsistg.setNextTarget(toWad(0));
        var {amount, side} = await fund.calculateRebalancingTarget.call();
        printStrategy(amount, side);

        await fund.rebalance(amount, toWad(0), side);
        await printFundState(deployer, fund, user1);
    });


    it("normal case - user", async () => {

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        await rsistg.setNextTarget(toWad(1));

        var user1 = accounts[2];
        var balancer = accounts[3];
        await deployer.perpetual.deposit(toWad(1000), {from: balancer, value: toWad(1000)});

        await fund.purchase(toWad(2), toWad(200), { from: user1, value: toWad(400)});
        await printFundState(deployer, fund, user1);

        // -0.3
        await rsistg.setNextTarget(toWad(0.3));
        // acturally 200 * 3 * 0.3 / 0.005 = 36000
        await fund.rebalance(toWad(40000), toWad(0), SHORT);
        await printFundState(deployer, fund, user1);

        console.log((await fund.balanceOf(admin)).toString());
        console.log((await fund.balanceOf(user1)).toString());

        await fund.requestToRedeem(toWad(1), toWad(0.01), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), SHORT);

        await printFundState(deployer, fund, user1);

        await rsistg.setNextTarget(toWad(-1));

        await fund.rebalance(toWad(120000), toWad(100), LONG);
        await printFundState(deployer, fund, user1);


        await fund.requestToRedeem(toWad(1), toWad(0.01), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(1), LONG);

        await printFundState(deployer, fund, user1);
    });
});