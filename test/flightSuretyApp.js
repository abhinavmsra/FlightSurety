const { before } = require('lodash');
const { expect, assert } = require('chai');
const Big = require('bignumber.js');
const truffleAssert = require('truffle-assertions');
const FlightSuretyData = artifacts.require("FlightSuretyData")
const FlightSuretyApp = artifacts.require("FlightSuretyApp")

async function createAirline(appContract, airline, name, voter) {
  const fundingAmount = web3.utils.toWei("10");

  await appContract.registerAirline(airline, name, { from: voter });
  await appContract.sendTransaction({ from: airline, value: fundingAmount });
}

async function bootstrapContract(accounts) {
  const dataContractOwner = accounts[0];
  const appContractOwner = accounts[1];

  const dataContract = await FlightSuretyData.new({from: dataContractOwner});
  const appContract = await FlightSuretyApp.new(dataContract.address, { from: appContractOwner });
  await dataContract.setAppContract(appContract.address, { from: accounts[0] });
  await dataContract.setOperatingStatus(true, {from: dataContractOwner});

  await createAirline(appContract, appContractOwner, 'Crypto Airlines', appContractOwner);
  await createAirline(appContract, accounts[2], 'Bitcoin Airlines', accounts[1]);
  await createAirline(appContract, accounts[3], 'Ethereum Airlines', accounts[2]);
  await createAirline(appContract, accounts[4], 'Doge Airlines', accounts[3]);

  return { appContract, dataContract };
}

contract("FlightSuretyApp", accounts => {
  describe('#registerAirline', () => {
    it("registers airlines & grants consent", async () => {
      const { appContract, dataContract } = await bootstrapContract(accounts);

      await Promise.all(
        [
          accounts[1],
          accounts[2],
          accounts[3],
          accounts[4],
        ].map(async airlineOwner => {
          const result = await dataContract.getAirline(airlineOwner);
          assert.equal(result.consensus, true, "must be approved");
          assert.equal(result.activated, true, "must be activated");
        })
      );

      // After first 4 airlines, contract demands voting
      await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[4] });
      let result = await dataContract.getAirline(accounts[5]);
      assert.equal(result.consensus, false, "must not be approved");

      await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[1] });
      result = await dataContract.getAirline(accounts[5]);
      assert.equal(result.voteCount, 2, `expected 2, got ${result.voteCount}`);

      /** 
      *  Testing for consensus when prior count is an even number
      * */
      assert.equal(
        result.consensus, 
        true, 
        `Total Airlines is 4 (except for the current one), hence ${result.voteCount} votes should be enough for consensus`
      );

      /** 
      *  Testing for consensus when prior count is an odd number
      * */
      await appContract.registerAirline(accounts[6], 'Ada Airlines', { from: accounts[1] });
      result = await dataContract.getAirline(accounts[6]);
      assert.equal(
        result.consensus, 
        false, 
        `Total Airlines is 5 (except for the current one), hence ${result.voteCount} votes should not be enough for consensus`
      );

      await appContract.registerAirline(accounts[6], 'Ada Airlines', { from: accounts[2] });
      result = await dataContract.getAirline(accounts[6]);
      assert.equal(
        result.consensus, 
        false, 
        `Total Airlines is 5 (except for the current one), hence ${result.voteCount} votes should not be enough for consensus`
      );

      await appContract.registerAirline(accounts[6], 'Ada Airlines', { from: accounts[3] });
      result = await dataContract.getAirline(accounts[6]);
      assert.equal(
        result.consensus, 
        true, 
        `Total Airlines is 5 (except for the current one), hence ${result.voteCount} votes should be enough for consensus`
      );
    });
  });

  describe('#activate airlines', () => {
    it("validates transaction", async () => {
      const dataContractOwner = accounts[0];
      const appContractOwner = accounts[1];

      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
      const appContract = await FlightSuretyApp.new(dataContract.address, { from: appContractOwner });
      await dataContract.setAppContract(appContract.address, { from: accounts[0] });
      await dataContract.setOperatingStatus(true, {from: dataContractOwner});

      await appContract.registerAirline(appContractOwner, 'Crypto Airlines', { from: appContractOwner });

      await truffleAssert.fails(
        appContract.sendTransaction({ from: appContractOwner, value: web3.utils.toWei("9.9") }),
        truffleAssert.ErrorType.REVERT,
        "Must send at least 10 ether"
      );

      await truffleAssert.passes(
        appContract.sendTransaction({ from: appContractOwner, value: web3.utils.toWei("10.1") }),
        truffleAssert.ErrorType.REVERT
      );
    });
  });

  describe('#registerFlight', () => {
    it('registers flight', async () => {
      const dataContractOwner = accounts[0];
      const appContractOwner = accounts[1];
      const airlineName = 'Crypto Airlines';
      const timestamp = Date.now();
      const flight = 'FL-0';

      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
      const appContract = await FlightSuretyApp.new(dataContract.address, { from: appContractOwner });
      await dataContract.setAppContract(appContract.address, { from: accounts[0] });
      await dataContract.setOperatingStatus(true, {from: dataContractOwner});

      await createAirline(appContract, appContractOwner, airlineName, appContractOwner);

      await appContract.registerFlight(flight, timestamp, { from: appContractOwner });
      const results = await appContract.fetchFlight(appContractOwner, flight, timestamp);

      assert.equal(results.timestamp, timestamp);
      assert.equal(results.statusCode, 0);
      assert.equal(results.airlineName, airlineName);
    });
  });

  describe('#buyInsurance', () => {
    it('buys insurance', async () => {
      const dataContractOwner = accounts[0];
      const appContractOwner = accounts[1];
      const airlineName = 'Crypto Airlines';
      const timestamp = Date.now();
      const flight = 'FL-0';
      const initialBalance = await web3.eth.getBalance(accounts[2]);
      const insuranceAmount = web3.utils.toWei("0.5");

      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
      const appContract = await FlightSuretyApp.new(dataContract.address, { from: appContractOwner });
      await dataContract.setAppContract(appContract.address, { from: accounts[0] });
      await dataContract.setOperatingStatus(true, {from: dataContractOwner});

      await createAirline(appContract, appContractOwner, airlineName, appContractOwner);

      await appContract.registerFlight(flight, timestamp, { from: appContractOwner });
      await appContract.buyInsurance(
        appContractOwner, 
        flight, 
        timestamp,
        { from: accounts[2], value: insuranceAmount }
      );

      const newBalance = await web3.eth.getBalance(accounts[2]);
      const expected = (new Big(newBalance)).isLessThanOrEqualTo(Big(initialBalance - insuranceAmount));
      assert.equal(expected, true);

      await truffleAssert.fails(
        appContract.claimInsurance(appContractOwner, flight, timestamp, { from: accounts[2] }),
        truffleAssert.ErrorType.REVERT,
        "must be delayed due to airlines"
      );
    });
  });
});
