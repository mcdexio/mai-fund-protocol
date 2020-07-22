const assert = require("assert");
const BigNumber = require('bignumber.js');
const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows, sleep } = require("./utils.js");

const TestFundFee = artifacts.require('TestFundFee.sol');

BigNumber.config({ EXPONENTIAL_AT: 1000, ROUNDING_MODE: BigNumber.ROUND_DOWN });

contract('TestFundFee', accounts => {
    var fundFee;

    const deploy = async () => {
        fundFee = await TestFundFee.new();
    }

    beforeEach(deploy);

    it("updateFeeState", async () => {
        assert.equal(await fundFee.totalFeeClaimed(), 0);
        await fundFee.updateFeeStatePublic(0, toWad(100));
        assert.equal(await fundFee.totalFeeClaimed(), 0);
        var t1 = await fundFee.lastFeeTime();
        assert.ok(t1.toString() > 0);

        await sleep(1000);

        await fundFee.updateFeeStatePublic(toWad(100.1), toWad(0));
        assert.equal(await fundFee.totalFeeClaimed(), toWad(100.1));
        var t2 = await fundFee.lastFeeTime();
        assert.ok(t2.toString() > t1.toString());

        await sleep(1000);

        await fundFee.updateFeeStatePublic(toWad(2.33), toWad(0));
        assert.equal(await fundFee.totalFeeClaimed(), toWad(102.43));
        var t3 = await fundFee.lastFeeTime();
        assert.ok(t3.toString() > t2.toString());

        await fundFee.updateFeeStatePublic(0, toWad(1001.1));
        assert.equal(await fundFee.maxNetAssetValuePerShare(), toWad(1001.1));

        await fundFee.updateFeeStatePublic(0, toWad(1001));
        assert.equal(await fundFee.maxNetAssetValuePerShare(), toWad(1001.1));

        await fundFee.updateFeeStatePublic(0, toWad(1001.11));
        assert.equal(await fundFee.maxNetAssetValuePerShare(), toWad(1001.11));
    })

    it("entrance fee", async () => {
        await fundFee.setEntranceFeeRatePublic(toWad(0.01));
        assert.equal((await fundFee.getEntranceFeePublic(toWad(1000))).toString(), toWad(10));
        assert.equal((await fundFee.getEntranceFeePublic(toWad(0))).toString(), toWad(0));

        await fundFee.setEntranceFeeRatePublic(toWad(0.00));
        assert.equal((await fundFee.getEntranceFeePublic(toWad(1000))).toString(), toWad(0));
        assert.equal((await fundFee.getEntranceFeePublic(toWad(1000))).toString(), toWad(0));
    });

    describe("streaming fee", async () => {
        const feeTester = (interval, feeRate, netAssetValue) => {
            return async () => {
                console.log("    - begin  ", interval, feeRate, netAssetValue);
                // initial
                await fundFee.setStreamingFeeRatePublic(feeRate); // yearly
                var {fee, timestamp} = await fundFee.getStreamingFeePublic(netAssetValue);
                assert.equal(fee, toWad(0));

                await fundFee.updateFeeStatePublic(0, 0);
                var begin = await fundFee.lastFeeTime();
                // console.log(begin.toString());

                await sleep(interval);
                await fundFee.foo();

                var {fee, timestamp} = await fundFee.getStreamingFeePublic(netAssetValue);
                var diff = new BigNumber(timestamp.toString()).minus(new BigNumber(begin.toString()));

                var expected = (new BigNumber(netAssetValue))
                    .times(new BigNumber(feeRate))
                    .div(new BigNumber(toWad(31536000)))
                    .times(diff);

                // console.log("exp  =", expected.toFixed(0));
                // console.log("fee  =", fee.toString());
                assert.equal(expected.toFixed(0), fee.toString());
                console.log("    - end    ", interval, feeRate, netAssetValue);
            }
        }
        it("rate - 0%", feeTester(2000, toWad(0.01), toWad(1000)));
        it("rate - 0.01%", feeTester(2000, toWad(0.0001), toWad(1000)));
        it("rate - 0.1%", feeTester(2000, toWad(0.001), toWad(1000)));
        it("rate - 1%", feeTester(2000, toWad(0.01), toWad(1000)));
        it("rate - 100%", feeTester(2000, toWad(1), toWad(1000)));
    })

    it("performance fee", async () => {
        await fundFee.setTotalSupply(toWad(1));
        await fundFee.setPerformanceFeeRatePublic(toWad(0.05));
        await fundFee.updateFeeStatePublic(0, 0);
        assert.equal(await fundFee.getPerformanceFeePublic(toWad(1000)), toWad(50));
        await fundFee.updateFeeStatePublic(0, toWad(1000));

        assert.equal(await fundFee.getPerformanceFeePublic(toWad(900)), toWad(0));
        await fundFee.updateFeeStatePublic(0, toWad(900));

        assert.equal(await fundFee.getPerformanceFeePublic(toWad(1100)), toWad(5));
        await fundFee.updateFeeStatePublic(0, toWad(1100));
    })
})
