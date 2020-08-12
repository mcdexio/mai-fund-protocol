const BigNumber = require("bignumber.js");
const truffleContract = require('truffle-contract');
const { toWad, fromWad, infinity, Side, toBytes32 } = require('./utils');

const TestToken = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/TestToken.json'));
const Exchange = truffleContract(require('./external/Exchange.json'));
const PriceFeeder = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/TestPriceFeeder.json'));
const GlobalConfig = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/GlobalConfig.json'));
const ChainlinkAdapter = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/ChainlinkAdapter.json'));
const Perpetual = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/TestPerpetual.json'));
const AMM = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/TestAMM.json'));
const Proxy = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/Proxy.json'));
const ShareToken = truffleContract(require('@mcdex/mai-protocol-v2-build/build/contracts/ShareToken.json'));

class PerpetualDeployer {
    constructor(accounts, inversed) {
        this.accounts = accounts;
        this.inversed = inversed;

        var broker = accounts[9];
        var admin = accounts[0];
        var dev =  accounts[1];

        var provider = web3.currentProvider;
        var defaultOption = { from: admin }

        TestToken.setProvider(provider);
        PriceFeeder.setProvider(provider);
        GlobalConfig.setProvider(provider);
        Perpetual.setProvider(provider);
        AMM.setProvider(provider);
        Proxy.setProvider(provider);
        ShareToken.setProvider(provider);
        Exchange.setProvider(provider);
        ChainlinkAdapter.setProvider(provider);

        TestToken.defaults(defaultOption);
        PriceFeeder.defaults(defaultOption);
        GlobalConfig.defaults(defaultOption);
        Perpetual.defaults(defaultOption);
        AMM.defaults(defaultOption);
        Proxy.defaults(defaultOption);
        ShareToken.defaults(defaultOption);
        Exchange.defaults(defaultOption);
        ChainlinkAdapter.defaults(defaultOption);

        this.broker = broker;
        this.admin = admin;
        this.dev =  dev;

        this.globalConfig = null;
        this.collateral = null;
        this.priceFeeder = null;
        this.exchange = null;
        this.chainlinkAdapter = null;
        this.share = null;
        this.perpetual = null;
        this.proxy = null;
        this.amm = null;
    }

    async deploy() {
        var collateral;
        if (this.inversed) {
            collateral = { address: "0x0000000000000000000000000000000000000000" }
        } else {
            collateral = await TestToken.new("TT", "TestToken", 18);
        }
        var globalConfig = await GlobalConfig.new();
        var exchange = await Exchange.new(globalConfig.address);
        var priceFeeder = await PriceFeeder.new();
        var chainlinkAdapter = await ChainlinkAdapter.new(priceFeeder.address, 3600 * 6, this.inversed);
        var share = await ShareToken.new("ST", "STK", 18);
        var perpetual = await Perpetual.new(globalConfig.address, this.dev, collateral.address, 18);
        var proxy = await Proxy.new(perpetual.address);
        var amm = await AMM.new(globalConfig.address, proxy.address, chainlinkAdapter.address, share.address);

        await share.addMinter(amm.address);
        await share.renounceMinter();
        await perpetual.setGovernanceAddress(toBytes32("amm"), amm.address);
        await globalConfig.addComponent(perpetual.address, proxy.address);
        await globalConfig.addComponent(perpetual.address, exchange.address);
        await globalConfig.addComponent(amm.address, exchange.address);
        await globalConfig.addBroker(this.admin);

        this.globalConfig = globalConfig;
        this.priceFeeder = priceFeeder;
        this.exchange = exchange;
        this.perpetual = perpetual;
        this.proxy = proxy;
        this.amm = amm;

        this.collateral = collateral;
        this.share = share;
    }

    async initialize() {
        await this.perpetual.setGovernanceParameter(toBytes32("initialMarginRate"), toWad(0.10)); // 10%, should < 1
        await this.perpetual.setGovernanceParameter(toBytes32("maintenanceMarginRate"), toWad(0.075)); // 7.5%, should < initialMarginRate
        await this.perpetual.setGovernanceParameter(toBytes32("liquidationPenaltyRate"), toWad(0.005)); // 0.5%, should < maintenanceMarginRate
        await this.perpetual.setGovernanceParameter(toBytes32("penaltyFundRate"), toWad(0.005)); // 0.5%, should < maintenanceMarginRate
        await this.perpetual.setGovernanceParameter(toBytes32("takerDevFeeRate"), toWad(0)); // 0.075%
        await this.perpetual.setGovernanceParameter(toBytes32("makerDevFeeRate"), toWad(0)); // -0.025%

        await this.perpetual.setGovernanceParameter(toBytes32("tradingLotSize"), 1);
        await this.perpetual.setGovernanceParameter(toBytes32("lotSize"), 1);

        await this.amm.setGovernanceParameter(toBytes32("poolFeeRate"), toWad(0)); // 0.075% * 80%
        await this.amm.setGovernanceParameter(toBytes32("poolDevFeeRate"), toWad(0)); // 0.075% * 20%
        await this.amm.setGovernanceParameter(toBytes32("emaAlpha"), "3327787021630616"); // 2 / (600 + 1)
        await this.amm.setGovernanceParameter(toBytes32("updatePremiumPrize"), toWad(0));
        await this.amm.setGovernanceParameter(toBytes32("markPremiumLimit"), toWad(300000001));
        await this.amm.setGovernanceParameter(toBytes32("fundingDampener"), toWad(300000000));
    }

    async setIndex(dollarPrice) {
        const price = (new BigNumber(dollarPrice)).shiftedBy(8).dp(0, BigNumber.ROUND_DOWN);
        await this.priceFeeder.setPrice(price);

        const index = await this.amm.indexPrice();
        await this.amm.setBlockTimestamp(index.timestamp);
    }

    async createPool() {
        if (this.inversed) {
            const initialAmount = toWad(100 * 0.1 * 2 * 1.5);
            await this.perpetual.deposit(initialAmount, { value: initialAmount, gas: 1000000 });
        } else {
            const initialAmount = toWad(200 * 100 * 0.1 * 1.5);
            await this.collateral.approve(this.perpetual.address, infinity);
            await this.perpetual.deposit(initialAmount, { gas: 1000000 });
        }
        await this.amm.createPool(toWad(1), { gas: 800000 });
    }
}

module.exports = {
    PerpetualDeployer
}