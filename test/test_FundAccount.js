const assert = require("assert");
const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows } = require("./utils.js");

const TestFundAccount = artifacts.require('TestFundAccount.sol');

contract('TestFundAccount', accounts => {
    var user;
    var accountOPs;

    const deploy = async () => {
        user = accounts[1];
        accountOPs = await TestFundAccount.new();
    }

    function sleep(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    beforeEach(deploy);

    it("can / cannot redeem", async () => {
        await accountOPs.setRedeemingLockPeriodPublic(0);
        await accountOPs.mintShareBalancePublic(user, toWad(1));
        assert.ok(await accountOPs.canRedeemPublic(user));
        assert.equal(fromWad(await accountOPs.redeemableShareBalancePublic(user)), 1);

        await accountOPs.setRedeemingLockPeriodPublic(5);
        await accountOPs.mintShareBalancePublic(user, toWad(1));
        assert.ok(!(await accountOPs.canRedeemPublic(user)));
        assert.equal(fromWad(await accountOPs.redeemableShareBalancePublic(user)), 0);

        await sleep(6000);
        await accountOPs.doNothing();   // make testnode mine
        assert.ok(await accountOPs.canRedeemPublic(user));
        assert.equal(fromWad(await accountOPs.redeemableShareBalancePublic(user)), 2);

        await accountOPs.mintShareBalancePublic(user, toWad(1));
        assert.ok(!(await accountOPs.canRedeemPublic(user)));
        await sleep(2000);
        await accountOPs.mintShareBalancePublic(user, toWad(1));
        await sleep(4000);
        await accountOPs.doNothing();   // make testnode mine
        assert.ok(!(await accountOPs.canRedeemPublic(user)));
        await sleep(2000);
        await accountOPs.doNothing();   // make testnode mine
        assert.ok(await accountOPs.canRedeemPublic(user));
        assert.equal(fromWad(await accountOPs.redeemableShareBalancePublic(user)), 4);
    });


    it("increase / decrease share balance", async () => {
        assert.equal(await accountOPs.balance(user), 0);

        await accountOPs.increaseShareBalancePublic(user, toWad(1.1));
        assert.equal(await accountOPs.balance(user), toWad(1.1));

        await accountOPs.increaseShareBalancePublic(user, toWad(1.21));
        assert.equal(await accountOPs.balance(user), toWad(2.31));

        await accountOPs.decreaseShareBalancePublic(user, toWad(1.11));
        assert.equal(await accountOPs.balance(user), toWad(1.2));

        await shouldThrows(accountOPs.decreaseShareBalancePublic(user, toWad(1.21)), "insufficient share balance");

        await accountOPs.decreaseShareBalancePublic(user, toWad(1.2));
        assert.equal(await accountOPs.balance(user), toWad(0));
    });

    it("increase / decrease redeeming share balance", async () => {
        assert.equal(await accountOPs.redeemingBalance(user), 0);

        await accountOPs.increaseShareBalancePublic(user, toWad(10));

        await accountOPs.increaseRedeemingShareBalancePublic(user, toWad(1.1));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(1.1));
        await accountOPs.setRedeemingSlippagePublic(user, toWad(0.01));
        assert.equal(await accountOPs.redeemingSlippage(user), toWad(0.01));

        await accountOPs.increaseRedeemingShareBalancePublic(user, toWad(1.21));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(2.31));
        await accountOPs.setRedeemingSlippagePublic(user, toWad(0.02));
        assert.equal(await accountOPs.redeemingSlippage(user), toWad(0.02));

        await accountOPs.decreaseRedeemingShareBalancePublic(user, toWad(1.11));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(1.2));

        await shouldThrows(accountOPs.decreaseRedeemingShareBalancePublic(user, toWad(1.21)), "insufficient redeeming share balance");

        await accountOPs.decreaseRedeemingShareBalancePublic(user, toWad(1.2));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(0));

        await shouldThrows(accountOPs.increaseRedeemingShareBalancePublic(user, toWad(10.01)), "no enough share to redeem");
    });


    it("mint / burn share balance", async () => {
        await accountOPs.mintShareBalancePublic(user, toWad(10));
        assert.equal(await accountOPs.balance(user), toWad(10));
        assert.equal(await accountOPs.totalSupply(), toWad(10));
        var purchaseTime = (await accountOPs.lastPurchaseTime(user)).toString();
        assert.ok(purchaseTime > 0);

        await accountOPs.mintShareBalancePublic(user, toWad(10));
        assert.equal(await accountOPs.balance(user), toWad(20));
        assert.equal(await accountOPs.totalSupply(), toWad(20));
        assert.ok((await accountOPs.lastPurchaseTime(user)).toString() >= purchaseTime);
    });
});
