//migrations/3_deploy_raffle.js
const RaffleDraw = artifacts.require("RaffleDraw");

module.exports = function(deployer) {
  deployer.deploy(RaffleDraw)
    .then(() => {
      console.log("RaffleDraw contract deployed at:", RaffleDraw.address);
    });
};