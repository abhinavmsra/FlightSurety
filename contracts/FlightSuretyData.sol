// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

contract FlightSuretyData {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;         // Account used to deploy contract
    bool private operational = true;      // Blocks all state changes throughout the contract if false

    uint8 private constant INSURANCE_BOUGHT = 0;
    uint8 private constant INSURANCE_CLAIMED = 1;
    uint8 private constant INSURANCE_WITHDRAWN = 2;

    struct Airline {
        int8 id;
        string name;
        bool consensus;
        int8 voteCount;
        bool activated;
        uint256 balance;
    }

    struct Insurance {
        uint256 amount;
        uint256 claimAmount;
        uint8 status;
    }

    mapping(address => mapping(address => bool)) votes; // { voterAddress => { airlineAddress => true }}
    mapping(address => Airline) airlines;

    mapping(bytes32 => Insurance) insurances;
    int8 airlinesCount;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
 
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() {
        contractOwner = msg.sender;
    }

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
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() external view returns(bool) {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(
        address _voterAddress,
        address _airlineAddress, 
        string memory _airlineName,
        bool consensus
    ) 
        external 
    {
        _vote(_voterAddress, _airlineAddress);
        
        airlinesCount += 1;
        airlines[_airlineAddress] = Airline({
            id: airlinesCount, 
            name: _airlineName, 
            consensus: consensus,
            balance: 0,
            activated: false,
            voteCount: 1
        });
    }

    /**
    * @dev Get an airline from address
    *
    */   
    function getAirline(
        address _airlineAddress
    ) 
        external 
        view 
        returns(int8 id, string memory name, bool consensus, int8 voteCount, bool activated, uint256 balance) 
    {
        id = airlines[_airlineAddress].id;
        name = airlines[_airlineAddress].name;
        consensus = airlines[_airlineAddress].consensus;
        voteCount = airlines[_airlineAddress].voteCount;
        activated = airlines[_airlineAddress].activated;
        balance = airlines[_airlineAddress].balance;
    }

    /**
    * @dev Get an airline from address
    *
    */   
    function getAirlineId(address _airlineAddress) external view returns(int8) {
        return airlines[_airlineAddress].id;
    }

    /**
    * @dev Get founders of the contract
    *
    */   
    function getAirlinesCount() external view returns(int8) {
        return airlinesCount;
    }

    function voteAirline(address _voterAddress, address _airlineAddress) external returns(int8) {
       _vote(_voterAddress, _airlineAddress);

       return(airlines[_airlineAddress].voteCount);
    }

    function approveAirline(address _airlineAddress) external {
       airlines[_airlineAddress].consensus = true;
    }

    function addAirlineBalance(address _airlineAddress, uint256 amount) external {
       airlines[_airlineAddress].balance += amount;
    }

    function activateAirline(address _airlineAddress) external {
       airlines[_airlineAddress].activated = true;
    }

    function addInsurance(address _passengerAddr, bytes32 _flightKey, uint256 amount) external {
        bytes32 key = getInsuranceKey(_passengerAddr, _flightKey);
        insurances[key] = Insurance({amount: amount, claimAmount: 0, status: INSURANCE_BOUGHT});
    }

    function getInsurance(
        address _passengerAddr, 
        bytes32 _flightKey
    ) 
        external 
        view 
        returns(uint256 amount, uint256 claimAmount, uint8 status) 
    {
        bytes32 key = getInsuranceKey(_passengerAddr, _flightKey);
        
        amount = insurances[key].amount;
        claimAmount = insurances[key].claimAmount;
        status = insurances[key].status;
    }

    function claimInsurance(
        address _passengerAddr, 
        bytes32 _flightKey, 
        uint256 claimAmount
    ) 
        external 
    {
        bytes32 key = getInsuranceKey(_passengerAddr, _flightKey);
        insurances[key].status = INSURANCE_CLAIMED;
        insurances[key].claimAmount = claimAmount;
    }

    function withdrawInsurance(address _passengerAddr, bytes32 _flightKey) external {
        bytes32 key = getInsuranceKey(_passengerAddr, _flightKey);
        insurances[key].status = INSURANCE_WITHDRAWN;
    }

    /********************************************************************************************/
    /*                                     PRIVATE FUNCTIONS                                    */
    /********************************************************************************************/

    function _vote(address _voterAddress, address _airlineAddress) private {
       // Allows contractOwner to vote themselves when creating first airline
       require((_voterAddress != _airlineAddress) || (airlinesCount == 0), "cant vote yourself");
       require(!votes[_voterAddress][_airlineAddress], "has already voted");

       votes[_voterAddress][_airlineAddress] = true;
       airlines[_airlineAddress].voteCount += 1;
    }

    function getInsuranceKey(address _passengerAddr, bytes32 _flightKey) pure private returns(bytes32) {
        return keccak256(abi.encodePacked(_passengerAddr, _flightKey));
    }
}
