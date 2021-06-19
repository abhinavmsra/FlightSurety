const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {
    // Deploy A, then deploy B, passing in A's newly deployed address
  deployer.deploy(FlightSuretyData).then(() => {
    return deployer.
      deploy(FlightSuretyApp, FlightSuretyData.address, "Crypto Airlines").
      then(() => {
        const config = {
          localhost: {
              url: 'http://localhost:7545',
              dataAddress: FlightSuretyData.address,
              appAddress: FlightSuretyApp.address
          }
        };

        fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
        fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
      });
  });
}