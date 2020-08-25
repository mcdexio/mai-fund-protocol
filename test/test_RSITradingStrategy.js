const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad } = require("./utils.js");
const { buildOrder } = require("./order.js");
const { getPerpetualComponents } = require("./perpetual.js");

const TestPriceFeeder = artifacts.require('TestPriceFeeder.sol');
const PeriodicPriceBucket = artifacts.require('PeriodicPriceBucket.sol');
const TestRSITrendingStrategy = artifacts.require('TestRSITrendingStrategy.sol');

contract('TestRSITrendingStrategy', accounts => {

    var feeder;
    var bucket;
    var rsistg;

    const deploy = async () => {
        feeder = await TestPriceFeeder.new();
        bucket = await PeriodicPriceBucket.new();
        await bucket.initialize(feeder.address);
        rsistg = await TestRSITrendingStrategy.new(
            bucket.address,
            3600,
            3,
            [toWad(40), toWad(60)],
            [
                { begin: 0, end: 0, target: toWad(-1) },
                { begin: 0, end: 1, target: toWad(-1) },
                { begin: 0, end: 2, target: toWad(1) },
                { begin: 1, end: 0, target: toWad(-1) },
                { begin: 1, end: 1, target: toWad(0) },
                { begin: 1, end: 2, target: toWad(1) },
                { begin: 2, end: 0, target: toWad(-1) },
                { begin: 2, end: 1, target: toWad(1) },
                { begin: 2, end: 2, target: toWad(1) },
            ]
        );
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

    it("initial from +1", async () => {
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
            [6, 1595196000],
            [10, 1595199600],
        ])
        await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);

        // initial from +1
        await rsistg.setTimestamp(1595185200);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();

        await rsistg.setTimestamp(1595188800);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();

        await rsistg.setTimestamp(1595192400);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();

        await rsistg.setTimestamp(1595196000);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();

        await rsistg.setTimestamp(1595199600);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();
    });

    it("initial from 0", async () => {
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
            [6, 1595196000],
            [10, 1595199600],
        ])
        await assertArray(3600, 1595174400, 1595192400, [10, 10, 11, 12, 10, 4]);

        // initial from +1
        await rsistg.setTimestamp(1595188800);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();

        await rsistg.setTimestamp(1595192400);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();

        await rsistg.setTimestamp(1595196000);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();

        await rsistg.setTimestamp(1595199600);
        console.log(fromWad(await rsistg.getCurrentRSI()))
        // console.log("  l =>", await rsistg.lastSegment());
        // console.log("  s =>", await rsistg.getSegment());
        console.log("  t =>", fromWad(await rsistg.getNextTarget.call()));
        await rsistg.getNextTarget();
    });
});
