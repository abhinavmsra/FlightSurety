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
    /*******************************************************************/
    /*              DATA VARIABLES                                     */
    /*******************************************************************/

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

    /*******************************************************************/
    /*                      FUNCTION MODIFIERS                         */
    /*******************************************************************/

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

    /**
    * @dev Modifier that requires the "RegisteredAirline" account to be the function caller
    */
    modifier requireRegisteredAirline() {
        require(isRegisteredAirline(msg.sender), "Caller must be a registered airline");
        _;
    }

    /**
    * @dev Modifier that requires the "ActivatedAirline" account to be the function caller
    */
    modifier requireActivatedAirline() {
        require(isActivatedAirline(msg.sender), "Caller must be an active airline");
        _;
    }

    /**
    * @dev Modifier that requires an "ActivatedAirline" account or contract owner to be the function caller
    */
    modifier requireActivatedAirlineOrContractOwner() {
        require(
            isActivatedAirline(msg.sender) || (msg.sender == contractOwner), 
            "Caller must either be an active airline or contract owner"
        );
        _;
    }

    /**
    * @dev Modifier that demands a minimun funding amount
    */
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
    constructor(address payable _dataContractAddress) {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(_dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Returns whether the data contract is operational or not
    *
    */
    function isOperational() public view returns(bool) {
        return dataContract.isOperational();
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external requireContractOwner {
        dataContract.setOperatingStatus(mode);
    }

    /**
    * @dev Returns whether the airline is registered or not
    *
    */
    function isRegisteredAirline(address addr) private view returns(bool registered) {
        (int8 id,,,,,) = dataContract.getAirline(addr);
        
        registered = (id != 0);
    }

    /**
    * @dev Returns whether the airline is activated for operating or not
    *
    */
    function isActivatedAirline(address addr) private view returns(bool activated) {
        (,,,,activated,) = dataContract.getAirline(addr);
    }

    /******************************************************************************/
    /*                       SMART CONTRACT FUNCTIONS                             */
    /******************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *  It registers a new airline & adds votes for existing airlines    
    *
    **/   
    function registerAirline(
        address _airlineAddress, 
        string calldata _airlineName
    ) 
        external 
        requireIsOperational 
        requireActivatedAirlineOrContractOwner 
    {
        if (dataContract.getAirlineId(_airlineAddress) == 0) { // Registration Request
            _registerNewAirline(_airlineAddress, _airlineName);
        } else { // Voting
            _voteAirline(_airlineAddress);
        }
    }

    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(
        string calldata _flight, 
        uint256 _timestamp
    ) 
        external 
        requireActivatedAirline 
    {
        bytes32 key = getFlightKey(msg.sender, _flight, _timestamp);

        flights[key] = Flight({ isRegistered: true, statusCode: STATUS_CODE_UNKNOWN, updatedTimestamp: _timestamp, airline: msg.sender });
    }

    function fetchFlight(
        address _airline,
        string calldata _flight,
        uint256 _timestamp
    ) 
        external 
        view 
        returns(uint256 timestamp, uint8 statusCode, string memory airlineName) 
    {
        bytes32 key = getFlightKey(_airline, _flight, _timestamp);

        timestamp = flights[key].updatedTimestamp;
        statusCode = flights[key].statusCode;
        (,airlineName,,,,) = dataContract.getAirline(_airline);
    }

    function getInsurance(
        address _airline, 
        string calldata _flight, 
        uint256 _timestamp
    ) 
        external 
        view 
        returns(uint256 amount, uint256 claimAmount, uint8 status) 
    {
        bytes32 key = getFlightKey(_airline, _flight, _timestamp);
        (amount, claimAmount, status) = dataContract.getInsurance(msg.sender, key);
    }

    function buyInsurance(address _airline, string calldata _flight, uint256 _timestamp) external payable {
        require(msg.value > 0, "must send some ether");
        
        bytes32 key = getFlightKey(_airline, _flight, _timestamp);

        if (msg.value <= 1 ether) {
            dataContract.addInsurance(msg.sender, key, msg.value);
            return;
        }

        dataContract.addInsurance(msg.sender, key, 1 ether);
        
        // Refund remaining ether
        (bool sent,) = msg.sender.call{value: (msg.value - 1 ether)}("");
        require(sent, "Failed to refund Ether");
    }

    function claimInsurance(address _airline, string calldata _flight, uint256 _timestamp) external {
        bytes32 key = getFlightKey(_airline, _flight, _timestamp);
        require(flights[key].statusCode == STATUS_CODE_LATE_AIRLINE, "must be delayed due to airlines");

        (uint256 amount,, uint8 status) = dataContract.getInsurance(msg.sender, key);
        require(amount > 0, "must have bought insurance");
        require(status == 0, "must not be claimed");
        
        uint256 claimableAmount = SafeMath.div(SafeMath.mul(amount, 150), 100);
        dataContract.claimInsurance(msg.sender, key, claimableAmount);
    }

    function withDrawInsurance(address _airline, string calldata _flight, uint256 _timestamp) external {
        bytes32 key = getFlightKey(_airline, _flight, _timestamp);
        (, uint256 claimAmount, uint8 status) = dataContract.getInsurance(msg.sender, key);
        require(status == 1, "must be claimed");

        dataContract.withdrawInsurance(msg.sender, key);
        (bool sent,) = msg.sender.call{value: claimAmount}("");
        require(sent, "Failed to send Ether");
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
    (
        address _airline,
        string memory _flight,
        uint256 _timestamp,
        uint8 statusCode
    )
    internal
    {
        bytes32 key = getFlightKey(_airline, _flight, _timestamp);
        flights[key].statusCode = statusCode;
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
        ResponseInfo storage info = oracleResponses[key];
        info.requester = msg.sender;
        info.isOpen = true;

        emit OracleRequest(index, airline, flight, timestamp);
    }

    receive() external payable { _receiveAirlineFunds(); }
    fallback() external payable { _receiveAirlineFunds(); }

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

    function _receiveAirlineFunds() 
        private 
        requireRegisteredAirline 
        requireMinimumFunding 
    {
        dataContract.addAirlineBalance(msg.sender, msg.value);
        dataContract.activateAirline(msg.sender);
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
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({ isRegistered: true, indexes: indexes });
    }

    function getMyIndexes() view external returns(uint8[3] memory) {
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
        string memory flight,
        uint256 timestamp
    )
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3] memory) {
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
    function getRandomIndex(address account) internal returns (uint8){
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
