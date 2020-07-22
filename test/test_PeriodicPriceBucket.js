const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad } = require("./utils.js");
const { buildOrder } = require("./order.js");
const { getPerpetualComponents } = require("./perpetual.js");

const TestPriceFeeder = artifacts.require('TestPriceFeeder.sol');
const PeriodicPriceBucket = artifacts.require('PeriodicPriceBucket.sol');

contract('PeriodicPriceBucket', accounts => {

    var feeder;
    var bucket;

    const deploy = async () => {
        feeder = await TestPriceFeeder.new();
        bucket = await PeriodicPriceBucket.new(feeder.address);
    };

    beforeEach(deploy);

    const setValues = async (items) => {
        for (var i = 0; i < items.length; i++) {
            const item = items[i];
            // console.log(i, item, item[0], item[1]);
            await feeder.setPrice(item[0], item[1]);
            await bucket.updatePrice();
        }
    }

    const assertArray = async (interval, begin, end, outputs) => {
        var result = await bucket.retrievePriceSeries(interval, begin, end);
        assert.equal(result.length, outputs.length, "length not match");
        for (var i = 0; i < outputs.length; i++) {
            assert.equal(result[i], outputs[i]);
        }
    }

    it("set value", async () => {
        // 10, 1595174400
        // 10, 1595178000
        // 11, 1595181600
        // 12, 1595185200
        // 10, 1595188800
        //  4, 1595192400

        bucket.addBucket(3600);
        await setValues([
            [10, 1595174400],
            [10, 1595178000],
            [11, 1595181600],
            [12, 1595185200],
            [10, 1595188800],
            [4, 1595192400],
        ])
        await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
        await assertArray(3600, 1595178000, 1595192400, [10, 11, 12, 10, 4]);
        await assertArray(3600, 1595174400, 1595181600, [10, 10, 11]);
        await assertArray(3600, 1595185200, 1595192400, [12, 10, 4]);
        await assertArray(3600, 1595185200, 1595185200, [12]);
    });

    it("missing set value", async () => {
        // 10, 1595174400
        // 10, 1595178000
        // 11, 1595181600
        // 12, 1595185200
        // 10, 1595188800
        //  4, 1595192400

        bucket.addBucket(3600);
        await setValues([
            [10, 1595174400],
            [11, 1595181600],
            [12, 1595185200],
            [10, 1595188800],
            [4, 1595192400],
        ])
        await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
        await assertArray(3600, 1595178000, 1595192400, [10, 11, 12, 10, 4]);
        await assertArray(3600, 1595174400, 1595181600, [10, 10, 11]);
        await assertArray(3600, 1595185200, 1595192400, [12, 10, 4]);
        await assertArray(3600, 1595185200, 1595185200, [12]);
    });

    it("not aligned", async () => {
        // 10, 1595174400
        // 10, 1595178000
        // 11, 1595181600
        // 12, 1595185200
        // 10, 1595188800
        //  4, 1595192400

        bucket.addBucket(3600);
        await setValues([
            [10, 1595174420],
            [11, 1595181630],
            [12, 1595185250],
            [10, 1595189800],
            [4, 1595194400],
        ])
        await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
        // await assertArray(3600, 1595178000, 1595192400, [10, 11, 12, 10, 4]);
        // await assertArray(3600, 1595174400, 1595181600, [10, 10, 11]);
        // await assertArray(3600, 1595185200, 1595192400, [12, 10, 4]);
        // await assertArray(3600, 1595185200, 1595185200, [12]);
    });


    it("multiple bucket", async () => {
        // 10, 1595174400
        // 10, 1595178000
        // 11, 1595181600
        // 12, 1595185200
        // 10, 1595188800
        //  4, 1595192400

        bucket.addBucket(3600);
        bucket.addBucket(7200);
        await setValues([
            [10, 1595174400],
            [11, 1595181600],
            [12, 1595185200],
            [10, 1595188800],
            [4, 1595192400],
        ])
        await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
        await assertArray(7200, 1595174400, 1595192400, [10, 12, 4]);
    });

    it("binary search", async () => {
        // 10, 1595174400
        // 10, 1595178000
        // 11, 1595181600
        // 12, 1595185200
        // 10, 1595188800
        //  4, 1595192400

        bucket.addBucket(3600);
        bucket.addBucket(7200);
        await setValues([
            [10, 1595174400],
            [11, 1595181600],
            [12, 1595185200],
            [10, 1595188800],
            [4, 1595192400],
        ])
        await assertArray(3600, 1595192500, 1595192500, [4]);
    });
});
