const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot, checkEtherBalance
} = require("./utils.js");

const MockRSITrendingStrategy = artifacts.require('MockRSITrendingStrategy.sol');
const AutoTradingFund = artifacts.require('TestAutoTradingFund.sol');
const LibTargetCalculator = artifacts.require('LibTargetCalculator.sol');

contract('AutoTradingFund', accounts => {
    const FLAT = 0;
    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var perpetual;
    var fund;
    var rsistg;
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

        const lib1 = await LibTargetCalculator.new();
        AutoTradingFund.link("LibTargetCalculator", lib1.address);

        rsistg = await MockRSITrendingStrategy.new();
        fund = await AutoTradingFund.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            18,
            deployer.perpetual.address,
            toWad(1000),
            rsistg.address,
            true,
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
        const target = await fund.rebalanceTarget.call();

        console.log("  ┌───────────────────────────────┬─────────────────");
        console.log("  │ Oracle                        │                 ");
        console.log("  │    Price                      │ $", (await deployer.priceFeeder.latestAnswer()).div(new BN(1e8)).toString());
        console.log("  │    Price (inversed)           │ $", (new BN(1e8)).div(await deployer.priceFeeder.latestAnswer()).toString());
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fund                          │                 ");
        console.log("  │    Leverage                   │  ", fromWad(await fund.getCurrentLeverage.call()));
        console.log("  │    NeedRebalance              │  ", target.needRebalance);
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

    it("rebalance", async () => {
        var user1 = accounts[2];
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200) });

        await rsistg.setNextTarget(toWad(1));
        await shouldThrows(fund.rebalance(toWad(0), toWad(0), SHORT), "amount is 0");
        await shouldThrows(fund.rebalance(toWad(40000), toWad(0), LONG), "unexpected side");
        await fund.rebalance(toWad(40000), toWad(0), SHORT);

        await rsistg.setNextTarget(toWad(1));
        await shouldThrows(fund.rebalance(toWad(40000), toWad(0), SHORT), "need no rebalance");
    })

    it("normal case", async () => {

        var user1 = accounts[2];
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200) });

        await rsistg.setNextTarget(toWad(1));
        await printFundState(deployer, fund, user1);
        // 100: 0 -> 1
        var {needRebalance, amount, side} = await fund.rebalanceTarget.call();
        printStrategy(amount, side);
        assert.equal(needRebalance, true);
        assert.equal(fromWad(amount), 200 / 0.005);
        assert.equal(side, SHORT);

        await fund.rebalance(toWad(40000), toWad(0), side);
        await printFundState(deployer, fund, user1);

        // 50: 1 -> 1
        await rsistg.setNextTarget(toWad(1));
        await shouldThrows(fund.rebalanceTarget.call(), "need no rebalance");

        // 11: 1 -> -1
        await rsistg.setNextTarget(toWad(-1));
        var {needRebalance, amount, side} = await fund.rebalanceTarget.call();
        printStrategy(amount, side);
        assert.equal(needRebalance, true);
        assert.equal(fromWad(amount), 200 / 0.005 * 2);
        assert.equal(side, LONG);

        await fund.rebalance(amount, toWad(100000), side);
        await printFundState(deployer, fund, user1);

        // -1 => 0
        await rsistg.setNextTarget(toWad(0));
        var {needRebalance, amount, side} = await fund.rebalanceTarget.call();
        printStrategy(amount, side);
        assert.equal(needRebalance, true);
        assert.equal(fromWad(amount), 40000);
        assert.equal(side, SHORT);

        await fund.rebalance(amount, toWad(0), side);
        await printFundState(deployer, fund, user1);
    });


    it("normal case - user", async () => {

        await deployer.perpetual.deposit(toWad(1000), { value: toWad(1000) });

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200) });
        await rsistg.setNextTarget(toWad(1));

        var user1 = accounts[2];
        var balancer = accounts[3];
        await deployer.perpetual.deposit(toWad(1000), {from: balancer, value: toWad(1000)});

        await fund.purchase(toWad(400), toWad(2), toWad(200), { from: user1, value: toWad(400)});
        await printFundState(deployer, fund, user1);

        // -0.3
        await rsistg.setNextTarget(toWad(0.3));
        // acturally 200 * 3 * 0.3 / 0.005 = 36000
        await fund.rebalance(toWad(40000), toWad(0), SHORT);
        await printFundState(deployer, fund, user1);

        console.log((await fund.balanceOf(admin)).toString());
        console.log((await fund.balanceOf(user1)).toString());

        await fund.redeem(toWad(1), toWad(0.01), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), SHORT);

        await printFundState(deployer, fund, user1);

        await rsistg.setNextTarget(toWad(-1));

        await fund.rebalance(toWad(120000), toWad(100), LONG);
        await printFundState(deployer, fund, user1);


        await fund.redeem(toWad(1), toWad(0.01), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(1), LONG);

        await printFundState(deployer, fund, user1);
    });

    it("normal case - price change", async () => {

        // 200 -- 0.005
        await deployer.setIndex(200);
        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200), gasLimit: 8000000 });
        await rsistg.setNextTarget(toWad(1));

        var user1 = accounts[2];

        await deployer.perpetual.deposit(toWad(1000), { from: admin, value: toWad(1000) });
        await deployer.perpetual.deposit(toWad(1000), { from: user1, value: toWad(1000) });

        await fund.purchase(toWad(400), toWad(2), toWad(200), { from: user1, value: toWad(400), gasLimit: 8000000});

        await rsistg.setNextTarget(toWad(0.3));

        await fund.rebalance(toWad(40000), toWad(0), SHORT, { from: admin, gasLimit: 8000000 });

        var nav = fromWad(await fund.netAssetValue.call());
        var totalSupply = fromWad(await fund.totalSupply());
        console.log("  => NAV", nav/totalSupply);
        await printFundState(deployer, fund, user1);

        // 400 -- 0.0025  delta -- 0.0025 * 36000 = 90 (pnl) / 3 = 30
        // nav = 200 + 30
        await deployer.setIndex(400, { gasLimit: 8000000 });
        var nav = fromWad(await fund.netAssetValue.call());
        var totalSupply = fromWad(await fund.totalSupply());
        console.log("  => NAV", nav/totalSupply);
        assert.equal(nav/totalSupply, 230);

        // 100 -- 0.01  delta -- 0.005 * 36000 = 180 (pnl) / 3 = 60
        // nav = 200 - 60
        await deployer.setIndex(100, { gasLimit: 8000000 });
        var nav = fromWad(await fund.netAssetValue.call());
        var totalSupply = fromWad(await fund.totalSupply());
        console.log("  => NAV", nav/totalSupply);
        assert.equal(nav/totalSupply, 140);

        await deployer.setIndex(400, { gasLimit: 8000000 });
        var b1 = await web3.eth.getBalance(user1);
        await fund.redeem(toWad(1), toWad(0.00), { from: user1, gasLimit: 8000000 });
        assert.equal(fromWad(await fund.withdrawableCollateral(user1)), 0);
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), SHORT, { from: user1, gasLimit: 8000000 });
        assert.equal(fromWad(await fund.withdrawableCollateral(user1)), 230);
        return;
    });
});