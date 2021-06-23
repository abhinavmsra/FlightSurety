// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

contract FlightSuretyData {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;         // Account used to deploy contract
    address private appContract;          // Contract address on main app
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
    event NewAppContract(address oldAddress, address newAddress);

    /********************************************************************************************/
    /*                                       Constructor                                        */
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

    /**
    * @dev Modifier that requires the appContract to be the function caller
    */
    modifier requireAppContract() {
        require(msg.sender == appContract, "Caller is not app contract");
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

    /**
    * @dev Sets app contract address
    *
    * This allows contract owner to change app contract address, in case a new app is present
    */    
    function setAppContract(address _appContract) external requireContractOwner {
        emit NewAppContract(appContract, _appContract);

        appContract = _appContract;
    }

    /**
    * @dev Get current app contract address
    *
    * This allows contract owner to fetch current app contract address
    */    
    function getAppContract() 
        external 
        view 
        requireContractOwner 
        returns (address)
    {
        return appContract;
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
        requireIsOperational
        requireAppContract 
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
        returns(
            int8 id, 
            string memory name, 
            bool consensus, 
            int8 voteCount, 
            bool activated, 
            uint256 balance
        ) 
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
    function getAirlineId(address _airlineAddress) external view returns(int8 id) {
        id = airlines[_airlineAddress].id;
    }

    /**
    * @dev Get total number of airlines in the contract
    *
    */   
    function getAirlinesCount() external view returns(int8 count) {
        count = airlinesCount;
    }

    /**
    * @dev Adds votes to an airline
    *
    */ 
    function voteAirline(
        address _voterAddress, 
        address _airlineAddress
    ) 
        external 
        requireIsOperational
        requireAppContract 
        returns(int8 voteCount) 
    {
       _vote(_voterAddress, _airlineAddress);

       voteCount = airlines[_airlineAddress].voteCount;
    }

    /**
    * @dev Approves an airline
    *
    */
    function approveAirline(
        address _airlineAddress
    ) 
        external 
        requireIsOperational
        requireAppContract 
    {
       airlines[_airlineAddress].consensus = true;
    }

    /**
    * @dev Funds an airline balance
    *
    */
    function addAirlineBalance(
        address _airlineAddress, 
        uint256 amount
    ) 
        external 
        requireIsOperational
        requireAppContract 
    {
       airlines[_airlineAddress].balance += amount;
    }

    /**
    * @dev Activates an airline
    *
    */
    function activateAirline(
        address _airlineAddress
    ) 
        external 
        requireIsOperational
        requireAppContract 
    {
       airlines[_airlineAddress].activated = true;
    }

    /**
    * @dev Adds an insurance for a flight & passenger
    *
    */
    function addInsurance(
        address _passengerAddr, 
        bytes32 _flightKey, 
        uint256 amount
    ) 
        external 
        requireIsOperational
        requireAppContract 
    {
        bytes32 key = getInsuranceKey(_passengerAddr, _flightKey);
        insurances[key] = Insurance({amount: amount, claimAmount: 0, status: INSURANCE_BOUGHT});
    }

    /**
    * @dev Fetches an insurance details for a flight & passenger
    *
    */
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

    /**
    * @dev Claims an insurance for a flight & passenger
    *
    */
    function claimInsurance(
        address _passengerAddr, 
        bytes32 _flightKey, 
        uint256 claimAmount
    ) 
        external 
        requireIsOperational
        requireAppContract 
    {
        bytes32 key = getInsuranceKey(_passengerAddr, _flightKey);
        insurances[key].status = INSURANCE_CLAIMED;
        insurances[key].claimAmount = claimAmount;
    }

    /**
    * @dev Marks an insurance as withdrawn
    *
    */
    function withdrawInsurance(
        address _passengerAddr, 
        bytes32 _flightKey
    ) 
        external 
        requireIsOperational
        requireAppContract
    {
        bytes32 key = getInsuranceKey(_passengerAddr, _flightKey);
        insurances[key].status = INSURANCE_WITHDRAWN;
    }

    /********************************************************************************************/
    /*                                     PRIVATE FUNCTIONS                                    */
    /********************************************************************************************/
    /**
    * @dev Adds votes to an airline
    *
    */
    function _vote(address _voterAddress, address _airlineAddress) private {
       // Allows contractOwner to vote themselves when creating first airline
       require((_voterAddress != _airlineAddress) || (airlinesCount == 0), "cant vote yourself");
       require(!votes[_voterAddress][_airlineAddress], "has already voted");

       votes[_voterAddress][_airlineAddress] = true;
       airlines[_airlineAddress].voteCount += 1;
    }

    /**
    * @dev Calculates a key for _passengerAddr & _flightKey
    *
    */
    function getInsuranceKey(address _passengerAddr, bytes32 _flightKey) pure private returns(bytes32) {
        return keccak256(abi.encodePacked(_passengerAddr, _flightKey));
    }
}
