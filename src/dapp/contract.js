import config from './config.json';
import appArtifact from '../../build/contracts/FlightSuretyApp.json';

class Contract {
    constructor(web3, networkName, account) {
        this.web3 = web3;
        this.networkName = networkName;
        this.account = account;
        this.contract = new this.web3.eth.Contract(appArtifact.abi, config[networkName].appAddress);  
    }

    async buyInsuranceFor(airline, amount, callback) {
        const { buyInsurance } = this.contract.methods;
        
        buyInsurance(airline)
            .send({from: this.account, value: this.web3.utils.toWei(amount)})
            .on("receipt", callback)
            .on("error", console.error);
    }

    async loadFlights() {
        const { fetchFlight } = this.contract.methods;
        let flights = [];

        await Promise.all(
            config[this.networkName].flights.map(async flight => {
                const results = await fetchFlight(flight[0], flight[1]).call();
                flights.push({ name: results.airlineName, timestamp: results.timestamp, id: results.flightId });
            })
        );

        return flights;
    }
}

export default Contract;