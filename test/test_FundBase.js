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

        fund = await TestFund.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            18,
            deployer.perpetual.address,
            admin,
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
        console.log("  │    Leverage                   │  ", fromWad(await fund.getCurrentLeverage.call()));
        // console.log("  │    NeedRebalance              │  ", await fund.needRebalancing.call());
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

    it("base info", async () => {
        assert.equal(await fund.name(), "Fund Share Token");
        assert.equal(await fund.symbol(), "FST");
        assert.equal(await fund.decimals(), 18);
        assert.equal(await fund.capacity(), toWad(1000));
    });

    it("user purchase - redeem", async () => {
        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.setDelegator(deployer.exchange.address);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);

        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);

        await printFundState(deployer, fund, user1);

        await fund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(deployer, fund, user1);
    });

    it("user purchase - redeem (with entrance fee)", async () => {
        debug = false;
        await setConfigurationEntry(fund, "entranceFeeRate", toWad(0.10));

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);
        await printFundState(deployer, fund, user1);

        console.log("DEBUG", fromWad(await fund.getNetAssetValuePerShare.call()));
        await fund.purchase(toWad(1), toWad(220), { from: user1, value: toWad(220) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);
        await printFundState(deployer, fund, user1);

        await fund.setDelegator(deployer.exchange.address);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user1);

        await fund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(deployer, fund, user1);
    });

    it("user purchase - redeem (with streaming fee)", async () => {
        debug = true;
        await setConfigurationEntry(fund, "streamingFeeRate", toWad(0.31536)); // 0.000864 / day -> 0.00000001 / second

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);
        await printFundState(deployer, fund, user1);
        const lastFeeTimeA = Number((await fund.lastFeeTime()).toString());

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        const lastFeeTimeB = Number((await fund.lastFeeTime()).toString());
        assert.equal(fromWad(await fund.totalFeeClaimed()),  (lastFeeTimeB-lastFeeTimeA) * 0.00000001 * 200);

        // assert.equal(fromWad(await fund.balanceOf(user1)), 1);
        await printFundState(deployer, fund, user1);

        await fund.setDelegator(deployer.exchange.address);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user1);

        await fund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(deployer, fund, user1);

        // 0.000006341989 =
        // 0.000005073598 +
        // 0.000001268391
    });

    it("user purchase - redeem (with performace fee)", async () => {
        debug = true;
        await setConfigurationEntry(fund, "streamingFeeRate", toWad(0.00));

        await fund.create(toWad(1), toWad(200), { value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(admin)), 1);
        await printFundState(deployer, fund, user1);

        await fund.purchase(toWad(1), toWad(200), { from: user1, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);
        await printFundState(deployer, fund, user1);

        await fund.setDelegator(deployer.exchange.address);
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await delegateTrade(admin, user2, 'buy', toWad(200), toWad(1));

        await printFundState(deployer, fund, user1);
        // price + 10%
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user1);

        await fund.requestToRedeem(toWad(1), toWad(0), { from: user1 });
        await fund.bidRedeemingShare(user1, toWad(1), toWad(0), 1);

        await printFundState(deployer, fund, user1);

        // 0.000006341989 =
        // 0.000005073598 +
        // 0.000001268391
    });
});