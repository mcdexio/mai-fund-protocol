const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows } = require("./utils.js");
const { buildOrder } = require("./order.js");
const { getPerpetualComponents } = require("./perpetual.js");

const TestPriceFeeder = artifacts.require('TestPriceFeeder.sol');
const PeriodicPriceBucket = artifacts.require('PeriodicPriceBucket.sol');

contract('PeriodicPriceBucket', accounts => {

    var feeder;
    var bucket;
    var MAX_BUCKET;

    const deploy = async () => {
        feeder = await TestPriceFeeder.new();
        bucket = await PeriodicPriceBucket.new();
        await bucket.initialize(feeder.address);
        MAX_BUCKET = await bucket.MAX_BUCKETS();
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

    // it("0 0x0 feeder", async () => {
    //     await shouldThrows(bucket.setPriceFeeder("0x0000000000000000000000000000000000000000"), "invalid price feeder address");
    //     await shouldThrows(bucket.setPriceFeeder(feeder.address), "price feeder duplicated");

    //     var feeder2 = await TestPriceFeeder.new();
    //     await bucket.setPriceFeeder(feeder2.address);
    //     await shouldThrows(bucket.setPriceFeeder(feeder2.address), "price feeder duplicated");
    // })

    it("set value", async () => {
        await bucket.addBucket(432);
        await bucket.addBucket(10);
        await setValues([
            [10, 1595174400],
            [10, 1595178000],
            [11, 1595181600],
            [12, 1595185200],
            [10, 1595188800],
            [4, 1595192400],
        ])
        var result = await bucket.retrievePriceSeries(432, 1595174400, 1595192400);
        for (var i = 0; i < result.length; i++) {
            console.log(result[i].toString())
        }

        var result = await bucket.retrievePriceSeries(10, 1595174400, 1595192400);
        for (var i = 0; i < result.length; i++) {
            console.log(result[i].toString())
        }
    });


    // it("set value", async () => {
    //     // 10, 1595174400
    //     // 10, 1595178000
    //     // 11, 1595181600
    //     // 12, 1595185200
    //     // 10, 1595188800
    //     //  4, 1595192400

    //     await bucket.addBucket(3600);
    //     await setValues([
    //         [10, 1595174400],
    //         [10, 1595178000],
    //         [11, 1595181600],
    //         [12, 1595185200],
    //         [10, 1595188800],
    //         [4, 1595192400],
    //     ])
    //     await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
    //     await assertArray(3600, 1595178000, 1595192400, [10, 11, 12, 10, 4]);
    //     await assertArray(3600, 1595174400, 1595181600, [10, 10, 11]);
    //     await assertArray(3600, 1595185200, 1595192400, [12, 10, 4]);
    //     await assertArray(3600, 1595185200, 1595185200, [12]);
    // });

    // it("missing set value", async () => {
    //     // 10, 1595174400
    //     // 10, 1595178000
    //     // 11, 1595181600
    //     // 12, 1595185200
    //     // 10, 1595188800
    //     //  4, 1595192400

    //     await bucket.addBucket(3600);
    //     await setValues([
    //         [10, 1595174400],
    //         [11, 1595181600],
    //         [12, 1595185200],
    //         [10, 1595188800],
    //         [4, 1595192400],
    //     ])
    //     await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
    //     await assertArray(3600, 1595178000, 1595192400, [10, 11, 12, 10, 4]);
    //     await assertArray(3600, 1595174400, 1595181600, [10, 10, 11]);
    //     await assertArray(3600, 1595185200, 1595192400, [12, 10, 4]);
    //     await assertArray(3600, 1595185200, 1595185200, [12]);
    // });

    // it("not aligned", async () => {
    //     // 10, 1595174400
    //     // 10, 1595178000
    //     // 11, 1595181600
    //     // 12, 1595185200
    //     // 10, 1595188800
    //     //  4, 1595192400

    //     await bucket.addBucket(3600);
    //     await setValues([
    //         [10, 1595174420],
    //         [11, 1595181630],
    //         [12, 1595185250],
    //         [10, 1595189800],
    //         [4, 1595194400],
    //     ])
    //     await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
    //     // await assertArray(3600, 1595178000, 1595192400, [10, 11, 12, 10, 4]);
    //     // await assertArray(3600, 1595174400, 1595181600, [10, 10, 11]);
    //     // await assertArray(3600, 1595185200, 1595192400, [12, 10, 4]);
    //     // await assertArray(3600, 1595185200, 1595185200, [12]);
    // });


    // it("multiple bucket", async () => {
    //     // 10, 1595174400
    //     // 10, 1595178000
    //     // 11, 1595181600
    //     // 12, 1595185200
    //     // 10, 1595188800
    //     //  4, 1595192400

    //     await bucket.addBucket(3600);
    //     await bucket.addBucket(7200);
    //     await setValues([
    //         [10, 1595174400],
    //         [11, 1595181600],
    //         [12, 1595185200],
    //         [10, 1595188800],
    //         [4, 1595192400],
    //     ])
    //     await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);
    //     await assertArray(7200, 1595174400, 1595192400, [10, 12, 4]);
    // });

    // it("binary search", async () => {
    //     // 10, 1595174400
    //     // 10, 1595178000
    //     // 11, 1595181600
    //     // 12, 1595185200
    //     // 10, 1595188800
    //     //  4, 1595192400

    //     await bucket.addBucket(3600);
    //     await bucket.addBucket(7200);
    //     await setValues([
    //         [10, 1595174400],
    //         [11, 1595181600],
    //         [12, 1595185200],
    //         [10, 1595188800],
    //         [4, 1595192400],
    //     ])
    //     await assertArray(3600, 1595192500, 1595192500, [4]);
    // });

    // it("add bucket", async () => {
    //     await shouldThrows(bucket.addBucket(0), "period must be greater than 0");

    //     await bucket.addBucket(3600);
    //     assert.equal(await bucket.hasBucket(3600), true);
    //     await shouldThrows(bucket.addBucket(3600), "period is duplicated");
    //     await bucket.removeBucket(3600);
    //     assert.equal(await bucket.hasBucket(3600), false);

    //     for (var i = 1; i <= MAX_BUCKET; i++) {
    //         await bucket.addBucket(3600 * i);
    //     }
    //     var periods = await bucket.buckets();
    //     assert.equal(periods.length, MAX_BUCKET);
    //     await shouldThrows(bucket.addBucket(30), "number of buckets reaches limit");
    //     assert.equal(await bucket.hasBucket(30), false);
    // });

    // it("remove bucket", async () => {
    //     await bucket.addBucket(3600);

    //     var periods = await bucket.buckets();
    //     assert.equal(periods.length, 1);
    //     assert.equal(periods[0], 3600);
    //     assert.equal(await bucket.hasBucket(3600), true);

    //     await shouldThrows(bucket.removeBucket(300), "period is not exist");
    //     await bucket.removeBucket(3600);
    //     var periods = await bucket.buckets();
    //     assert.equal(periods.length, 0);
    //     assert.equal(await bucket.hasBucket(3600), false);
    // });

    // it("updatePrice", async () => {
    //     var newBucket = await PeriodicPriceBucket.new()
    //     await shouldThrows(newBucket.initialize("0x0000000000000000000000000000000000000000"), "invalid price feeder address");

    //     await feeder.setPrice(0, 0);
    //     await shouldThrows(bucket.updatePrice(), "invalid price");
    // });

    // it("retrievePriceSeries", async () => {
    //     await deploy();
    //     await bucket.addBucket(30);
    //     await bucket.addBucket(60);
    //     await setValues([
    //         [1, 30],
    //         [2, 60],
    //         [3, 90],
    //         [4, 120],
    //         [5, 150],
    //         [6, 180],
    //         [7, 210],
    //         [8, 240],
    //         [9, 270],
    //     ]);
    //     await assertArray(30, 30, 270, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    //     await assertArray(60, 60, 240, [3, 5, 7, 9]);
    //     await assertArray(60, 60, 270, [3, 5, 7, 9]);

    //     await deploy();
    //     await bucket.addBucket(30);
    //     await bucket.addBucket(60);
    //     await setValues([
    //         [1, 30],
    //         [5, 150],
    //         [6, 180],
    //         [7, 210],
    //         [8, 240],
    //         [9, 270],
    //     ]);
    //     await assertArray(30, 30, 270, [1, 1, 1, 1, 5, 6, 7, 8, 9]);
    //     await assertArray(60, 120, 270, [5, 7, 9]);

    //     await deploy();
    //     await bucket.addBucket(30);
    //     await bucket.addBucket(60);
    //     await setValues([
    //         [1, 30],
    //         [5, 150],
    //         [6, 180],
    //         [7, 210],
    //         [8, 240],
    //     ]);
    //     await assertArray(30, 30, 270, [1, 1, 1, 1, 5, 6, 7, 8, 8]);
    //     await assertArray(30, 30,  30, [1]);
    //     await assertArray(60, 120, 120, [5]);

    //     await deploy();
    //     await bucket.addBucket(30);
    //     await setValues([
    //         [5, 150],
    //         [6, 180],
    //         [7, 210],
    //         [8, 240],
    //     ]);
    //     await shouldThrows(assertArray(30, 30, 270, [1, 1, 1, 1, 5, 6, 7, 8, 8]), "begin is earlier than first time");
    //     await shouldThrows(assertArray(60, 30, 270, [1, 1, 1, 1, 5, 6, 7, 8, 8]), "period is not exist");
    //     await shouldThrows(assertArray(60, 270, 30, [1, 1, 1, 1, 5, 6, 7, 8, 8]), "begin must be earlier than end");
    // });
});
