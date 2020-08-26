const assert = require("assert");
const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows } = require("./utils.js");
const { PerpetualDeployer } = require("./perpetual.js");
const TestCore = artifacts.require('TestCore.sol');

contract('TestCoreParameter', accounts => {
    var fund;

    const deploy = async () => {

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
    }

    before(deploy);

    it ("set entry", async () => {
        // await fund.setParameter(toBytes32("redeemingLockPeriod"), 6);
        assert.equal(await fund.redeemingLockPeriod(), 0);
        assert.equal(await fund.drawdownHighWaterMark(), 0);
        assert.equal(await fund.leverageHighWaterMark(), 0);

        var { entranceFeeRate, streamingFeeRate, performanceFeeRate } = await fund.feeRates();
        assert.equal(entranceFeeRate, 0);
        assert.equal(streamingFeeRate, 0);
        assert.equal(performanceFeeRate, 0);

        await fund.setParameter(toBytes32("redeemingLockPeriod"), 86400);
        assert.equal(await fund.redeemingLockPeriod(), 86400);
        await fund.setParameter(toBytes32("redeemingLockPeriod"), 0);
        assert.equal(await fund.redeemingLockPeriod(), 0);

        await fund.setParameter(toBytes32("drawdownHighWaterMark"), toWad(0.2));
        assert.equal(await fund.drawdownHighWaterMark(), toWad(0.2));
        await fund.setParameter(toBytes32("drawdownHighWaterMark"), 0);
        assert.equal(await fund.drawdownHighWaterMark(), 0);

        await fund.setParameter(toBytes32("leverageHighWaterMark"), toWad(0.5));
        assert.equal(await fund.leverageHighWaterMark(), toWad(0.5));
        await fund.setParameter(toBytes32("leverageHighWaterMark"), 0);
        assert.equal(await fund.leverageHighWaterMark(), 0);

        await fund.setParameter(toBytes32("entranceFeeRate"), toWad(0.05));
        var { entranceFeeRate, streamingFeeRate, performanceFeeRate } = await fund.feeRates();
        assert.equal(entranceFeeRate, toWad(0.05));

        await fund.setParameter(toBytes32("entranceFeeRate"), 0);
        var { entranceFeeRate, streamingFeeRate, performanceFeeRate } = await fund.feeRates();
        assert.equal(entranceFeeRate, 0);

        await fund.setParameter(toBytes32("streamingFeeRate"), toWad(0.11));
        var { entranceFeeRate, streamingFeeRate, performanceFeeRate } = await fund.feeRates();
        assert.equal(streamingFeeRate, toWad(0.11));

        await fund.setParameter(toBytes32("streamingFeeRate"), 0);
        var { entranceFeeRate, streamingFeeRate, performanceFeeRate } = await fund.feeRates();
        assert.equal(streamingFeeRate, 0);

        await fund.setParameter(toBytes32("performanceFeeRate"), toWad(0.24));
        var { entranceFeeRate, streamingFeeRate, performanceFeeRate } = await fund.feeRates();
        assert.equal(performanceFeeRate, toWad(0.24));

        await fund.setParameter(toBytes32("performanceFeeRate"), toWad(0));
        var { entranceFeeRate, streamingFeeRate, performanceFeeRate } = await fund.feeRates();
        assert.equal(performanceFeeRate, 0);
    });


    it ("out of range value", async () => {
        await shouldThrows(fund.setParameter(toBytes32("leverageHighWaterMark"), (toWad(10.1))), "too high hwm.");
        await shouldThrows(fund.setParameter(toBytes32("entranceFeeRate"), (toWad(100.1))), "too large rate");
        await shouldThrows(fund.setParameter(toBytes32("streamingFeeRate"), (toWad(100.1))), "too large rate");
        await shouldThrows(fund.setParameter(toBytes32("performanceFeeRate"), (toWad(100.1))), "too large rate");
    });
});
