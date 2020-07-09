const IPerpetual = artifacts.require('IPerpetual.sol');
const IPriceFeeder = artifacts.require('IPriceFeeder.sol');
const IChainlinkFeeder = artifacts.require('IChainlinkFeeder.sol');
const IGlobalConfig = artifacts.require('IGlobalConfig.sol');
const IAMM = artifacts.require('IAMM.sol');
const IExchange = artifacts.require('IExchange.sol');

const getPerpetualComponents = async (perpetualInstance, exchangeInstance) => {
    const perpetual = await IPerpetual.at(perpetualInstance);
    const global = await IGlobalConfig.at(await perpetual.globalConfig());
    const amm = await IAMM.at(await perpetual.amm());
    const chainLinkFeeder = await IChainlinkFeeder.at(await amm.priceFeeder());
    const feeder = await IPriceFeeder.at(await chainLinkFeeder.feeder());
    const exchange = await IExchange.at(exchangeInstance);
    return { perpetual, amm, global, feeder, exchange };
}

module.exports = {
    getPerpetualComponents
}

