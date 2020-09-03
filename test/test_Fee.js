const assert = require("assert");
const BigNumber = require('bignumber.js');
const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows, sleep } = require("./utils.js");

const TestFee = artifacts.require('TestFee.sol');

BigNumber.config({ EXPONENTIAL_AT: 1000, ROUNDING_MODE: BigNumber.ROUND_DOWN });

contract('TestFee', accounts => {
    var fundFee;
    var user1;

    const deploy = async () => {
        user1 = accounts[0];

        fundFee = await TestFee.new();
    }

    beforeEach(deploy);

    it("updateFee", async () => {
        var t1 = await fundFee.lastFeeTime();
        await fundFee.updateFee(toWad(100.1));
        assert.equal(await fundFee.totalFeeClaimed(), toWad(100.1));
        var t2 = await fundFee.lastFeeTime();
        assert.ok(t2.toString() > t1.toString());

        await sleep(1000);

        await fundFee.updateFee(toWad(2.33));
        assert.equal(await fundFee.totalFeeClaimed(), toWad(102.43));
        var t3 = await fundFee.lastFeeTime();
        assert.ok(t3.toString() > t2.toString());
    })

    it("updateMaxNetAssetValuePerShare", async () => {
        assert.equal(await fundFee.maxNetAssetValuePerShare(), 0);
        await fundFee.updateMaxNetAssetValuePerShare(toWad(100));

        await sleep(1000);

        await fundFee.updateMaxNetAssetValuePerShare(toWad(1001.1));
        assert.equal(await fundFee.maxNetAssetValuePerShare(), toWad(1001.1));

        await fundFee.updateMaxNetAssetValuePerShare(toWad(1001));
        assert.equal(await fundFee.maxNetAssetValuePerShare(), toWad(1001.1));

        await fundFee.updateMaxNetAssetValuePerShare(toWad(1001.11));
        assert.equal(await fundFee.maxNetAssetValuePerShare(), toWad(1001.11));
    })

    it("entrance fee", async () => {
        await fundFee.setEntranceFeeRate(toWad(0.01));
        assert.equal((await fundFee.entranceFee(toWad(1010))).toString(), toWad(10));
        assert.equal((await fundFee.entranceFee(toWad(0))).toString(), toWad(0));

        await fundFee.setEntranceFeeRate(toWad(0.00));
        assert.equal((await fundFee.entranceFee(toWad(1000))).toString(), toWad(0));
        assert.equal((await fundFee.entranceFee(toWad(1000))).toString(), toWad(0));
    });

    it("performance fee", async () => {
        await fundFee.setPerformanceFeeRate(toWad(0.05));

        var totalSupply = toWad(1);
        await fundFee.mint(user1, toWad(1));

        await fundFee.updateMaxNetAssetValuePerShare(0);
        assert.equal(await fundFee.performanceFee(toWad(1000)), toWad(50));

        await fundFee.updateMaxNetAssetValuePerShare(toWad(1000));
        console.log(fromWad(await fundFee.maxNetAssetValuePerShare()));
        console.log(fromWad(await fundFee.totalSupply()));

        assert.equal(await fundFee.performanceFee(toWad(900)), toWad(0));

        await fundFee.updateMaxNetAssetValuePerShare(toWad(900));
        assert.equal(await fundFee.performanceFee(toWad(1100)), toWad(5));
    })

    describe("streaming fee", async () => {
        const feeTester = (interval, feeRate, netAssetValue) => {
            return async () => {
                console.log("    - begin  ", interval, feeRate, netAssetValue);
                // initial
                await fundFee.setStreamingFeeRate(feeRate); // yearly
                var {fee, timestamp} = await fundFee.streamingFee(netAssetValue);
                assert.equal(fee, toWad(0));

                await fundFee.updateFee(0);
                var begin = await fundFee.lastFeeTime();
                // console.log(begin.toString());

                await sleep(interval);
                await fundFee.foo();

                var {fee, timestamp} = await fundFee.streamingFee(netAssetValue);
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

})
