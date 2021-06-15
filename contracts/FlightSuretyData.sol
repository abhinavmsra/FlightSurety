// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

contract FlightSuretyData {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address public contractOwner;         // Account used to deploy contract
    bool private operational = true;      // Blocks all state changes throughout the contract if false

    struct Airline {
        int8 id;
        string name;
    }

    mapping(address => Airline) airlines;
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
    function registerAirline(address _airlineAddress, string memory _airlineName) external returns(int8, string memory){
        airlinesCount += 1;
        airlines[_airlineAddress] = Airline({id: airlinesCount, name: _airlineName});

        return(airlines[_airlineAddress].id, airlines[_airlineAddress].name);
    }

    /**
    * @dev Get an airline from address
    *
    */   
    function getAirlineId(address _airlineAddress) external view returns(int8) {
        return airlines[_airlineAddress].id;
    }

    /**
    * @dev Get an airline from address
    *
    */   
    function getAirlineName(address _airlineAddress) external view returns(string memory) {
        return airlines[_airlineAddress].name;
    }

    /**
    * @dev Get founders of the contract
    *
    */   
    function getAirlinesCount() external view returns(int8) {
        return airlinesCount;
    }
}

