const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const Web3 = require('web3');
const fs = require('fs');

const airlineNames = [
  'Bitcoin Airlines',
  'Ethereum Airlines',
  'Tether Airlines',
  'Binance Airlines',
  'Cardano Airlines'
];

module.exports = async function(deployer, _, accounts) {
  await deployer.deploy(FlightSuretyData);
  await deployer.deploy(FlightSuretyApp, FlightSuretyData.address, "Crypto Airlines");
  const appContract = await FlightSuretyApp.deployed();

  // Bootstraps Airlines
  airlineNames.slice(0, 3).forEach(async (airlineName, index) => {
    await appContract.registerAirline(accounts[index + 1], airlineName, { from: accounts[index] });
  });

  await appContract.registerAirline(accounts[4], airlineNames[3], { from: accounts[1] });
  await appContract.registerAirline(accounts[4], airlineNames[3], { from: accounts[2] });

  await appContract.registerAirline(accounts[5], airlineNames[4], { from: accounts[1] });
  await appContract.registerAirline(accounts[5], airlineNames[4], { from: accounts[2] });
  await appContract.registerAirline(accounts[5], airlineNames[4], { from: accounts[3] });

  // Fund accounts
  const amount = web3.utils.toWei("10");
  await appContract.sendTransaction({ from: accounts[1], value: amount });
  await appContract.sendTransaction({ from: accounts[2], value: amount });
  await appContract.sendTransaction({ from: accounts[3], value: amount });
  await appContract.sendTransaction({ from: accounts[4], value: amount });
  await appContract.sendTransaction({ from: accounts[5], value: amount });

  // Register Flights
  let flights = [];
  for(let i = 0; i < 5; i++) {
    const timestamp = getRandomHourTimestamps();
    flights.push([timestamp, accounts[i+1]]);

    await appContract.registerFlight(timestamp, { from: accounts[i+1] });
  }

  let config = {
    localhost: {
        url: 'http://localhost:7545',
        dataAddress: FlightSuretyData.address,
        appAddress: FlightSuretyApp.address,
        flights: flights
    }
  };

  fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');

  // Register Oracles
  config.localhost.oracles = {};

  await Promise.all(
    accounts.map(async account => {
      await appContract.registerOracle({ from: account, value: web3.utils.toWei("1") });

      config.localhost.oracles[account] = (await appContract.getMyIndexes({ from: account })).map(index => {
        return parseInt(index);
      });
    })
  );
  
  fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
}

function getRandomHourTimestamps() {
  const currentTimestamp = parseInt(+new Date() / 1000);
  const max = 10; // 10 hours from now
  const min = 1; // 1 hour from now
  const rand = parseInt(Math.random() * (max - min) + min);

  return(currentTimestamp + (rand * 3600));
}
