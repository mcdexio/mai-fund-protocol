const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const TestStatus = artifacts.require('TestStatus.sol');

contract('TestStatus', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var deployer;
    var status;
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

        status = await TestStatus.new("TTK", "TTK", toWad(10000), deployer.perpetual.address);
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

        await status.setSelf(user1);

        assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user1)), 1000);

        var netAssetValue = await status.netAssetValue.call();
        assert.equal(fromWad(netAssetValue), 1000);

        await status.mint(user1, toWad(100)); // + totalSupply
        assert.equal(fromWad(await status.netAssetValuePerShare.call(netAssetValue)), 10);

        // margin / margin balance -> 0.005 * 1 / 1000  = 0.000005
        assert.equal(fromWad(await status.leverage.call()), -0.000005);
        assert.equal(fromWad(await status.drawdown.call()), 0);
    });

    it('netAssetValue', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));

        await status.setSelf(user1);
        assert.equal(fromWad(await status.netAssetValue.call()), 1000);

        await status.setTotalFeeClaimed(toWad(99));
        assert.equal(fromWad(await status.netAssetValue.call()), 901);

        await status.setStreamingFee(toWad(101));
        assert.equal(fromWad(await status.netAssetValue.call()), 901);
        assert.equal(fromWad(await status.netAssetValueEx.call()), 800);
    });

    it('netAssetValue - fee', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));

        await status.setSelf(user1);

        // steaming fee
        await status.setStreamingFee(toWad(25));
        await status.setPerformanceFee(toWad(0));
        await status.netAssetValueEx();
        assert.equal(fromWad(await status.netAssetValue.call()), 975);
        assert.equal(fromWad(await status.totalFeeClaimed()), 25);

        await status.setStreamingFee(toWad(0));
        await status.setPerformanceFee(toWad(25));
        await status.netAssetValueEx();
        assert.equal(fromWad(await status.netAssetValue.call()), 950);
        assert.equal(fromWad(await status.totalFeeClaimed()), 50);

        await status.setStreamingFee(toWad(25));
        await status.setPerformanceFee(toWad(25));
        await status.netAssetValueEx();
        assert.equal(fromWad(await status.netAssetValue.call()), 900);
        assert.equal(fromWad(await status.totalFeeClaimed()), 100);
    });

    it('drawdown', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));
        await status.setSelf(user1);

        assert.equal(fromWad(await status.drawdown.call()), 0);

        await status.mint(user1, toWad(1));

        await status.setMaxNetAssetValuePerShare(toWad(1100));
        assert.equal(fromWad(await status.drawdown.call()), 100/1100);

        await status.setMaxNetAssetValuePerShare(toWad(1200));
        assert.equal(fromWad(await status.drawdown.call()), 200/1200);

        await status.setMaxNetAssetValuePerShare(toWad(2000));
        assert.equal(fromWad(await status.drawdown.call()), 1000/2000);

        await status.setMaxNetAssetValuePerShare(toWad(0));
        assert.equal(fromWad(await status.drawdown.call()), 0);
    });

    it('leverage', async () => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});

        await status.setSelf(user1);
        await status.mint(user1, toWad(1));

        // 200 -- 0.005; 0.005 * 10 = 0.05; 0.05 / 1000 = 0.00005
        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));
        assert.equal(fromWad(await status.leverage.call()), -0.00005);

        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(10));
        assert.equal(fromWad(await status.leverage.call()), -0.0001);

        await delegateTrade(user1, user2, 'sell', toWad(200), toWad(40));
        assert.equal(fromWad(await status.leverage.call()), 0.0001);

        await delegateTrade(user1, user2, 'buy', toWad(200), toWad(20));
        assert.equal(fromWad(await status.leverage.call()), 0);
    });
});