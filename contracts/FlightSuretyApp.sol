// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */

/// @author Abhinav Mishra
contract FlightSuretyApp {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    int8 constant MAX_FOUNDERS = 4;
    uint256 constant MINIMUM_FUNDING = 10 ether;

    FlightSuretyData private dataContract;
 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        require(isOperational(), "Contract is currently not operational");  
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireRegisteredAirline() {
        require(isAirline(msg.sender), "Caller must be a airline");
        _;
    }

    modifier requireMinimumFunding() {
        require(msg.value >= MINIMUM_FUNDING, "Must send at least 10 ether");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable _dataContractAddress, string memory _airlineName) {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(_dataContractAddress);
        
        // Create a default airlines
        _registerNewAirline(contractOwner, _airlineName);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() private view returns(bool) {
        return dataContract.isOperational();
    }

    function isAirline(address addr) private view returns(bool) {
        return dataContract.getAirlineId(addr) != 0;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    **/   
    function registerAirline(
        address _airlineAddress, 
        string calldata _airlineName
    ) 
        external 
        requireIsOperational 
        requireRegisteredAirline 
    {
        if (dataContract.getAirlineId(_airlineAddress) == 0) { // Registration Request
            _registerNewAirline(_airlineAddress, _airlineName);
        } else { // Voting
            _voteAirline(_airlineAddress);
        }
    }

    function getInsurance(address passengerAddr) external view returns(uint256 amount) {
        return dataContract.getInsurance(passengerAddr);
    }

    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight() external {

    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
    (
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    )
    internal
    {

    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp                            
    )
    external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        // oracleResponses[key] = ResponseInfo({
        //                                         requester: msg.sender,
        //                                         isOpen: true
        //                                     });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    receive() external payable { _receiveFunds(); }
    fallback() external payable { _receiveFunds(); }

    /********************************************************************************************/
    /*                                     PRIVATE FUNCTIONS                                    */
    /********************************************************************************************/
    function _registerNewAirline(address _airlineAddress, string memory _airlineName) private {
        dataContract.registerAirline(
            msg.sender,
            _airlineAddress, 
            _airlineName, 
            dataContract.getAirlinesCount() < MAX_FOUNDERS // consensus
        );
    }

    function _voteAirline(address _airlineAddress) private {
        uint256 airlineVoteCount = SafeCast.toUint256(dataContract.voteAirline(msg.sender, _airlineAddress));
        uint256 totalAirlineCount = SafeCast.toUint256(dataContract.getAirlinesCount() - 1); // One being the airline itself

        if(
            SafeMath.div(
                SafeMath.mul(airlineVoteCount, 100), 
                totalAirlineCount
            ) >= 50) {
                dataContract.approveAirline(_airlineAddress);   
        }
    }

    function _receiveFunds() private {
        if (isAirline(msg.sender)) {
            return _receiveAirlineFunds();
        }

        _receiveInsuranceFunds();
    }

    function _receiveAirlineFunds() private requireRegisteredAirline requireMinimumFunding {
        dataContract.addAirlineBalance(msg.sender, msg.value);
        dataContract.activateAirline(msg.sender);
    }

    function _receiveInsuranceFunds() private {
        if (msg.value <= 1 ether) {
            dataContract.addInsurance(msg.sender, msg.value);
            return;
        }

        dataContract.addInsurance(msg.sender, 1 ether);
        
        // Refund remaining ether
        (bool sent,) = msg.sender.call{value: (msg.value - 1 ether)}("");
        require(sent, "Failed to refund Ether");
    }

    /********************************************************************************************/
    /*                                     ORACLE MANAGEMENT                                    */
    /********************************************************************************************/
    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string calldata flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion

}   
