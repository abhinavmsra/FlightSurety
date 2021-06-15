const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {
    // Deploy A, then deploy B, passing in A's newly deployed address
  deployer.deploy(FlightSuretyData).then(() => {
    return deployer.deploy(FlightSuretyApp, FlightSuretyData.address, "Crypto Airlines");
  });
}