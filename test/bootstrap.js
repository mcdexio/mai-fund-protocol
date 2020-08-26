const { toBytes32, fromBytes32, uintToBytes32, toWad, fromWad } = require("./utils.js");
const { buildOrder } = require("./order.js");
const { getPerpetualComponents } = require("./perpetual.js");
const IGlobalConfig = artifacts.require('IGlobalConfig.sol');

const encodeInitializData  = (
    name,
    symbol,
    collateral,
    colleteralDecimals,
    perpetual,
    maintainer
) => {
    const parameters = web3.eth.abi.encodeParameters(
        [
            "string",
            "string",
            "address",
            "uint8",
            "address",
            "address"
        ],
        [
            name,
            symbol,
            collateral,
            colleteralDecimals,
            perpetual,
            maintainer
        ]
    );
    return "0xf75e987a" + parameters.slice(2)
}

const setConfigurationEntry = async (target, entry, value) => {
    await target.setParameter(toBytes32(entry), uintToBytes32(value));
}

const createTradingContext = (perpetual, exchange, fundProxy, broker) => {
    const delegateTrade = async (taker, maker, side, price, amount) => {
        const takerParam = await buildOrder({
            trader: fundProxy? fundProxy.address: taker,
            amount: amount,
            price: price,
            version: 2,
            side: side,
            type: 'limit',
            expiredAtSeconds: 86400,
            salt: 666,
            inversed: true,
        }, perpetual.address, broker, taker);

        const makerParam = await buildOrder({
            trader: maker,
            amount: amount,
            price: price,
            version: 2,
            side: side == 'buy'? 'sell': 'buy',
            type: 'limit',
            expiredAtSeconds: 86400,
            salt: 666,
            inversed: true,
        }, perpetual.address, broker);
        await exchange.matchOrders(takerParam, [makerParam], perpetual.address, [amount]);
    }
    return delegateTrade;
}

module.exports = {
    encodeInitializData,
    setConfigurationEntry,
    createTradingContext,
};


// contract('bootstrap', accounts => {

//     const admin = accounts[0];
//     const u1 = accounts[1];
//     const u2 = accounts[2];
//     const u3 = accounts[3];

//     it ("deploy", async () => {
//         // initial
//         const {
//             perpetual,
//             amm,
//             global,
//             feeder,
//             exchange,
//         } = await getPerpetualComponents(
//             "0x92733bf875740980BFe5C61C8166e4384127E7f7",
//             "0xB1607d262FA78539b7281bc56c4F90E6ac1cb1d5"
//         );

//         await feeder.setPrice("20000000000");
//         await amm.updateIndex();
//         if (!(await global.brokers(admin))) {
//             await global.addBroker(admin);
//         }
//         // factory
//         const factory = await FundFactory.new(global.address);
//         const implementation = await FundBase.new();
//         const initializeData = encodeInitializData(
//             "Fund Share Token",
//             "FST",
//             "0x0000000000000000000000000000000000000000",
//             18,
//             perpetual.address,
//             admin
//         );
//         await factory.setImplementation(implementation.address);
//         // console.log(initializeData);
//         // deploy
//         const tx = await factory.createFundProxy(initializeData);
//         console.log("     proxy gas consmued:", tx.receipt.gasUsed);

//         const n = await factory.numProxies();
//         const proxy = await factory.getProxies(n - 1);
//         const instance = await FundBase.at(proxy);

//         console.log("   -", await instance.name());
//         console.log("   -", await instance.symbol());
//         console.log("   -", await instance.decimals());

//         await instance.create(toWad(1), toWad(200), { value: toWad(200) });

//         assert.equal(fromWad(await perpetual.marginBalance.call(instance.address)), 200);
//         assert.equal(fromWad(await instance.balanceOf(admin)), 1);
//         // console.log((await instance.lastPurchaseTime(admin)).toString());

//         // user 1 buy 2 share
//         await instance.purchase(toWad(2), toWad(200), { from: u1, value: toWad(400) });
//         assert.equal(fromWad(await perpetual.marginBalance.call(instance.address)), 600);
//         assert.equal(fromWad(await instance.balanceOf(u1)), 2);
//         // console.log((await instance.lastPurchaseTime(u1)).toString());

//         // // user 1 redeem 1 share
//         // await instance.requestToRedeem(toWad(1), toWad(0.01), { from: u1 });
//         // assert.equal(fromWad(await perpetual.marginBalance.call(instance.address)), 400);
//         // assert.equal(fromWad(await instance.balanceOf(u1)), 1);
//         // assert.equal(fromWad(await instance.redeemingBalance(u1)), 0);

//         // trading
//         // await factory.setDelegator(proxy, exchange);
//         await instance.setDelegator(exchange.address);
//         const delegateTrade = createTradingContext(perpetual, exchange, instance, admin);

//         await perpetual.deposit(toWad(1000), {from: u1, value: toWad(1000)});
//         console.log(fromWad(await perpetual.marginBalance.call(instance.address)));
//         console.log(fromWad(await perpetual.marginBalance.call(u1)));

//         await delegateTrade(admin, u1, 'buy', toWad(0.005), toWad(1));
//         console.log(await perpetual.getMarginAccount(instance.address));

//         await instance.requestToRedeem(toWad(1), toWad(0.01), { from: u1 });
//         console.log(fromWad(await perpetual.marginBalance.call(instance.address)));
//         console.log(fromWad(await instance.redeemingBalance(u1)));

//         await global.addComponent(perpetual.address, instance.address);
//         await perpetual.deposit(toWad(1000), {from: u2, value: toWad(1000)});
//         await instance.takeRedeemingShare(u1, toWad(1), toWad(1000), 2);

//         console.log(fromWad(await perpetual.marginBalance.call(instance.address)));
//         console.log(fromWad(await instance.redeemingBalance(u1)));
//         console.log(await perpetual.getMarginAccount(instance.address));
//     })
// })