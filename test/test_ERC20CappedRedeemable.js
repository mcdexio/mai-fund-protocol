const assert = require("assert");
const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows } = require("./utils.js");

const TestERC20CappedRedeemable = artifacts.require('TestERC20CappedRedeemable.sol');

contract('TestERC20CappedRedeemable', accounts => {
    var user;
    var redeemable;

    const deploy = async () => {
        user = accounts[1];
        redeemable = await TestERC20CappedRedeemable.new("Redeemable Token", "RTK", toWad(1000));
    }

    function sleep(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    beforeEach(deploy);

    it("cap", async () => {
        await redeemable.mint(user, toWad(1000));
        await shouldThrows(redeemable.mint(user, 1), "cap exceeded");

        await redeemable.setCap(toWad(2000));
        await redeemable.mint(user, toWad(1000));
        await shouldThrows(redeemable.mint(user, 1), "cap exceeded");

        await redeemable.setCap(toWad(0));
        await shouldThrows(redeemable.mint(user, 1), "cap exceeded");

        await redeemable.setCap(toWad(1000));
        await redeemable.burn(user, toWad(1500));
        await redeemable.mint(user, toWad(500));
        await shouldThrows(redeemable.mint(user, 1), "cap exceeded");

        await shouldThrows(redeemable.setCap(toWad(1000)), "same cap");
    });

    it("can / cannot redeem", async () => {
        await redeemable.setRedeemingLockPeriod(0);
        await redeemable.mint(user, toWad(1));
        assert.ok(await redeemable.canRedeem(user));
        assert.equal(fromWad(await redeemable.redeemableShareBalance(user)), 1);

        await redeemable.setRedeemingLockPeriod(5);
        await redeemable.mint(user, toWad(1));
        assert.ok(!(await redeemable.canRedeem(user)));
        assert.equal(fromWad(await redeemable.redeemableShareBalance(user)), 0);

        await sleep(6000);
        await redeemable.doNothing();   // make testnode mine
        assert.ok(await redeemable.canRedeem(user));
        assert.equal(fromWad(await redeemable.redeemableShareBalance(user)), 2);

        await redeemable.mint(user, toWad(1));
        assert.ok(!(await redeemable.canRedeem(user)));
        await sleep(2000);
        await redeemable.mint(user, toWad(1));
        await sleep(4000);
        await redeemable.doNothing();   // make testnode mine
        assert.ok(!(await redeemable.canRedeem(user)));
        await sleep(2000);
        await redeemable.doNothing();   // make testnode mine
        assert.ok(await redeemable.canRedeem(user));
        assert.equal(fromWad(await redeemable.redeemableShareBalance(user)), 4);
    });

    it("increase / decrease redeeming share balance", async () => {
        assert.equal(await redeemable.redeemingBalance(user), 0);

        await redeemable.mint(user, toWad(10));

        await redeemable.increaseRedeemingShareBalance(user, toWad(1.1));
        assert.equal(await redeemable.redeemingBalance(user), toWad(1.1));
        await redeemable.setRedeemingSlippage(user, toWad(0.01));
        assert.equal(await redeemable.redeemingSlippage(user), toWad(0.01));

        await redeemable.increaseRedeemingShareBalance(user, toWad(1.21));
        assert.equal(await redeemable.redeemingBalance(user), toWad(2.31));
        await redeemable.setRedeemingSlippage(user, toWad(0.02));
        assert.equal(await redeemable.redeemingSlippage(user), toWad(0.02));

        await redeemable.decreaseRedeemingShareBalance(user, toWad(1.11));
        assert.equal(await redeemable.redeemingBalance(user), toWad(1.2));

        await shouldThrows(redeemable.decreaseRedeemingShareBalance(user, toWad(1.21)), "amount exceeded");

        await redeemable.decreaseRedeemingShareBalance(user, toWad(1.2));
        assert.equal(await redeemable.redeemingBalance(user), toWad(0));

        await shouldThrows(redeemable.increaseRedeemingShareBalance(user, toWad(10.01)), "amount exceeded");
    });

    it("mint / burn share balance", async () => {
        await redeemable.mint(user, toWad(10));
        assert.equal(await redeemable.balanceOf(user), toWad(10));
        assert.equal(await redeemable.totalSupply(), toWad(10));
        var purchaseTime = (await redeemable.lastPurchaseTime(user)).toString();
        assert.ok(purchaseTime > 0);

        await redeemable.mint(user, toWad(10));
        assert.equal(await redeemable.balanceOf(user), toWad(20));
        assert.equal(await redeemable.totalSupply(), toWad(20));
        assert.ok((await redeemable.lastPurchaseTime(user)).toString() >= purchaseTime);
    });
});
