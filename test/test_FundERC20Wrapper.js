const assert = require("assert");
const BN = require('bn.js');
const BigNumber = require('bignumber.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot, infinity
} = require("./utils.js");

const TestFundERC20Wrapper = artifacts.require('TestFundERC20Wrapper.sol');

contract('TestFundERC20Wrapper', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var erc20;

    const deploy = async () => {
        admin = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        erc20 = await TestFundERC20Wrapper.new("Test Share Token", "TST");
    }

    before(deploy);

    var snapshotId;
    beforeEach(async () => {
        snapshotId = await createEVMSnapshot();
    });

    afterEach(async function () {
        await restoreEVMSnapshot(snapshotId);
    });

    it("basic", async () => {
        assert.equal(await erc20.name(), "Test Share Token");
        assert.equal(await erc20.symbol(), "TST");
        assert.equal(await erc20.decimals(), 18);
        assert.equal(await erc20.totalSupply(), 0);
    })

    it("transfer", async () => {
        await erc20.mint(user1, toWad(10));
        await erc20.mint(user2, toWad(20));
        assert.equal(fromWad(await erc20.balanceOf(user1)), 10);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 20);

        await shouldThrows(erc20.transfer("0x0000000000000000000000000000000000000000", toWad(1.5)), "transfer to the zero address");

        await erc20.transfer(user2, toWad(1.5), { from: user1 });
        assert.equal(fromWad(await erc20.balanceOf(user1)), 8.5);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 21.5);

        await erc20.transfer(user2, toWad(8.5), { from: user1 });
        assert.equal(fromWad(await erc20.balanceOf(user1)), 0);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 30);

        await shouldThrows(erc20.transfer(user2, 1, { from: user1 }), "insufficient fund to transfer");
    });

    it("transferFrom", async () => {
        await erc20.mint(user1, toWad(10));
        await erc20.mint(user2, toWad(20));
        assert.equal(fromWad(await erc20.balanceOf(user1)), 10);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 20);

        await shouldThrows(erc20.transferFrom(user1, user2, 1), "transfer amount exceeds allowance");
        await erc20.approve(admin, toWad(30), { from: user1});

        await shouldThrows(erc20.transferFrom("0x0000000000000000000000000000000000000000", user2, toWad(1.5)), "transfer from the zero address");
        await shouldThrows(erc20.transferFrom(user1, "0x0000000000000000000000000000000000000000", toWad(1.5)), "transfer to the zero address");

        await erc20.transferFrom(user1, user2, toWad(1.5));
        assert.equal(fromWad(await erc20.balanceOf(user1)), 8.5);
        assert.equal(fromWad(await erc20.allowance(user1, admin)), 28.5);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 21.5);

        await erc20.transferFrom(user1, user2, toWad(8.5));
        assert.equal(fromWad(await erc20.balanceOf(user1)), 0);
        assert.equal(fromWad(await erc20.allowance(user1, admin)), 20);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 30);

        await shouldThrows(erc20.transferFrom(user1, user2, 1), "insufficient fund to transfer");
    })

    it("approve", async () => {
        await shouldThrows(erc20.approve("0x0000000000000000000000000000000000000000", toWad(1.5)), "approve to the zero address");

        await erc20.approve(user2, toWad(30), { from: user1});
        assert.equal(fromWad(await erc20.allowance(user1, user2)), 30);

        await erc20.approve(user2, toWad(0), { from: user1});
        assert.equal(fromWad(await erc20.allowance(user1, user2)), 0);

        await erc20.increaseAllowance(user2, toWad(0.05), { from: user1});
        assert.equal(fromWad(await erc20.allowance(user1, user2)), 0.05);

        await erc20.decreaseAllowance(user2, toWad(0.01), { from: user1});
        assert.equal(fromWad(await erc20.allowance(user1, user2)), 0.04);

        await shouldThrows(erc20.decreaseAllowance(user2, toWad(0.05), { from: user1}), "decreased allowance below zero");
    })

    it("transferrable", async () => {
        await erc20.mint(user1, toWad(10));
        await erc20.mint(user2, toWad(20));
        assert.equal(fromWad(await erc20.balanceOf(user1)), 10);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 20);

        await erc20.setRedeemingBalances(user1, toWad(10));
        await shouldThrows(erc20.transfer(user2, toWad(1.5), { from: user1 }), "insufficient fund to transfer");
        assert.equal(fromWad(await erc20.balanceOf(user1)), 10);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 20);

        await erc20.setRedeemingBalances(user1, toWad(8.5));
        await erc20.transfer(user2, toWad(1.5), { from: user1 });
        assert.equal(fromWad(await erc20.balanceOf(user1)), 8.5);
        assert.equal(fromWad(await erc20.balanceOf(user2)), 21.5);

        await shouldThrows(erc20.transfer(user2, 1, { from: user1 }), "insufficient fund to transfer");
    });
});