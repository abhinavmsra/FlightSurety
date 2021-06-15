// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */

/// @author Abhinav Mishra
contract FlightSuretyApp {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    int8 constant MAX_FOUNDERS = 4;

    address private contractOwner;          // Account used to deploy contract
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
        require(dataContract.isOperational(), "Contract is currently not operational");  
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
        require(dataContract.getAirlineId(msg.sender) != 0, "Caller must be a airline");
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
        _registerAirline(contractOwner, _airlineName);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool) {
        return dataContract.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address _airlineAddress, string calldata _airlineName) external requireIsOperational requireRegisteredAirline returns(int8 id, string memory name) {
         (id, name) = _registerAirline(_airlineAddress, _airlineName);
    }

    /**
    * @dev Get an airline from address
    *
    */   
    function getAirlineName(address _airlineAddress) external view returns(string memory) {
        return dataContract.getAirlineName(_airlineAddress);
    }

    /**
    * @dev Get founders of the contract
    *
    */   
    function getAirlinesCount() external view returns(int8) {
        return dataContract.getAirlinesCount();
    }

    function _registerAirline(address _airlineAddress, string memory _airlineName) private returns(int8 id, string memory name) {
        (id, name) = dataContract.registerAirline(_airlineAddress, _airlineName);
    }
}   
