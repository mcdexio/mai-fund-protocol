const BigNumber = require('bignumber.js');
const web3 = require('web3');
const { toWei, fromWei, toWad, fromWad, infinity, Side, toBytes32 } = require('../test/utils');
const AutoTradingFund = artifacts.require('AutoTradingFund');

const settle = async () => {
    const fund = await AutoTradingFund.at("0xA8cD84eE8aD8eC1c7ee19E578F2825cDe18e56d1");
    await fund.rebalance(toWad(1000), toWad(100), 1);
}

const setParameter = async () => {
    const fund = await AutoTradingFund.at("0xA8cD84eE8aD8eC1c7ee19E578F2825cDe18e56d1");
    await fund.setParameter(web3.utils.fromAscii("rebalanceTolerance"), toWad(0.1));
}

module.exports = (callback) => {
    setParameter().then(() => callback()).catch(err => callback(err));
};