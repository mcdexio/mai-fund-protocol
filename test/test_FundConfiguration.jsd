const assert = require("assert");
const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows } = require("./utils.js");

const TestFundConfiguration = artifacts.require('TestFundConfiguration.sol');

contract('TestFundConfiguration', accounts => {
    var config;

    const deploy = async () => {
        config = await TestFundConfiguration.new();
    }

    before(deploy);

    it ("set entry", async () => {
        assert.equal(await config.redeemingLockPeriod(), 0);
        assert.equal(await config.drawdownHighWaterMark(), 0);
        assert.equal(await config.leverageHighWaterMark(), 0);
        assert.equal(await config.entranceFeeRate(), 0);
        assert.equal(await config.streamingFeeRate(), 0);
        assert.equal(await config.performanceFeeRate(), 0);

        await config.setRedeemingLockPeriodPublic(86400);
        assert.equal(await config.redeemingLockPeriod(), 86400);
        await config.setRedeemingLockPeriodPublic(0);
        assert.equal(await config.redeemingLockPeriod(), 0);

        await config.setDrawdownHighWaterMarkPublic(toWad(0.2));
        assert.equal(await config.drawdownHighWaterMark(), toWad(0.2));
        await config.setDrawdownHighWaterMarkPublic(0);
        assert.equal(await config.drawdownHighWaterMark(), 0);

        await config.setLeverageHighWaterMarkPublic(toWad(0.5));
        assert.equal(await config.leverageHighWaterMark(), toWad(0.5));
        await config.setLeverageHighWaterMarkPublic(0);
        assert.equal(await config.leverageHighWaterMark(), 0);

        await config.setEntranceFeeRatePublic(toWad(0.05));
        assert.equal(await config.entranceFeeRate(), toWad(0.05));
        await config.setEntranceFeeRatePublic(0);
        assert.equal(await config.entranceFeeRate(), 0);

        await config.setStreamingFeeRatePublic(toWad(0.11));
        assert.equal(await config.streamingFeeRate(), toWad(0.11));
        await config.setStreamingFeeRatePublic(0);
        assert.equal(await config.streamingFeeRate(), 0);

        await config.setPerformanceFeeRatePublic(toWad(0.24));
        assert.equal(await config.performanceFeeRate(), toWad(0.24));
        await config.setPerformanceFeeRatePublic(0);
        assert.equal(await config.performanceFeeRate(), 0);
    });


    it ("out of range value", async () => {
        await shouldThrows(config.setLeverageHighWaterMarkPublic(toWad(10.1)), "hwm exceeds leverage limit");
        await shouldThrows(config.setEntranceFeeRatePublic(toWad(100.1)), "streaming fee rate must be less than 100%");
        await shouldThrows(config.setStreamingFeeRatePublic(toWad(100.1)), "streaming fee rate must be less than 100%");
        await shouldThrows(config.setPerformanceFeeRatePublic(toWad(100.1)), "performance fee rate must be less than 100%");
    });
});
