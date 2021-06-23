const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const Web3 = require('web3');
const fs = require('fs');

const airlineNames = [
  'Crypto Airlines',
  'Bitcoin Airlines',
  'Ethereum Airlines',
  'Tether Airlines',
  'Binance Airlines',
  'Cardano Airlines'
];

module.exports = async function(deployer, _, accounts) {
  await deployer.deploy(FlightSuretyData, { from: accounts[0] });
  await deployer.deploy(FlightSuretyApp, FlightSuretyData.address, { from: accounts[0] });

  const appContract = await FlightSuretyApp.deployed();
  const dataContract = await FlightSuretyData.deployed();
  const fundingAmount = web3.utils.toWei("10");

  await dataContract.setAppContract(FlightSuretyApp.address, { from: accounts[0] });
  await dataContract.setOperatingStatus(true, { from: accounts[0] });

  await appContract.registerAirline(accounts[0], airlineNames[0], { from: accounts[0] });
  await appContract.sendTransaction({ from: accounts[0], value: fundingAmount });

  await appContract.registerAirline(accounts[1], airlineNames[1], { from: accounts[0] });
  await appContract.sendTransaction({ from: accounts[1], value: fundingAmount });

  await appContract.registerAirline(accounts[2], airlineNames[2], { from: accounts[1] });
  await appContract.sendTransaction({ from: accounts[2], value: fundingAmount });

  await appContract.registerAirline(accounts[3], airlineNames[3], { from: accounts[2] });
  await appContract.sendTransaction({ from: accounts[3], value: fundingAmount });

  await appContract.registerAirline(accounts[4], airlineNames[4], { from: accounts[1] });
  await appContract.registerAirline(accounts[4], airlineNames[4], { from: accounts[2] });
  await appContract.sendTransaction({ from: accounts[4], value: fundingAmount });

  await appContract.registerAirline(accounts[5], airlineNames[5], { from: accounts[1] });
  await appContract.registerAirline(accounts[5], airlineNames[5], { from: accounts[2] });
  await appContract.registerAirline(accounts[5], airlineNames[5], { from: accounts[3] });
  await appContract.sendTransaction({ from: accounts[5], value: fundingAmount });

  // // Register Flights
  let flights = [];
  for(let i = 0; i < 5; i++) {
    const timestamp = getRandomHourTimestamps();
    const name = `FL-${i}`;
    flights.push({name, timestamp, airlineName: airlineNames[i], airline: accounts[i+1]});

    await appContract.registerFlight(name, timestamp, { from: accounts[i+1] });
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

  // // Register Oracles
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
