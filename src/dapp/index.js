
import Web3 from 'web3';
import {html, render} from 'lit-html';

import config from './config.json';
import Contract from './contract';

import './flightsurety.css';

function openModal(event) {
    event.preventDefault();
    document.querySelector("#flightId").value = event.target.dataset.airline;

    $('#modalInsurance').modal('show');
}

function onInsurancePurchase(event) {
    event.preventDefault();

    const amount = event.target.querySelector("#amount").value;
    const flightId = event.target.querySelector("#flightId").value;

    appContract.buyInsuranceFor(flightId, amount, (result) => {
        $('#modalInsurance').modal('hide');
        location.reload();
    });
}

function fetchStatusHandler(event) {
    event.preventDefault();

    const flightId = event.target.dataset.flight;
    const airline = event.target.dataset.airline;

    // Write transaction
    appContract.fetchFlightStatus(flightId, airline, (error, result) => {
        debugger
    });
}

function renderBuyInsurance(flight) {
    if(flight.amount === "0") {
        return(
            html`<button type="button" class="btn btn-primary" data-airline=${flight.id} @click=${openModal}>BUY</button>`
        )
    } 

    return html`<button type="button" class="btn btn-success">${flight.amount} Ether</button>`
}

function airlineTableTemplate(flights) {
    return(
        html`
            ${flights.map((flight) => html`
                <tr>
                    <td scope="row">${flight.name}</td>
                    <td>${new Date(flight.timestamp*1000)}</td>
                    <td>
                        ${renderBuyInsurance(flight)}
                        <button type="button" 
                                class="btn btn-info" 
                                data-airline=${flight.airlineId} 
                                data-flight=${flight.id} 
                                @click=${fetchStatusHandler}>
                            CHECK STATUS
                        </button>
                    </td>
                </tr>
            `)}
        `
    );
}

window.addEventListener("load", async function() {
    const networkName = "localhost";
    let web3 = undefined;

    if (window.ethereum) {
        web3 = new Web3(Web3.givenProvider || new Web3.providers.HttpProvider(config[networkName].url)); // use MetaMask's provider
        await window.ethereum.enable(); // get permission to access accounts
    } else {
        console.warn("No web3 detected. Falling back to http://127.0.0.1:9545. You should remove this fallback when you deploy live",);
        web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:9545"));
    }

    const accounts = await web3.eth.getAccounts();
    window.appContract = new Contract(web3, networkName, accounts[0]);

    const flights = await appContract.loadFlights();
    render(airlineTableTemplate(flights), document.querySelector("#tableAirline tbody"));

    this.document.querySelector("#formInsurance").addEventListener("submit", onInsurancePurchase);

    $('#modalInsurance').on('hidden.bs.modal', function (e) {
        document.querySelector("#amount").value = "";
        document.querySelector("#flightId").value = "";
    });
});
