const TestPriceFeeder = artifacts.require("TestPriceFeeder.sol");
const PeriodicPriceBucket = artifacts.require("PeriodicPriceBucket.sol");

module.exports = async function(deployer) {

  await deployer.deploy(TestPriceFeeder);
  await deployer.deploy(PeriodicPriceBucket);
  const bucket = await PeriodicPriceBucket.deployed();
  await bucket.initialize(TestPriceFeeder.address);
  await bucket.addBucket(432);
};
