// SPDX-License-Identifier: Copyright

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

/// @title silicoin - Chainlink VRF connector contract
/// @author rixel
/// @notice silicoin is a blockchain powered marketplace for artificial
/// @notice intelligence and machine learning models.
/// @notice ---
/// @notice Made for Chainlink Spring 2023 Hackathon
contract silicoinVRFconnector is VRFV2WrapperConsumerBase, ConfirmedOwner {

    // ###############
    // # CONSTRUCTOR #
    // ###############

    constructor() ConfirmedOwner(msg.sender)
                  VRFV2WrapperConsumerBase(linkAddress, wrapperAddress) {

        requestNumbers();

    }

    // ######################
    // # EXTERNAL FUNCTIONS #
    // ######################

    function getRandomNumber() external returns (uint256) {

        require(randomNumbers.length > 0,
                'silicoinLinkServiceContract is out of numbers');
        uint256 result = randomNumbers[randomNumbers.length - 1];
        randomNumbers.pop();
        if (randomNumbers.length < 1) {
            requestNumbers();
        }
        return result;

    }

    // ######################
    // # INTERNAL FUNCTIONS #
    // ######################

    function fulfillRandomWords(uint256 _requestId,
                                uint256[] memory _randomWords)
                                internal override {

        uint i = _requestId;
        for (i = 0; i < _randomWords.length; i++) {
            randomNumbers.push(_randomWords[i]);
        }
        lastPaid = 0;
        lastRequestId = 0;
        lastFulfilled = false;

    }

    // #####################
    // # PRIVATE FUNCTIONS #
    // #####################

    function requestNumbers() private {

        uint256 requestId = requestRandomness(callbackGasLimit,
                                              requestConfirmations, numWords);
        lastPaid = VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit);
        lastRequestId = requestId;
        lastFulfilled = true;

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

    uint32 private callbackGasLimit = 500000;
    bool private lastFulfilled = false;
    uint256 private lastPaid = 0;
    uint256 private lastRequestId = 0;
    address private linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    uint32 private numWords = 10;
    uint256[] private randomNumbers;
    uint16 private requestConfirmations = 3;
    address private wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    // ##########
    // # EVENTS #
    // ##########

}
