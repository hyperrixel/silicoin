// SPDX-License-Identifier: Copyright

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/// @title silicoin - Chainlink API connector contract
/// @author rixel
/// @notice silicoin is a blockchain powered marketplace for artificial
/// @notice intelligence and machine learning models.
/// @notice ---
/// @notice Made for Chainlink Spring 2023 Hackathon
contract silicoinAPIconnector is ChainlinkClient, ConfirmedOwner {

    using Chainlink for Chainlink.Request;
    
    // ###############
    // # CONSTRUCTOR #
    // ###############

    constructor(string memory apiPath_) ConfirmedOwner(msg.sender) {
        
        apiPath = apiPath_;
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "53f9755920cd451a8fe46f5087468395";
        fee = (1 * LINK_DIVISIBILITY) / 10;
        inRequest = false;

    }

    // ######################
    // # EXTERNAL FUNCTIONS #
    // ######################

    function getResponse(string calldata request_) external
                         returns (string memory, string memory, string memory) {
        
        makeRequest(request_);
        return (request, result, errorMessage);

    }

    // ####################
    // # PUBLIC FUNCTIONS #
    // ####################

    function fulfill(bytes32 requestId_, string memory response_) public
                     recordChainlinkFulfillment(requestId_) {
        
        inRequest = false;
        result = response_;
        errorMessage = '';

    }
    
    // ######################
    // # INTERNAL FUNCTIONS #
    // ######################

    // #####################
    // # PRIVATE FUNCTIONS #
    // #####################

    function makeRequest(string calldata request_) private {

        
        if (inRequest) {
            errorMessage = 'Called new request in request';
            revert();
        }
        Chainlink.Request memory thisRequest =
                          buildChainlinkRequest(jobId, address(this),
                                                this.fulfill.selector);
        thisRequest.add('get', string.concat(apiPath, request_));
        thisRequest.add('path', 'result');
        sendChainlinkRequest(thisRequest, fee);
        inRequest = true;

    }

    // #############
    // # MODIFIERS #
    // #############

    // ###########
    // # STRUCTS #
    // ###########
    
    // #############
    // # CONSTANTS #
    // #############

    // #########
    // # ENUMS #
    // #########

    // ####################
    // # PUBLIC VARIABLES #
    // ####################

    // #####################
    // # PRIVATE VARIABLES #
    // #####################

    uint256 private fee;
    bytes32 private jobId;
    
    string private apiPath;
    bool private inRequest;
    string private request;
    string private result;
    string private errorMessage;

    // ##########
    // # EVENTS #
    // ##########

}
