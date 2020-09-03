const assert = require("assert");
const BN = require('bn.js');
const BigNumber = require('bignumber.js');
const { encodeInitializData, setConfigurationEntry, createTradingContext } = require("./bootstrap.js");
const { PerpetualDeployer } = require("./perpetual.js");
const {
    toBytes32, fromBytes32, uintToBytes32, toWad, fromWad, shouldThrows,
    createEVMSnapshot, restoreEVMSnapshot, infinity
} = require("./utils.js");

const TestCollateral = artifacts.require('TestCollateral.sol');
const ERC20WithoutDecimals = artifacts.require('ERC20WithoutDecimals.sol');
const ERC20WithDecimals = artifacts.require('ERC20WithDecimals.sol');
const LibUtil = artifacts.require('LibUtil.sol');

contract('TestCollateral', accounts => {

    const SHORT = 1;
    const LONG = 2;

    var user1;
    var user2;
    var user3;
    var admin;

    var perpetual;
    var collateral;
    var rsistg;
    var debug;

    const deploy = async () => {
        admin = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        var libUtil = await LibUtil.new();
        await TestCollateral.link("LibUtil", libUtil.address);

        var token = await ERC20WithDecimals.new("Token", "TKN", 18);
        collateral = await TestCollateral.new();
        await collateral.initialize(token.address, 18);
    }

    before(deploy);

    var snapshotId;
    beforeEach(async () => {
        snapshotId = await createEVMSnapshot();
    });

    afterEach(async function () {
        await restoreEVMSnapshot(snapshotId);
    });

    it("retrieveDecimals", async () => {
        // no decimal
        var token = await ERC20WithoutDecimals.new("Token", "TKN");
        var result = await collateral.retrieveDecimals(token.address);
        assert.equal(result[0], 0);
        assert.equal(result[1], false);

        var token = await ERC20WithDecimals.new("Token", "TKN", 8);
        var result = await collateral.retrieveDecimals(token.address);
        assert.equal(result[0], 8);
        assert.equal(result[1], true);

        var token = await ERC20WithDecimals.new("Token", "TKN", 10);
        var result = await collateral.retrieveDecimals(token.address);
        assert.equal(result[0], 10);
        assert.equal(result[1], true);

        var token = await ERC20WithDecimals.new("Token", "TKN", 18);
        var result = await collateral.retrieveDecimals(token.address);
        assert.equal(result[0], 18);
        assert.equal(result[1], true);

        var token = await ERC20WithDecimals.new("Token", "TKN", 27);
        var result = await collateral.retrieveDecimals(token.address);
        assert.equal(result[0], 27);
        assert.equal(result[1], true);
    });

    it("initialize - erc20", async () => {
        var token = await ERC20WithoutDecimals.new("Token", "TKN");
        var collateral = await TestCollateral.new();
        await collateral.initialize(token.address, 18);

        assert.equal(await collateral.collateral(), token.address);
        assert.equal(await collateral.scaler(), "1");
        assert.ok(await collateral.isCollateralERC20());


        var token = await ERC20WithDecimals.new("Token", "TKN", 0);
        var collateral = await TestCollateral.new();
        await collateral.initialize(token.address, 0);

        assert.equal(await collateral.collateral(), token.address);
        assert.equal(await collateral.scaler(), "1000000000000000000");
        assert.ok(await collateral.isCollateralERC20());


        var token = await ERC20WithDecimals.new("Token", "TKN", 8);
        var collateral = await TestCollateral.new();
        await collateral.initialize(token.address, 8);

        assert.equal(await collateral.collateral(), token.address);
        assert.equal(await collateral.scaler(), "10000000000");
        assert.ok(await collateral.isCollateralERC20());


        var token = await ERC20WithDecimals.new("Token", "TKN", 18);
        var collateral = await TestCollateral.new();
        await collateral.initialize(token.address, 18);

        assert.equal(await collateral.collateral(), token.address);
        assert.equal(await collateral.scaler(), "1");
        assert.ok(await collateral.isCollateralERC20());

        var token = await ERC20WithDecimals.new("Token", "TKN", 19);
        var collateral = await TestCollateral.new();
        await shouldThrows(collateral.initialize(token.address, 19), "bad decimals");

        var token = await ERC20WithDecimals.new("Token", "TKN", 18);
        var collateral = await TestCollateral.new();
        await shouldThrows(collateral.initialize(token.address, 17), "bad decimals");

        var token = await ERC20WithDecimals.new("Token", "TKN", 18);
        var collateral = await TestCollateral.new();
        await shouldThrows(collateral.initialize(token.address, 17), "bad decimals");
    });

    it("initialize - ether", async () => {
        var collateral = await TestCollateral.new();
        await collateral.initialize("0x0000000000000000000000000000000000000000", 18);

        assert.equal(await collateral.collateral(), "0x0000000000000000000000000000000000000000");
        assert.equal(await collateral.scaler(), "1");
        assert.ok(!(await collateral.isCollateralERC20()));

        var collateral = await TestCollateral.new();
        await shouldThrows(collateral.initialize("0x0000000000000000000000000000000000000000", 17), "decimals is not 18");
    });

    it("pullFrom / pushTo user - erc20", async () => {

        const _unit = new BigNumber('100000000');
        const toToken = (...xs) => {
            let sum = new BigNumber(0);
            for (var x of xs) {
                sum = sum.plus(new BigNumber(x).times(_unit));
            }
            return sum.toFixed();
        };
        const fromToken = x => {
            return new BigNumber(x).div(_unit).toFixed(18);
        };

        var collateral = await TestCollateral.new();
        var token = await ERC20WithDecimals.new("Token", "TKN", 8);
        await token.mint(user1, toToken(10));
        await collateral.initialize(token.address, 8);
        assert.equal(await token.balanceOf(user1), "1000000000");

        await shouldThrows(collateral.pullFromUser(user1, toToken(1)), "low-level call failed");
        await token.approve(collateral.address, toWad(9999999), { from: user1 });
        await collateral.pullFromUser(user1, toToken(1));
        assert.equal(await token.balanceOf(user1), "900000000");
        assert.equal(await token.balanceOf(collateral.address), "100000000");

        await collateral.pushToUser(user1, toToken(0.01));
        assert.equal(await token.balanceOf(user1), "901000000");
        assert.equal(await token.balanceOf(collateral.address), "99000000");

        await collateral.pushToUser(user1, toToken(0.99));
        assert.equal(await token.balanceOf(user1), "1000000000");
        assert.equal(await token.balanceOf(collateral.address), "0");
    });

    it("pullFrom / pushTo user - ether", async () => {
        var collateral = await TestCollateral.new();
        await collateral.initialize("0x0000000000000000000000000000000000000000", 18);

        await collateral.pullFromUser(user1, toWad(1), { value: toWad(1), from: user1 });
        assert.equal(fromWad(await web3.eth.getBalance(collateral.address)), 1);

        await collateral.pushToUser(user1, toWad(0.01));
        assert.equal(fromWad(await web3.eth.getBalance(collateral.address)), 0.99);

        await collateral.pushToUser(user1, toWad(0.99));
        assert.equal(fromWad(await web3.eth.getBalance(collateral.address)), 0);
    });

    it("convert", async () => {
        var token = await ERC20WithoutDecimals.new("Token", "TKN");
        var collateral = await TestCollateral.new();
        var value = toWad(123);

        await collateral.initialize(token.address, 18);
        assert.equal(await collateral.toRawAmount(value), "123000000000000000000");
        assert.equal(await collateral.toInternalAmount(value), "123000000000000000000");

        var collateral = await TestCollateral.new();
        await collateral.initialize(token.address, 6);
        assert.equal(await collateral.toRawAmount(value), "123000000");
        assert.equal(await collateral.toInternalAmount("123000000"), value);

        var collateral = await TestCollateral.new();
        await collateral.initialize(token.address, 0);
        assert.equal(await collateral.toRawAmount(value), "123");
        assert.equal(await collateral.toInternalAmount("123"), value);
    });

    // it("pullFrom / pushTo perpetual - erc20", async () => {
    //     deployer = await new PerpetualDeployer(accounts, false);
    //     await deployer.deploy();
    //     await deployer.initialize();
    //     await deployer.setIndex(200);
    //     await deployer.createPool();
    //     var token = deployer.collateral;

    //     collateral = await TestCollateral.new();

    //     await collateral.initialize(token.address, 18);
    //     await collateral.approvePerpetual(infinity);

    //     await token.transfer(collateral.address, toWad(1));
    //     await collateral.pushCollateralToPerpetual(toWad(1), { from: user1 });

    //     var marginAccount = await deployer.perpetual.getMarginAccount(collateral.address);
    //     // console.log(marginAccount);
    //     assert.equal(fromWad(await token.balanceOf(collateral.address)), 0);
    //     assert.equal(fromWad(marginAccount.cashBalance), 1);

    //     await collateral.pullCollateralFromPerpetual(toWad(0.05), { from: user1 });
    //     var marginAccount = await deployer.perpetual.getMarginAccount(collateral.address);
    //     // console.log(marginAccount);
    //     assert.equal(fromWad(await token.balanceOf(collateral.address)), 0.05);
    //     assert.equal(fromWad(marginAccount.cashBalance), 0.95);

    //     await collateral.pullCollateralFromPerpetual(toWad(0.95), { from: user1 });
    //     var marginAccount = await deployer.perpetual.getMarginAccount(collateral.address);
    //     // console.log(marginAccount);
    //     assert.equal(fromWad(await token.balanceOf(collateral.address)), 1);
    //     assert.equal(fromWad(marginAccount.cashBalance), 0);
    // });

    // it("pullFrom / pushTo perpetual - ether", async () => {
    //     deployer = await new PerpetualDeployer(accounts, true);
    //     await deployer.deploy();
    //     await deployer.initialize();
    //     await deployer.setIndex(200);
    //     await deployer.createPool();
    //     var token = deployer.collateral;

    //     var collateral = await TestCollateral.new();
    //     await collateral.initialize(token.address, 18);

    //     await collateral.pushCollateralToPerpetual(toWad(1), { from: user1, value: toWad(1) });
    //     var marginAccount = await deployer.perpetual.getMarginAccount(collateral.address);
    //     // console.log(marginAccount);
    //     assert.equal(fromWad(await web3.eth.getBalance(collateral.address)), 0);
    //     assert.equal(fromWad(marginAccount.cashBalance), 1);

    //     await collateral.pullCollateralFromPerpetual(toWad(0.05), { from: user1 });
    //     var marginAccount = await deployer.perpetual.getMarginAccount(collateral.address);
    //     // console.log(marginAccount);
    //     assert.equal(fromWad(await web3.eth.getBalance(collateral.address)), 0.05);
    //     assert.equal(fromWad(marginAccount.cashBalance), 0.95);

    //     await collateral.pullCollateralFromPerpetual(toWad(0.95), { from: user1 });
    //     var marginAccount = await deployer.perpetual.getMarginAccount(collateral.address);
    //     // console.log(marginAccount);
    //     assert.equal(fromWad(await web3.eth.getBalance(collateral.address)), 1);
    //     assert.equal(fromWad(marginAccount.cashBalance), 0);
    // });
});