// migrations/2_deploy_storedata.js
const StoreData = artifacts.require("BettingEvents");

module.exports = function (deployer) {
  deployer.deploy(StoreData);
};