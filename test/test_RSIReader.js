const BN = require("bn.js");
const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows } = require("./utils.js");
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

    const assertN = async (result, expect) => {
        assert.equal(result.length, expect.length);
        for (var i = 0; i < expect.length; i++) {
            assert.equal(result[i], expect[i]);
        }
    }

    it("property", async () => {
        assert.equal(await reader.period(), 3600);
        assert.equal(await reader.numPeriod(), 3);
    });

    it("constructor", async () => {
        await shouldThrows(TestRSIReader.new("0x0000000000000000000000000000000000000000", 3600, 3), "invalid price reader");
        await shouldThrows(TestRSIReader.new("0x0000000000000000000000000000000000000000", 3600, 3), "invalid price reader");
        await shouldThrows(TestRSIReader.new(bucket.address, 0, 3), "period must be greater than 0");
        await shouldThrows(TestRSIReader.new(bucket.address, 3600, 0), "num period must be greater than 0");
    });

    it("calculateRSI", async () => {
        // 100 100 100 100  50  11
        var rsi = await reader.calculateRSI([
            toWad(10), toWad(10), toWad(11)
        ]);
        assert.equal(fromWad(rsi), 100);

        var rsi = await reader.calculateRSI([
            toWad(10), toWad(10), toWad(11), toWad(12)
        ]);
        assert.equal(fromWad(rsi), 100);

        var rsi = await reader.calculateRSI([
            toWad(10), toWad(11), toWad(12), toWad(10)
        ]);
        assert.equal(fromWad(rsi), 50);

        var rsi = await reader.calculateRSI([
            toWad(11), toWad(12), toWad(10), toWad(4)
        ]);
        assert.equal(fromWad(rsi), 11.111111111111111111);

    })

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
        assertN(await reader.retrieveData(), [10, 10, 11, 12]);
        assert.equal(fromWad(await reader.getCurrentRSI()), 100);

        await reader.setTimestamp(1595188800);
        // console.log(await reader.retrieveData());
        assertN(await reader.retrieveData(), [10, 11, 12, 10]);
        assert.equal(fromWad(await reader.getCurrentRSI()), 50);

        await reader.setTimestamp(1595192400);
        assertN(await reader.retrieveData(), [11, 12, 10, 4]);
        assert.equal(fromWad(await reader.getCurrentRSI()), 11.111111111111111111);
    });
});
