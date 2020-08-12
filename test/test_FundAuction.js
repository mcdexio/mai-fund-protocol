const assert = require("assert");
const BN = require('bn.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot,
} = require("./utils.js");

const TestFundAuction = artifacts.require('TestFundAuction.sol');

contract('TestFundAuction', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var deployer;
    var auction;
    var debug = false;

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

        auction = await TestFundAuction.new(deployer.perpetual.address);
        await deployer.globalConfig.addComponent(deployer.perpetual.address, auction.address);
    }

    before(deploy);

    var snapshotId;
    beforeEach(async () => {
        snapshotId = await createEVMSnapshot();
    });

    afterEach(async function () {
        await restoreEVMSnapshot(snapshotId);
    });

    it("price", async () => {
        var {tradingPrice, priceLoss} = await auction.biddingPrice.call(LONG, toWad(0.01));
        assert.equal(fromWad(tradingPrice), 0.005 * 0.99);
        assert.equal(fromWad(priceLoss), 0.005 * 0.01);
        var {tradingPrice, priceLoss} = await auction.biddingPrice.call(SHORT, toWad(0.01));
        assert.equal(fromWad(tradingPrice), 0.005 * 1.01);
        assert.equal(fromWad(priceLoss), 0.005 * 0.01);

        var {tradingPrice, priceLoss} = await auction.biddingPrice.call(LONG, toWad(0.03));
        assert.equal(fromWad(tradingPrice), 0.005 * 0.97);
        assert.equal(fromWad(priceLoss), 0.005 * 0.03);
        var {tradingPrice, priceLoss} = await auction.biddingPrice.call(SHORT, toWad(0.03));
        assert.equal(fromWad(tradingPrice), 0.005 * 1.03);
        assert.equal(fromWad(priceLoss), 0.005 * 0.03);

        var {tradingPrice, priceLoss} = await auction.biddingPrice.call(LONG, toWad(1));
        assert.equal(fromWad(tradingPrice), 0.005 * 0);
        assert.equal(fromWad(priceLoss), 0.005 * 1);
        var {tradingPrice, priceLoss} = await auction.biddingPrice.call(SHORT, toWad(1));
        assert.equal(fromWad(tradingPrice), 0.005 * 2);
        assert.equal(fromWad(priceLoss), 0.005 * 1);
    });

    it("validate price", async () => {
        assert.ok(await auction.validateBiddingPrice(LONG, 1000, 1000));
        assert.ok(await auction.validateBiddingPrice(LONG, 1000, 1002));
        await shouldThrows(auction.validateBiddingPrice(LONG, 1000, 999), "price too low for long");

        assert.ok(await auction.validateBiddingPrice(SHORT, 1000, 1000));
        assert.ok(await auction.validateBiddingPrice(SHORT, 1000, 999));
        await shouldThrows(auction.validateBiddingPrice(SHORT, 1000, 1001), "price too high for short");
    })

    const prepare = async (side) => {
        await deployer.perpetual.deposit(toWad(1000), {from: user1, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user2, value: toWad(1000)});
        await deployer.perpetual.deposit(toWad(1000), {from: user3, value: toWad(1000)});

        const delegateTrade = createTradingContext(deployer.perpetual, deployer.exchange, null, admin);
        await delegateTrade(user1, user3, side, toWad(200), toWad(20000)); 
        
        var margin = await deployer.perpetual.getMarginAccount(user1);
        assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user1)), 1000);
        assert.equal(fromWad(margin.size), 20000);
        assert.equal(margin.side, side == "buy"? SHORT: LONG);
        // user1 -- mock fund
        // user2 -- keeper
        await auction.setSelf(user1);
        await auction.setTotalSupply(toWad(100));
        await auction.setRedeemingBalances(user2, toWad(2));
    }

    it("bidding no slippage", async () => {
        await prepare("buy");
        await auction.bidShare(toWad(2), toWad(0.005), SHORT, toWad(0), { from: user2 });
        {
            var margin = await deployer.perpetual.getMarginAccount(user1);
            assert.equal(margin.side, SHORT);
            assert.equal(fromWad(margin.size), 20000 - 400);
            assert.equal(fromWad(margin.entryValue), 0.005 * (20000 - 400));
            assert.equal(fromWad(await deployer.perpetual.pnl.call(user1)), 0);
            assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user1)), 1000);
        }
        {
            var margin = await deployer.perpetual.getMarginAccount(user2);
            assert.equal(margin.side, SHORT);
            assert.equal(fromWad(margin.size), 400);
            assert.equal(fromWad(margin.entryValue), 0.005 * 400);
            assert.equal(fromWad(await deployer.perpetual.pnl.call(user2)), 0);
            assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user2)), 1000);
        }
    });

    it("bidding 5% slippage, short", async () => {
        await prepare("buy");
        // 5% slippage
        await shouldThrows(auction.bidShare.call(toWad(2), toWad(0.005), LONG, toWad(0.05), { from: user2 }), "unexpected side");
        var loss = await auction.bidShare.call(toWad(2), toWad(0.005), SHORT, toWad(0.05), { from: user2 });
        await auction.bidShare(toWad(2), toWad(0.005), SHORT, toWad(0.05), { from: user2 });
        {
            // price == 0.005 - 0.00025 == 0.00475
            var margin = await deployer.perpetual.getMarginAccount(user1);
            assert.equal(margin.side, SHORT);
            assert.equal(fromWad(margin.size), 20000 - 400);
            assert.equal(fromWad(margin.entryValue), 0.005 * (20000 - 400));
            assert.equal(fromWad(await deployer.perpetual.pnl.call(user1)), 0);
            assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user1)), 1000 - 0.00025 * 400);
        }
        {
            var margin = await deployer.perpetual.getMarginAccount(user2);
            assert.equal(margin.side, SHORT);
            assert.equal(fromWad(margin.size), 400);
            assert.equal(fromWad(margin.entryValue), 0.00525 * 400);
            assert.equal(fromWad(await deployer.perpetual.pnl.call(user2)), 0.00025 * 400);
            assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user2)), 1000 + 0.00025 * 400);
            assert.equal(fromWad(loss), 0.00025 * 400);
        }
    });

    it("bidding 5% slippage, long", async () => {
        await prepare("sell");
        // 5% slippage
        await shouldThrows(auction.bidShare.call(toWad(2), toWad(0.005), SHORT, toWad(0.05), { from: user2 }), "unexpected side");
        var loss = await auction.bidShare.call(toWad(2), toWad(0.005), LONG, toWad(0.05), { from: user2 });
        await auction.bidShare(toWad(2), toWad(0.005), LONG, toWad(0.05), { from: user2 });
        {
            // price == 0.005 - 0.00025 == 0.00475
            var margin = await deployer.perpetual.getMarginAccount(user1);
            assert.equal(margin.side, LONG);
            assert.equal(fromWad(margin.size), 20000 - 400);
            assert.equal(fromWad(margin.entryValue), 0.005 * (20000 - 400));
            assert.equal(fromWad(await deployer.perpetual.pnl.call(user1)), 0);
            assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user1)), 1000 - 0.00025 * 400);
        }
        {
            var margin = await deployer.perpetual.getMarginAccount(user2);
            assert.equal(margin.side, LONG);
            assert.equal(fromWad(margin.size), 400);
            assert.equal(fromWad(margin.entryValue), 0.00475 * 400);
            assert.equal(fromWad(await deployer.perpetual.pnl.call(user2)), 0.00025 * 400);
            assert.equal(fromWad(await deployer.perpetual.marginBalance.call(user2)), 1000 + 0.00025 * 400);
            assert.equal(fromWad(loss), 0.00025 * 400);
        }
    });
});


