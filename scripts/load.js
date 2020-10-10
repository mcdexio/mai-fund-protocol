const BigNumber = require('bignumber.js');
const web3 = require('web3');
const { toWei, fromWei, toWad, fromWad, infinity, Side, toBytes32 } = require('../test/utils');
const TestPriceFeeder = artifacts.require('TestPriceFeeder');
const PeriodicPriceBucket = artifacts.require('PeriodicPriceBucket');
const RSITrendingStrategy = artifacts.require('RSITrendingStrategy');

// s10
// TestPriceFeeder       0xC6d9D645C39D006647b69088254225773Da63f6c
// PeriodicPriceBucket   0xDAaEFF0372b806a5c1e8E262196d490Ccef77200
// RSITrendingStrategy   0x3e1932d4B025D592B5158f0812F1601CEd1eb042

// bad
// TestPriceFeeder       0xe415B969EEEB991D40431303A1ea199978816F53
// PeriodicPriceBucket   0x361041b793679fe5E66eEb2F759c03206E11fd6D
// RSITrendingStrategy   0x81f69A2c5db95EDBe32C28Ff1799A56833036B3C

// 1
// TestPriceFeeder       0x06cD8456886ab23aA94f29B4dB5699dc9bfed6b6
// PeriodicPriceBucket   0x37452E6514aCc32182B978Aa2f8DE02b26c28adD
// RSITrendingStrategy   0xe61Dc1a443AC7f8f1aa56afa1197d6E822d254AD

const set = async () => {
    const bucket = await PeriodicPriceBucket.at("0x2b0C0835ccbE5E89BCc46AC9d477b3cE494F3037");
    const strategy = await RSITrendingStrategy.at("0x7E2aAca3F01cbAD595A07bcBc38ed50077007816");

    console.log("buckets ...")
    const spans = await bucket.buckets()
    for (let i = 0; i < spans.length; i++) {
        console.log(spans[i].toString());
    }

    console.log("time series ...")
    // const series = await bucket.retrievePriceSeries(432, now - 432 * 14, now)
    // var series = await bucket.retrievePriceSeries(432, 1601546205, 1601546205 + 432*14)
    // for (let i = 0; i < series.length; i++) {
    //     console.log(series[i].toString());
    // }

    console.log("====")
    const now = Math.floor(Date.now() / 1000);
    var series = await bucket.retrievePriceSeries(30, 1602297560, now)
    for (let i = 0; i < series.length; i++) {
        console.log(series[i].toString());
    }

    console.log("rsi ...")
    console.log((await strategy.getCurrentRSI()).toString());

}

module.exports = (callback) => {
    set().then(() => callback()).catch(err => callback(err));
};