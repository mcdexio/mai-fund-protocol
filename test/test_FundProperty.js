const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const TestFundProperty = artifacts.require('TestFundProperty.sol');

contract('FundProperty', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var deployer;
    var property;
    var debug = false;

    const deploy = async () => {
        admin = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        deployer = new PerpetualDeployer(accounts, true);
        await deployer.deploy();
        await deployer.initialize();
        await deployer.setIndex(200);
        await deployer.createPool();

        property = await TestFundProperty.new(deployer.perpetual.address);
    }

    before(deploy);

    var snapshotId;
    beforeEach(async () => {
        snapshotId = await createEVMSnapshot();
    });

    afterEach(async function () {
        await restoreEVMSnapshot(snapshotId);
    });

    it("info", async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(1));

        await property.setSelf(user1);

        assert.equal(fromWad(await property.getPositionSizePublic()), 1);
        assert.equal(fromWad(await property.getTotalAssetValuePublic.call()), 1000);

        var res = await property.getNetAssetValueAndFeePublic.call();
        var nav = res[0];
        var fee = res[1];
        assert.equal(fromWad(nav), 1000);
        assert.equal(fromWad(fee), 0);

        await property.setTotalSupply(toWad(100));
        var res = await property.getNetAssetValuePerShareAndFeePublic.call();
        var nav = res[0];
        var fee = res[1];
        // 1000 / 100
        assert.equal(fromWad(nav), 10);
        assert.equal(fromWad(fee), 0);

        var lev = await property.getLeveragePublic.call();
        // margin / margin balance -> 0.005 * 1 / 1000  = 0.000005
        assert.equal(fromWad(lev), -0.000005);

        var drawdown = await property.getDrawdownPublic.call();
        assert.equal(drawdown, 0);
    });

    it('getTotalAssetValue', async () => {
        await shouldThrows(property.getTotalAssetValuePublic.call(), "marginBalance must be greater than 0");
    });

    it('getNetAssetValueAndFeePublic', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));

        await property.setSelf(user1);

        var res = await property.getNetAssetValueAndFeePublic.call();
        var nav = res[0];
        var fee = res[1];
        assert.equal(fromWad(nav), 1000);
        assert.equal(fromWad(fee), 0);

        await property.setTotalFeeClaimed(toWad(99));

        var res = await property.getNetAssetValueAndFeePublic.call();
        var nav = res[0];
        var fee = res[1];
        assert.equal(fromWad(nav), 901);
    });

    it('getNetAssetValueAndFeePublic - fee', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));

        await property.setSelf(user1);

        // steaming fee
        await property.setStreamingFee(toWad(25));
        var res = await property.getNetAssetValueAndFeePublic.call();
        var nav = res[0];
        var fee = res[1];
        assert.equal(fromWad(nav), 975);
        assert.equal(fromWad(fee), 25);
        await property.setStreamingFee(toWad(0));

        await property.setPerformanceFee(toWad(25));
        var res = await property.getNetAssetValueAndFeePublic.call();
        var nav = res[0];
        var fee = res[1];
        assert.equal(fromWad(nav), 975);
        assert.equal(fromWad(fee), 25);
        await property.setPerformanceFee(toWad(0));


        await property.setStreamingFee(toWad(25));
        await property.setPerformanceFee(toWad(25));
        var res = await property.getNetAssetValueAndFeePublic.call();
        var nav = res[0];
        var fee = res[1];
        assert.equal(fromWad(nav), 950);
        assert.equal(fromWad(fee), 50);
        await property.setStreamingFee(toWad(0));
        await property.setPerformanceFee(toWad(0));
    });

    it('getNetAssetValueAndFeePublic - streaming fee', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));

        await property.setSelf(user1);

        await property.setTotalFeeClaimed(toWad(1025));
        await shouldThrows(property.getNetAssetValueAndFeePublic.call(), "total asset value less than fee");
        await property.setTotalFeeClaimed(toWad(0));

        await property.setStreamingFee(toWad(1025));
        await shouldThrows(property.getNetAssetValueAndFeePublic.call(), "incorrect streaming fee rate");
        await property.setStreamingFee(toWad(0));

        await property.setPerformanceFee(toWad(1025));
        await shouldThrows(property.getNetAssetValueAndFeePublic.call(), "incorrect performance fee rate");
        await property.setPerformanceFee(toWad(0));
    });

    it('drawdown', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));
        await property.setSelf(user1);

        await shouldThrows(property.getDrawdownPublic.call(), "no share supplied yet");

        await property.setTotalSupply(toWad(1));
        // 1000
        assert.equal(fromWad(await property.getDrawdownPublic.call()), 0);

        await property.setMaxNetAssetValuePerShare(toWad(1100));
        assert.equal(fromWad(await property.getDrawdownPublic.call()), 100/1100);

        await property.setMaxNetAssetValuePerShare(toWad(1200));
        assert.equal(fromWad(await property.getDrawdownPublic.call()), 200/1200);

        await property.setMaxNetAssetValuePerShare(toWad(2000));
        assert.equal(fromWad(await property.getDrawdownPublic.call()), 1000/2000);

        await property.setMaxNetAssetValuePerShare(toWad(0));
        assert.equal(fromWad(await property.getDrawdownPublic.call()), 0);
    });
});