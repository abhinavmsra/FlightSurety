
import Web3 from 'web3';
import {html, render} from 'lit-html';

import config from './config.json';
import Contract from './contract';

import './flightsurety.css';

const STATUS_CODES = {
    "0": "UNKNOWN",
    "10": "ON_TIME",
    "20": "LATE_AIRLINE",
    "30": "LATE_WEATHER",
    "40": "LATE_TECHNICAL",
    "50": "LATE_OTHER"
}

function openModal(event) {
    event.preventDefault();
    const { airline, flight, timestamp } = event.target.closest('tr').dataset;
    
    document.querySelector("#airline").value = airline;
    document.querySelector("#flight").value = flight;
    document.querySelector("#timestamp").value = timestamp;

    $('#modalInsurance').modal('show');
}

function onInsurancePurchase(event) {
    event.preventDefault();

    const amount = event.target.querySelector("#amount").value;
    const airline = event.target.querySelector("#airline").value;
    const flight = event.target.querySelector("#flight").value;
    const timestamp = event.target.querySelector("#timestamp").value;

    appContract.buyInsuranceFor(airline, flight, timestamp, amount, (result) => {
        $('#modalInsurance').modal('hide');
        location.reload();
    });
}

function claimHandler(event) {
    event.preventDefault();

    const { airline, flight, timestamp } = event.target.closest('tr').dataset;

    appContract.claimInsuranceFor(airline, flight, timestamp, _ => {
        location.reload();
    });
}

function withdrawHandler(event) {
    event.preventDefault();

    const { airline, flight, timestamp } = event.target.closest('tr').dataset;

    appContract.withdrawInsuranceFor(airline, flight, timestamp, _ => {
        location.reload();
    });
}

function fetchStatusHandler(event) {
    event.preventDefault();

    const { airline, flight, timestamp } = event.target.closest('tr').dataset;

    // Write transaction
    appContract.fetchFlightStatus(airline, flight, timestamp, (error, result) => {
        debugger
    });
}

function renderAction(flight) {
    if(flight.amount === "0") {
        return(
            html`<button type="button" class="btn btn-primary" @click=${openModal}>BUY</button>`
        )  
    }

    switch(flight.statusCode) {
        case "0":
            return(
                html`<button type="button" class="btn btn-info" @click=${fetchStatusHandler}>CHECK STATUS</button>`
            );
        case "20":
            switch(flight.insuranceStatus) {
                case "0":
                    return(
                        html`<button type="button" class="btn btn-info" @click=${claimHandler}>CLAIM</button>`
                    );
                case "1":
                    return(
                        html`<button type="button" class="btn btn-info" @click=${withdrawHandler}>
                                WITHDRAW ${Web3.utils.fromWei(flight.claimAmount)} Ether
                            </button>`
                    );
                case "2":
                    return(`WITHDRAWN ${Web3.utils.fromWei(flight.claimAmount)} Ether`);
            }
        default:
            return STATUS_CODES[flight.statusCode];
    }
}

function airlineTableTemplate(flights) {
    return(
        html`
            ${flights.map((flight) => html`
                <tr data-airline=${flight.airline} data-flight=${flight.name} data-timestamp=${flight.timestamp}>
                    <td>${flight.name}</td>
                    <td>${flight.airlineName}</td>
                    <td>${new Date(flight.timestamp*1000).toLocaleString("en-US")}</td>
                    <td>${renderAction(flight)}</td>
                </tr>
            `)}
        `
    );
}

function renderFlights(flights) {
    render(airlineTableTemplate(flights), document.querySelector("#tableAirline tbody"));
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
    renderFlights(flights);

    this.document.querySelector("#formInsurance").addEventListener("submit", onInsurancePurchase);

    $('#modalInsurance').on('hidden.bs.modal', function (e) {
        document.querySelector("#amount").value = "";
        document.querySelector("#airline").value = "";
        document.querySelector("#flight").value = "";
        document.querySelector("#timestamp").value = "";
    });

    const { FlightStatusInfo } = window.appContract.contract.events;

    FlightStatusInfo({fromBlock: 0}, (error, event) => {
        if(error) { return; }

        flights.forEach(flight => { 
            if(flight.name === event.returnValues.flight) { flight.statusCode = event.returnValues.status; }
        });

        renderFlights(flights)
    });
});
