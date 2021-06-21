import Web3 from 'web3';
import express from 'express';

import { abi as appAbi } from '../../build/contracts/FlightSuretyApp.json';
import { localhost as config } from './config.json';

const STATUS_CODES = [0, 10, 20, 30, 40, 50];

const web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
const flightSuretyApp = new web3.eth.Contract(appAbi, config.appAddress);
const { OracleRequest } = flightSuretyApp.events;

OracleRequest({ fromBlock: 0 }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
});

const app = express();

function initREST() {
    app.get('/api', (req, res) => {
        res.send({
            message: 'An API for use with your Dapp!'
        });
    });
}

export default app;