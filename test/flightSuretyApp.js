const truffleAssert = require('truffle-assertions');
const FlightSuretyData = artifacts.require("FlightSuretyData")
const FlightSuretyApp = artifacts.require("FlightSuretyApp")

contract("FlightSuretyApp", accounts => {
  describe('#constructor', () => {
    it("registers first airline", async () => {
      const dataContract = await FlightSuretyData.deployed();
      const recordedAirline = await dataContract.getAirline(accounts[0]);
      
      assert.equal(recordedAirline.id, 1, "must be recorded with id = 1");
    });
  });

  describe('#registerAirline', () => {
    describe('when a new airlines is registered', () => {
      describe('when total airlines count is less than 4', () => {
        it("registers airlines & grants consent", async () => {
          const dataContractOwner = accounts[0];
          const appContractOwner = accounts[1];

          const dataContract = await FlightSuretyData.new({from: dataContractOwner});
          const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

          await appContract.registerAirline(accounts[2], 'Bitcoin Airlines', { from: accounts[1] });
          await appContract.registerAirline(accounts[3], 'Ethereum Airlines', { from: accounts[2] });
          await appContract.registerAirline(accounts[4], 'Doge Airlines', { from: accounts[3] });

          await Promise.all(
            [
              appContractOwner,
              accounts[2],
              accounts[3],
              accounts[4],
            ].map(async airlineOwner => {
              const result = await dataContract.getAirline(airlineOwner);
              assert.equal(result.consensus, true, "must be approved");
            })
          );
        });
      });

      describe('when total airlines count is greater than 4', () => {
        it("registers airlines but does NOT grant consent", async () => {
          const dataContractOwner = accounts[0];
          const appContractOwner = accounts[1];

          const dataContract = await FlightSuretyData.new({from: dataContractOwner});
          const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

          await appContract.registerAirline(accounts[2], 'Bitcoin Airlines', { from: accounts[1] });
          await appContract.registerAirline(accounts[3], 'Ethereum Airlines', { from: accounts[2] });
          await appContract.registerAirline(accounts[4], 'Doge Airlines', { from: accounts[3] });

          const _binanceAirline = await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[4] });
          const result = await dataContract.getAirline(accounts[5]);

          assert.equal(result.consensus, false, "must not be approved");
        });
      });
    });

    describe('when airline with _airlineAddress exists', () => {
      it("adds votes to the airlines", async () => {
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

        await appContract.registerAirline(accounts[2], 'Bitcoin Airlines', { from: accounts[1] });
        await appContract.registerAirline(accounts[3], 'Ethereum Airlines', { from: accounts[2] });
        await appContract.registerAirline(accounts[4], 'Doge Airlines', { from: accounts[3] });

        const _binanceAirline = await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[4] });
        await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[1] });

        const result = await dataContract.getAirline(accounts[5]);
        assert.equal(result.voteCount, 2, `expected 2, got ${result.voteCount}`);
      });

      it("approves airlines if voteCount >= 50%", async () => {
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

        await appContract.registerAirline(accounts[2], 'Bitcoin Airlines', { from: accounts[1] });
        await appContract.registerAirline(accounts[3], 'Ethereum Airlines', { from: accounts[2] });
        await appContract.registerAirline(accounts[4], 'Doge Airlines', { from: accounts[3] });

        /** 
         *  Testing for consensus when prior count is an even number
         * */
        await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[4] });
        let result = await dataContract.getAirline(accounts[5]);
        assert.equal(
          result.consensus, 
          false, 
          `Total Airlines is 4 (except for the current one), hence ${result.voteCount} votes should not be enough for consensus`
        );

        await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[1] });

        result = await dataContract.getAirline(accounts[5]);
        assert.equal(
          result.consensus, 
          true, 
          `Total Airlines is 4 (except for the current one), hence ${result.voteCount} votes should be enough for consensus`
        );

        /** 
         *  Testing for consensus when prior count is an odd number
         * */
        await appContract.registerAirline(accounts[6], 'Ada Airlines', { from: accounts[5] });
        result = await dataContract.getAirline(accounts[6]);
        assert.equal(
          result.consensus, 
          false, 
          `Total Airlines is 5 (except for the current one), hence ${result.voteCount} votes should not be enough for consensus`
        );

        await appContract.registerAirline(accounts[6], 'Ada Airlines', { from: accounts[4] });
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

      it("reverts when an airline tries to vote itself", async () => {
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        
        // Prepare 4 airlines
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });
        await appContract.registerAirline(accounts[2], 'Bitcoin Airlines', { from: accounts[1] });
        await appContract.registerAirline(accounts[3], 'Ethereum Airlines', { from: accounts[2] });
        await appContract.registerAirline(accounts[4], 'Doge Airlines', { from: accounts[3] });

        // Register & vote a new airline
        await appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[4] }); // register

        await truffleAssert.fails(
          appContract.registerAirline(accounts[5], 'Binance Airlines', { from: accounts[5] }), // vote yourself
          truffleAssert.ErrorType.REVERT,
          "cant vote yourself"
        );
      });
    });
  });

  describe('#activate airlines', () => {
    describe('when value is less than 10 ether', () => {
      it("reverts transaction", async () => {
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

        await truffleAssert.fails(
          appContract.sendTransaction({ from: appContractOwner, value: 1 }),
          truffleAssert.ErrorType.REVERT,
          "Must send at least 10 ether"
        );
      });
    });

    describe('when sender is not an airline', () => {
      it("creates an insurance", async () => {
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

        const insuranceAmount = 10000;
        appContract.sendTransaction({ from: accounts[2], value: insuranceAmount })

        assert.equal(
          await appContract.getInsurance(accounts[2]), 
          insuranceAmount,
          "must equal provided amount"
        );
      });

      it("refunds if sent more than 1 ether", async () => {
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

        const passenger = accounts[2];
        const initialPassengerBalance = web3.utils.fromWei(await web3.eth.getBalance(passenger));
        const transferredAmount = "2";
        const gasPrice = "10000000000";

        const txHash = await appContract.sendTransaction({ from: passenger, gasPrice: gasPrice, value: web3.utils.toWei(transferredAmount) });

        const contractBalance  = web3.utils.fromWei(await web3.eth.getBalance(appContract.address));
        const passengerBalance = web3.utils.fromWei(await web3.eth.getBalance(passenger));
        const insuranceBalance = web3.utils.fromWei(await appContract.getInsurance(passenger));
        const totalGasAmount   = parseFloat(web3.utils.fromWei(gasPrice)) * txHash.receipt.gasUsed;

        assert.equal(contractBalance, "1", "contract balance must equal 1 ether");
        assert.equal(insuranceBalance, "1", "insurance balance must equal 1 ether");
        assert.equal(
          parseFloat(initialPassengerBalance), 
          parseFloat(passengerBalance) + parseFloat(1) + parseFloat(totalGasAmount), 
          "net total must be same"
        );
      });
    });
    
    describe('when value is greater than 10 ether & from an airline', () => {
      it("records transaction", async () => {
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

        await truffleAssert.passes(
          appContract.sendTransaction({ from: appContractOwner, value: 10000000000000000000 }),
          "This should pass"
        );
      });

      it("activates airline", async () => {
        const amount = 10000000000000000000;
        const dataContractOwner = accounts[0];
        const appContractOwner = accounts[1];

        const dataContract = await FlightSuretyData.new({from: dataContractOwner});
        const appContract = await FlightSuretyApp.new(dataContract.address, 'Crypto Airlines', { from: appContractOwner });

        assert.equal(
          (await dataContract.getAirline(appContractOwner)).activated, 
          false, 
          "should not be activated yet"
        );

        await truffleAssert.passes(
          appContract.sendTransaction({ from: appContractOwner, value: amount }),
          "This should pass"
        );

        const result = await dataContract.getAirline(appContractOwner);

        assert.equal(result.activated, true, "should be activated after transferring funds");
        assert.equal(result.balance, amount, "should have balance equal to transferred funds");
      });
    });
  })
});
