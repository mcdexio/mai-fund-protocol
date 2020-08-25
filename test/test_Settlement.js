const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const TestSettlement = artifacts.require('TestSettlement.sol');

contract('TestSettlement', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var settlement;

    const deploy = async () => {
        admin = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        settlement = await TestSettlement.new();
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

    it("setDrawdownHighWaterMark", async () => {
        await settlement.setDrawdownHighWaterMark(toWad(0.2));
        assert.equal(await settlement.drawdownHighWaterMark(), toWad(0.2));

        await settlement.setDrawdownHighWaterMark(toWad(0.5));
        assert.equal(await settlement.drawdownHighWaterMark(), toWad(0.5));

        await settlement.setDrawdownHighWaterMark(toWad(0));
        assert.equal(await settlement.drawdownHighWaterMark(), toWad(0));

        await shouldThrows(settlement.setDrawdownHighWaterMark(toWad(0.51)), "too high hwm");
    });

    it("setLeverageHighWaterMark", async () => {
        await settlement.setLeverageHighWaterMark(toWad(2));
        assert.equal(await settlement.leverageHighWaterMark(), toWad(2));

        await settlement.setLeverageHighWaterMark(toWad(10));
        assert.equal(await settlement.leverageHighWaterMark(), toWad(10));

        await settlement.setLeverageHighWaterMark(toWad(0));
        assert.equal(await settlement.leverageHighWaterMark(), toWad(0));

        await shouldThrows(settlement.setLeverageHighWaterMark(toWad(10.1)), "too high hwm");
    });

    it("canShutdown", async () => {
        // 20%
        await settlement.setDrawdownHighWaterMark(toWad(0.2));
        await settlement.setLeverageHighWaterMark(toWad(5));

        await settlement.setEmergency(false);
        assert.equal(await settlement.canShutdown.call(), false);

        await settlement.setEmergency(true);
        assert.equal(await settlement.canShutdown.call(), true);
        await settlement.setEmergency(false);

        await settlement.setDrawdown(toWad(0.2));
        assert.equal(await settlement.canShutdown.call(), true);

        await settlement.setDrawdown(toWad(0.1));
        assert.equal(await settlement.canShutdown.call(), false);


        await settlement.setLeverage(toWad(5));
        assert.equal(await settlement.canShutdown.call(), true);
        await settlement.setLeverage(toWad(4));
        assert.equal(await settlement.canShutdown.call(), false);
    });
});