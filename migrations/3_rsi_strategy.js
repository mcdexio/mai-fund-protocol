const { toWad } = require('../test/utils')
const TestPriceFeeder = artifacts.require("TestPriceFeeder.sol");
const PeriodicPriceBucket = artifacts.require("PeriodicPriceBucket.sol");
const RSITrendingStrategy = artifacts.require("RSITrendingStrategy.sol");

module.exports = async function(deployer) {

  const unit = 10**18;
  await deployer.deploy(RSITrendingStrategy,
    PeriodicPriceBucket.address,
    432,
    13,
    [ toWad(40), toWad(50), toWad(60)],
    [
        { begin: 0, end: 0, target: toWad(-0.3) },
        { begin: 0, end: 1, target: toWad(-0.3) },
        { begin: 0, end: 2, target: toWad(0) },
        { begin: 0, end: 3, target: toWad(0.3) },

        { begin: 1, end: 0, target: toWad(-0.3) },
        { begin: 1, end: 1, target: toWad(0) },
        { begin: 1, end: 2, target: toWad(0) },
        { begin: 1, end: 3, target: toWad(0.3) },

        { begin: 2, end: 0, target: toWad(-0.3) },
        { begin: 2, end: 1, target: toWad(0) },
        { begin: 2, end: 2, target: toWad(0) },
        { begin: 2, end: 3, target: toWad(0.3) },

        { begin: 3, end: 0, target: toWad(-0.3) },
        { begin: 3, end: 1, target: toWad(0) },
        { begin: 3, end: 2, target: toWad(0.3) },
        { begin: 3, end: 3, target: toWad(0.3) },
    ]
  );

  console.log("TestPriceFeeder      ", TestPriceFeeder.address);
  console.log("PeriodicPriceBucket  ", PeriodicPriceBucket.address);
  console.log("RSITrendingStrategy  ", RSITrendingStrategy.address);

};
