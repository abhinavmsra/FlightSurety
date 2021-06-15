const truffleAssert = require('truffle-assertions');
const FlightSuretyData = artifacts.require("FlightSuretyData")
const FlightSuretyApp = artifacts.require("FlightSuretyApp")

contract("FlightSuretyApp", accounts => {
  describe('#constructor', () => {
    it("registers first airline", async () => {
      const dataContractOwner = accounts[0];
      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
  
      const appContractOwner = accounts[1];
      await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });
  
      const recordedAirlineId = dataContract.getAirlineId.call(appContractOwner);
      assert(recordedAirlineId, 1, "must be recorded with id = 1");
    });
  });

  describe('#registerAirline', () => {
    it("does not allow to register when caller is not an airline", async () => {
      const dataContractOwner = accounts[0];
      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
  
      const appContractOwner = accounts[1];
      const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });
  
      const newAirlineAddress = accounts[2];

      await truffleAssert.fails(
        appContract.registerAirline.call(newAirlineAddress, 'Ethereum Airlines', { from: newAirlineAddress }),
        truffleAssert.ErrorType.REVERT
      );
    });
  
    it("allows to register when caller is an airline", async () => {
      const dataContractOwner = accounts[0];
      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
  
      const appContractOwner = accounts[1];
      const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

      await appContract.registerAirline(accounts[2], 'Bitcoin Airlines', { from: accounts[1] });
      let airlinesCount = await appContract.getAirlinesCount();
      assert(airlinesCount, 2, `must create an airline for account: ${accounts[2]}`);

      await appContract.registerAirline(accounts[3], 'Ethereum Airlines', { from: accounts[2] });
      airlinesCount = await appContract.getAirlinesCount();
      assert(airlinesCount, 3, `must create an airline for account: ${accounts[3]}`);

      await appContract.registerAirline(accounts[4], 'Doge Airlines', { from: accounts[3] });
      airlinesCount = await appContract.getAirlinesCount();
      assert(airlinesCount, 4, `must create an airline for account: ${accounts[4]}`);
    });
  });
});
