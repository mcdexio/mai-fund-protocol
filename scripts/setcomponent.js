const BigNumber = require('bignumber.js');
const web3 = require('web3');
const { toWei, fromWei, toWad, fromWad, infinity, Side, toBytes32 } = require('../test/utils');

const IGlobalConfig = artifacts.require('IGlobalConfig');

const set = async () => {
    const globalConfig = await IGlobalConfig.at("0x1953049d255840fafc2bf7f865a95a95ea91236f");
    await globalConfig.addComponent("0x4ea47ffe24a8e2435e6a72ab451276224ca6cebb", "0x38B50BD3298975507d3093C100CfAd4e324DFED5");
    console.log("added");
}

module.exports = (callback) => {
    set().then(() => callback()).catch(err => callback(err));
};