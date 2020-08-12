const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad } = require("./utils.js");
const { buildOrder } = require("./order.js");
const { getPerpetualComponents } = require("./perpetual.js");

const TestPriceFeeder = artifacts.require('TestPriceFeeder.sol');
const PeriodicPriceBucket = artifacts.require('PeriodicPriceBucket.sol');
const TestRSIReader = artifacts.require('TestRSIReader.sol');

contract('TestRSIReader', accounts => {

    var feeder;
    var bucket;
    var reader;

    const deploy = async () => {
        feeder = await TestPriceFeeder.new();
        bucket = await PeriodicPriceBucket.new(feeder.address);
        reader = await TestRSIReader.new(bucket.address, 3600, 3);
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

        // assert.equal(await reader.period(), 3600);
        // assert.equal(await reader.numPeriod(), 3);

        await reader.setTimestamp(1595185200);
        console.log(await reader.retrieveData());
        assert.equal(fromWad(await reader.getCurrentRSI()), 100);

        await reader.setTimestamp(1595188800);
        console.log(await reader.retrieveData());
        assert.equal(fromWad(await reader.getCurrentRSI()), 50);

        await reader.setTimestamp(1595192400);
        console.log(await reader.retrieveData());
        assert.equal(fromWad(await reader.getCurrentRSI()), 11.111111111111111111);
    });
});
