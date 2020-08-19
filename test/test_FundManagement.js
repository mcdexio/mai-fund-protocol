const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const TestFundManagement = artifacts.require('TestFundManagement.sol');

contract('FundAutoTrader', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var perpetual;
    var management;

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

        management = await TestFundManagement.new(deployer.perpetual.address);
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
        assert.equal(await management.administrator(), admin);

        await management.setConfigurationEntry(toBytes32("redeemingLockPeriod"), 10);
        await management.setConfigurationEntry(toBytes32("drawdownHighWaterMark"), toWad(0.2));
        await management.setConfigurationEntry(toBytes32("leverageHighWaterMark"), toWad(5));

        await shouldThrows(management.setConfigurationEntry(toBytes32("redeemingLockdownPeriod"), 10, {from: user1}), "caller must be administrator");

        await management.setManager(user2);
        assert.equal(await management.manager(), user2);
        await shouldThrows(management.setManager(user1, {from: user1}), "caller must be administrator");

        await management.pause();
        assert.equal(await management.paused(), true);
        await management.unpause();
        assert.equal(await management.paused(), false);
        await shouldThrows(management.pause({from: user1}), "caller must be administrator or maintainer");

        await management.setTotalSupply(toWad(1));

        await shouldThrows(management.shutdown({ from: user1 }), "caller must be administrator or cannot shutdown");
        await management.shutdown();

        assert.equal(await management.stopped(), true);
    });

    it("configuration", async () => {
        await management.setConfigurationEntry(toBytes32("redeemingLockPeriod"), toWad(10));
        assert.equal(await management.getRedeemingLockPeriod(), toWad(10));

        await management.setConfigurationEntry(toBytes32("drawdownHighWaterMark"), toWad(0.2));
        assert.equal(await management.getDrawdownHighWaterMark(), toWad(0.2));

        await management.setConfigurationEntry(toBytes32("leverageHighWaterMark"), toWad(5));
        assert.equal(await management.getLeverageHighWaterMark(), toWad(5));

        await management.setConfigurationEntry(toBytes32("entranceFeeRate"), toWad(0.1));
        assert.equal(await management.getEntranceFeeRate(), toWad(0.1));

        await management.setConfigurationEntry(toBytes32("streamingFeeRate"), toWad(0.2));
        assert.equal(await management.getStreamingFeeRate(), toWad(0.2));

        await management.setConfigurationEntry(toBytes32("performanceFeeRate"), toWad(0.5));
        assert.equal(await management.getPerformanceFeeRate(), toWad(0.5));

        await shouldThrows(management.setConfigurationEntry(toBytes32("notExist"), toWad(0.5)), "unrecognized key");
    });

    it("canShutdown", async () => {
        // 20%
        await management.setConfigurationEntry(toBytes32("drawdownHighWaterMark"), toWad(0.2));
        await management.setConfigurationEntry(toBytes32("leverageHighWaterMark"), toWad(5));

        assert.equal(await management.canShutdown.call(), false);

        await management.setDrawdown(toWad(0.2));
        assert.equal(await management.canShutdown.call(), true);
        await management.setDrawdown(toWad(0.1));
        assert.equal(await management.canShutdown.call(), false);


        await management.setLeverage(toWad(5));
        assert.equal(await management.canShutdown.call(), true);
        await management.setLeverage(toWad(4));
        assert.equal(await management.canShutdown.call(), false);
    });

    it("shutdown - admin", async () => {
        // 20%
        await management.setConfigurationEntry(toBytes32("drawdownHighWaterMark"), toWad(0.2));
        await management.setConfigurationEntry(toBytes32("leverageHighWaterMark"), toWad(5));

        assert.equal(await management.canShutdown.call(), false);

        await management.setTotalSupply(toWad(100));
        await management.shutdown();

        assert.equal(await management.stopped(), true);
        // assert.equal(await management.balance(management.address), toWad(100));
        assert.equal(await management.redeemingBalance(management.address), toWad(100));
        assert.equal(await management.redeemingSlippage(management.address), toWad(0));
    });

    it("shutdown - user", async () => {
        // 20%
        await management.setConfigurationEntry(toBytes32("drawdownHighWaterMark"), toWad(0.2));
        await management.setConfigurationEntry(toBytes32("leverageHighWaterMark"), toWad(5));

        assert.equal(await management.canShutdown.call(), false);

        await management.setDrawdown(toWad(0.2));
        await management.setTotalSupply(toWad(100));
        await management.shutdown({ from: user1 });

        assert.equal(await management.stopped(), true);
        // assert.equal(await management.balance(management.address), toWad(100));
        assert.equal(await management.redeemingBalance(management.address), toWad(100));
        assert.equal(await management.redeemingSlippage(management.address), toWad(0));
    });
});