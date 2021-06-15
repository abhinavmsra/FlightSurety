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

    int8 constant MAX_FOUNDERS = 4;
    uint256 constant MINIMUM_FUNDING = 10 ether;

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
        require(dataContract.getAirlineId(msg.sender) != 0, "Caller must be a airline");
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

    receive() external payable requireRegisteredAirline requireMinimumFunding { _receiveFunds(); }
    fallback() external payable requireRegisteredAirline requireMinimumFunding { _receiveFunds(); }

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
        dataContract.addAirlineBalance(msg.sender, msg.value);
        dataContract.activateAirline(msg.sender);
    }
}   
