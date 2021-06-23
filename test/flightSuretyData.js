const FlightSuretyData = artifacts.require("FlightSuretyData")
const FlightSuretyApp = artifacts.require("FlightSuretyApp")

contract("FlightSuretyData", accounts => {
  describe("setAppContract", async () => {
    it("sets app contract address", async () => {
      const dataContractOwner = accounts[0];
      const appContractOwner = accounts[1];
  
      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
      const appContract = await FlightSuretyApp.new(dataContract.address, { from: appContractOwner });
  
      await dataContract.setAppContract(appContract.address, { from: accounts[0] });

      assert.equal(await dataContract.getAppContract(), appContract.address);
    });
  });

  describe("setOperatingStatus", async () => {
    it("enables operationStatus", async () => {
      const dataContractOwner = accounts[0];
      const appContractOwner = accounts[1];
  
      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
      const appContract = await FlightSuretyApp.new(dataContract.address, { from: appContractOwner });
      await dataContract.setAppContract(appContract.address, { from: accounts[0] });

      await dataContract.setOperatingStatus(true, {from: dataContractOwner});
      assert.equal(await dataContract.isOperational(), true);
    });

    it("disables operationStatus", async () => {
      const dataContractOwner = accounts[0];
      const appContractOwner = accounts[1];
  
      const dataContract = await FlightSuretyData.new({from: dataContractOwner});
      const appContract = await FlightSuretyApp.new(dataContract.address, { from: appContractOwner });
      await dataContract.setAppContract(appContract.address, { from: accounts[0] });

      await dataContract.setOperatingStatus(false, {from: dataContractOwner});
      assert.equal(await dataContract.isOperational(), false);
    });
  });
});