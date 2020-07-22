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

    beforeEach(deploy);

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

        await shouldThrows(accountOPs.increaseShareBalancePublic(user, 0), "share amount must be greater than 0");
        await shouldThrows(accountOPs.decreaseShareBalancePublic(user, 0), "share amount must be greater than 0");
    });

    it("increase / decrease redeeming share balance", async () => {
        assert.equal(await accountOPs.redeemingBalance(user), 0);

        await accountOPs.increaseShareBalancePublic(user, toWad(10));

        await accountOPs.increaseRedeemingAmountPublic(user, toWad(1.1), toWad(0.01));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(1.1));
        assert.equal(await accountOPs.redeemingSlippage(user), toWad(0.01));

        await accountOPs.increaseRedeemingAmountPublic(user, toWad(1.21), toWad(0.02));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(2.31));
        assert.equal(await accountOPs.redeemingSlippage(user), toWad(0.02));

        await accountOPs.decreaseRedeemingAmountPublic(user, toWad(1.11));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(1.2));

        await shouldThrows(accountOPs.decreaseRedeemingAmountPublic(user, toWad(1.21)), "insufficient redeeming share balance");

        await accountOPs.decreaseRedeemingAmountPublic(user, toWad(1.2));
        assert.equal(await accountOPs.redeemingBalance(user), toWad(0));

        await shouldThrows(accountOPs.increaseRedeemingAmountPublic(user, toWad(10.01), toWad(0.02)), "no enough share to redeem");

        await shouldThrows(accountOPs.increaseRedeemingAmountPublic(user, 0, toWad(0.02)), "share amount must be greater than 0");
        await shouldThrows(accountOPs.decreaseRedeemingAmountPublic(user, 0), "share amount must be greater than 0");
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
        assert.ok((await accountOPs.lastPurchaseTime(user)).toString() > purchaseTime);
    });
});
