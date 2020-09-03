const assert = require("assert");
const BN = require('bn.js');
const BigNumber = require('bignumber.js');
const { encodeInitializData, setParameter, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot, approximatelyEqual
} = require("./utils.js");

BigNumber.set({ ROUNDING_MODE: BigNumber.ROUND_DOWN })

const SocialTradingFund = artifacts.require('TestSocialTradingFund.sol');

contract('SocialTradingFund', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var perpetual;
    var fund;
    var rsistg;
    var debug;

    const deploy = async () => {
        admin = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        deployer = await new PerpetualDeployer(accounts, true);
        await deployer.deploy();
        await deployer.initialize();
        await deployer.setIndex(200);
        await deployer.createPool();

        fund = await SocialTradingFund.new();
        await fund.initialize(
            "Fund Share Token",
            "FST",
            18,
            deployer.perpetual.address,
            toWad(1000000)
        )
        await deployer.globalConfig.addComponent(deployer.perpetual.address, fund.address);
        await fund.setManager(admin, deployer.exchange.address);
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

    const printFundState = async (deployer, fund, user) => {
        if (!debug) {
            return;
        }
        const marginAccount = await deployer.perpetual.getMarginAccount(fund.address);
        console.log("  ┌───────────────────────────────┬─────────────────");
        console.log("  │ Oracle                        │                 ");
        console.log("  │    Price                      │ $", (await deployer.priceFeeder.latestAnswer()).div(new BN(1e8)).toString());
        console.log("  │    Price (inversed)           │ $", (new BN(1e8)).div(await deployer.priceFeeder.latestAnswer()).toString());
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fund                          │                 ");
        console.log("  │    Leverage                   │  ", fromWad(await fund.leverage.call()));
        console.log("  │    TotalSupply                │  ", fromWad(await fund.totalSupply()));
        console.log("  │    NetAssetValuePerShare      │ Ξ", fromWad(await fund.getNetAssetValuePerShare.call()));
        console.log("  │    PositionSize               │  ", fromWad(marginAccount.size));
        console.log("  │    PositionSide               │  ", marginAccount.side == SHORT? "SHORT": marginAccount.side == LONG? "LONG": "FLAT");
        console.log("  ├───────────────────────────────┼─────────────────");
        console.log("  │ Fee                           │                 ");
        console.log("  │    Manager                    │  ", await fund.manager());
        console.log("  │    FeeClaimed                 │  ", fromWad(await fund.totalFeeClaimed()));
        console.log("  │    LastFeeTime                │  ", (await fund.lastFeeTime()).toString());
        console.log("  └───────────────────────────────┴─────────────────");
        console.log("");
    };

    it("normal case - user", async () => {
        await fund.setManager(user1, deployer.exchange.address);

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200), from: user1 });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.purchase(toWad(200), toWad(1), toWad(200), { from: user2, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user2)), 1);

        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await printFundState(deployer, fund, user2);

        await deployer.perpetual.deposit(toWad(1000), {from: user3, value: toWad(1000)});
        // +0.3x -> 0.005 * n / 400 = 0.3 -> n = sell 24,000
        // entry = 0.005,
        await delegateTrade(user1, user3, 'buy', toWad(200), toWad(24000));
        await printFundState(deployer, fund, user2);

        // console.log(await deployer.perpetual.getMarginAccount(fund.address));
        // console.log(await deployer.perpetual.getMarginAccount(user2));
        // price + 100%
        // 0.005 -> 0.0025 | 0.0025 * 24000 = 60.  60 / 460 = 0.13
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user2);
    });

    it("normal case - performance fee", async () => {
        await fund.setManager(user1, deployer.exchange.address);

        await fund.setParameter(toBytes32("performanceFeeRate"), toWad(0.5));

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200), from: user1 });
        assert.equal(fromWad(await fund.balanceOf(user1)), 1);

        await fund.purchase(toWad(200), toWad(1), toWad(200), { from: user2, value: toWad(200) });
        assert.equal(fromWad(await fund.balanceOf(user2)), 1);

        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        await printFundState(deployer, fund, user2);

        await deployer.perpetual.deposit(toWad(1000), {from: user3, value: toWad(1000)});
        // +0.3x -> 0.005 * n / 400 = 0.3 -> n = sell 24,000
        // entry = 0.005,
        await delegateTrade(user1, user3, 'buy', toWad(200), toWad(24000));
        await printFundState(deployer, fund, user2);

        // console.log(await deployer.perpetual.getMarginAccount(fund.address));
        // console.log(await deployer.perpetual.getMarginAccount(user2));
        // price + 100%
        // 0.005 -> 0.0025 | 0.0025 * 24000 = 60.  60 / 460 = 0.13
        await deployer.setIndex(400);
        await printFundState(deployer, fund, user2);
        assert.equal(fromWad(await fund.leverage.call()), -0.13953488372093023255813953488372);

        await fund.withdrawManagementFee(toWad(0)); // update
        await printFundState(deployer, fund, user2);
        // console.log(fromWad(await fund.totalFeeClaimed()));

        await fund.withdrawManagementFee(await fund.totalFeeClaimed());
        assert.equal(fromWad(await fund.totalFeeClaimed()), 0);
    });


    const getCalculator = (entranceFeeRate, streamingFeeRate, performanceFeeRate) => {
        var eRate = new BigNumber(entranceFeeRate);
        var sRatePerSec = new BigNumber(streamingFeeRate).div(new BigNumber(365)).div(new BigNumber(86400));
        var pRate = new BigNumber(performanceFeeRate);
        return (_elapsed, _nav, _maxNAV, _paid, _totalSupply) => {
            var elapsed = new BigNumber(_elapsed);
            var nav = new BigNumber(_nav);
            var maxNAV = new BigNumber(_maxNAV);
            var paid = new BigNumber(_paid);
            var totalSupply = new BigNumber(_totalSupply);

            var streamingFee = nav.times(sRatePerSec).times(elapsed);
            var nav = nav.minus(streamingFee);
            var performanceFee = new BigNumber(0);
            if (nav.div(totalSupply).gt(maxNAV)) {
                performanceFee = nav.minus(maxNAV.times(totalSupply)).times(pRate);
            }
            // var nav = nav.minus(performanceFee);
            // var entranceFee = nav.times(entranceFeeRate);
            // var unitPrice = nav.plus(entranceFee).div(totalSupply);
            // var newAmount = paid.div(unitPrice);
            // var newFee = streamingFee.plus(performanceFee).plus(entranceFee);
            var nav = nav.minus(performanceFee);
            var unitPrice = nav.div(totalSupply);
            var unitEntranceFee = unitPrice.times(entranceFeeRate);
            var finalUnitPrice = unitPrice.plus(unitEntranceFee);
            var newAmount = paid.div(finalUnitPrice);
            var entranceFee = unitEntranceFee.times(newAmount);
            var newFee = streamingFee.plus(performanceFee).plus(entranceFee);

            return {newAmount, newFee};
        }
    }

    const testPurchaseAmount = async (calculator, amount, price, user) => {
        // from contract
        var maxNAV = await fund.maxNetAssetValuePerShare();
        var feePrev = await fund.totalFeeClaimed();
        var marginBalance = await deployer.perpetual.marginBalance.call(fund.address);
        var totalSupply = await fund.totalSupply();

        var purchased = await fund.balanceOf(user);
        var t1 = await fund.lastFeeTime();

        await fund.purchase(toWad(amount*price), toWad(amount), toWad(price), { from: user, value: toWad(amount*price) });
        var t2 = await fund.lastFeeTime();

        var purchased = (await fund.balanceOf(user)).sub(purchased);
        var feePost = await fund.totalFeeClaimed();
        var feeClaimed = feePost.sub(feePrev);
        var totalFee = await fund.managementFee.call();
        // from calc
        var { newAmount, newFee } = calculator(t2.sub(t1).toString(), fromWad(marginBalance.sub(feePrev)), fromWad(maxNAV), amount*price, fromWad(totalSupply));
        // ignore lowest digit
        approximatelyEqual(fromWad(purchased), newAmount, 1000);
        approximatelyEqual(fromWad(feeClaimed), newFee, 1000);
        approximatelyEqual(feePost, totalFee, 0);
    }

    it("normal case - entrance fee + performance fee + streaming fee - 1", async () => {
        await fund.setParameter(toBytes32("entranceFeeRate"), toWad(0.05));
        // assume 0.00000001 per sec, 0.00000001 * 86400 * 365 = 0.31536 = 31.536%
        await fund.setParameter(toBytes32("streamingFeeRate"), toWad(0.31536));
        await fund.setParameter(toBytes32("performanceFeeRate"), toWad(0.2));

        await fund.purchase(toWad(210), toWad(1), toWad(200), { value: toWad(210), from: user1 });

        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        const calr = getCalculator(0.05, 0.31536, 0.2);

        var t1 = await fund.lastFeeTime();
        // 200 * 1.05 = 210,  21000 / 210 = 100.
        await fund.purchase(toWad(21000), toWad(100), toWad(210), { from: user2, value: toWad(21000) });
        var t2 = await fund.lastFeeTime();

        await testPurchaseAmount(calr, 100, 210, user2);

        await deployer.setIndex(400);
        await testPurchaseAmount(calr, 10, 1000, user2);

        await deployer.setIndex(200);
        await testPurchaseAmount(calr, 15, 1000, user2);

        await fund.redeem(await fund.balanceOf(user2), toWad(0), { from: user2 });
        await fund.redeem(await fund.balanceOf(user1), toWad(0), { from: user1 });

        var fee = fromWad(await fund.managementFee.call());
        await fund.withdrawManagementFee(toWad(0)); // update
        assert.equal(fromWad(await fund.managementFee.call()), fee);

        await fund.withdrawManagementFee(await fund.managementFee.call());
    });

    it("normal case - entrance fee + performance fee + streaming fee - 2", async () => {
        // await fund.setParameter(toBytes32("entranceFeeRate"), toWad(0.05));
        // assume 0.00000001 per sec, 0.00000001 * 86400 * 365 = 0.31536 = 31.536%
        await fund.setParameter(toBytes32("streamingFeeRate"), toWad(0.31536));
        // await fund.setParameter(toBytes32("performanceFeeRate"), toWad(0.2));

        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200), from: user1 });

        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        const calr = getCalculator(0.05, 0.31536, 0.2);

        var t1 = await fund.lastFeeTime();
        // 200 * 1.05 = 210,  21000 / 210 = 100.
        await fund.purchase(toWad(21000), toWad(100), toWad(210), { from: user2, value: toWad(21000) });
        var t2 = await fund.lastFeeTime();

        await testPurchaseAmount(calr, 100, 210, user2);

        await deployer.setIndex(400);
        await testPurchaseAmount(calr, 10, 1000, user2);

        await fund.withdrawManagementFee(toWad(0)); // update
        // console.log(await deployer.perpetual.getMarginAccount(fund.address));
        // console.log(fromWad(await fund.managementFee.call()));

        await fund.withdrawManagementFee(await fund.managementFee.call());
        // console.log(await deployer.perpetual.getMarginAccount(fund.address));
        // console.log((await fund.lastFeeTime()).toString());

        await deployer.setIndex(200);
        await testPurchaseAmount(calr, 15, 1000, user2);

        await fund.redeem(await fund.balanceOf(user2), toWad(0), { from: user2 });
        await fund.redeem(await fund.balanceOf(user1), toWad(0), { from: user1 });

        // console.log((await fund.lastFeeTime()).toString());
        // console.log(fromWad(await fund.managementFee.call()));/
    });

    it("normal case - entrance fee + performance fee + streaming fee - 3", async () => {

        await fund.setParameter(toBytes32("streamingFeeRate"), toWad(0.31536));

        // ---------------- 1 ---------------------
        await fund.setTimestamp(1);
        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200), from: user1 });

        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        const calr = getCalculator(0.05, 0.31536, 0.2);

        // 200 * 1.05 = 210,  21000 / 210 = 100.
        await fund.purchase(toWad(21000), toWad(100), toWad(210), { from: user2, value: toWad(21000) });
        await testPurchaseAmount(calr, 100, 210, user2);

        await deployer.setIndex(400);
        await testPurchaseAmount(calr, 10, 1000, user2);

        // ---------------- 5 ---------------------
        await fund.setTimestamp(5);

        await fund.withdrawManagementFee(toWad(0)); // update
        var marginBalance = new BigNumber(await deployer.perpetual.marginBalance.call(fund.address));
        assert.equal((await fund.managementFee.call()).toString(), marginBalance.times(new BigNumber(0.00000004)).toFixed());

        await fund.withdrawManagementFee(await fund.managementFee.call());
        assert.equal((await fund.managementFee.call()).toString(), "0");

        await deployer.setIndex(200);
        await testPurchaseAmount(calr, 15, 1000, user2);

        await fund.setTimestamp(10);
        var marginBalance = new BigNumber(await deployer.perpetual.marginBalance.call(fund.address));
        assert.equal((await fund.managementFee.call()).toString(), marginBalance.times(new BigNumber(0.00000005)).toFixed());
    });


    it("normal case - entrance fee + performance fee + streaming fee - settle", async () => {

        await fund.setParameter(toBytes32("streamingFeeRate"), toWad(0.31536));

        // ---------------- 1 ---------------------
        await fund.setTimestamp(1);
        await fund.purchase(toWad(200), toWad(1), toWad(200), { value: toWad(200), from: user1 });

        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, fund, admin);
        const calr = getCalculator(0.05, 0.31536, 0.2);

        // 200 * 1.05 = 210,  21000 / 210 = 100.
        await fund.purchase(toWad(21000), toWad(100), toWad(210), { from: user2, value: toWad(21000) });
        await testPurchaseAmount(calr, 100, 210, user2);

        await deployer.setIndex(400);
        await testPurchaseAmount(calr, 10, 1000, user2);

        // ---------------- 5 ---------------------
        await fund.setTimestamp(5);

        await fund.setEmergency();
        await shouldThrows(fund.withdrawManagementFee(toWad(0)), "bad state"); // update

        await fund.setShutdown();

        await fund.withdrawManagementFee(toWad(0)); // update
        var marginBalance = new BigNumber(await deployer.perpetual.marginBalance.call(fund.address));
        assert.equal((await fund.managementFee.call()).toString(), marginBalance.times(new BigNumber(0.00000004)).toFixed());

        // ---------------- 10 ---------------------
        await fund.setTimestamp(10);
        assert.equal((await fund.managementFee.call()).toString(), marginBalance.times(new BigNumber(0.00000004)).toFixed());
        await fund.withdrawManagementFee(await fund.managementFee.call());

        // ---------------- 100 ---------------------
        await fund.setTimestamp(100);
        assert.equal((await fund.managementFee.call()).toString(), "0");
    });
});