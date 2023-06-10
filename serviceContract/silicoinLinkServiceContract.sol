// SPDX-License-Identifier: Copyright

pragma solidity ^0.8.18;

import './silicoinLinkService.sol';
import './silicoinAPIconnector.sol';
import './silicoinVRFconnector.sol';

/// @title silicoin - backend contract
/// @author rixel
/// @notice silicoin is a blockchain powered marketplace for artificial
/// @notice intelligence and machine learning models.
/// @notice ---
/// @notice Made for Chainlink Spring 2023 Hackathon
contract silicoinLinkServiceContract is silicoinLinkService {

    // ###############
    // # CONSTRUCTOR #
    // ###############

    constructor(string memory sentence_, address authorizedContract_) {

        rootUser = payable(msg.sender);
        rootKey = keccak256(abi.encodePacked(sentence_));
        authorizedContract = authorizedContract_;
        randomConnector = new silicoinVRFconnector();
        apiConnector = new silicoinAPIconnector(API_PATH);

    }

    // ##################
    // # USER FUNCTIONS #
    // ##################

    /// @notice Get a response from off-chain server
    /// @param  request_ The request to get response for
    /// @return ApiResponse The the request and the full response
    function getResponse(string calldata request_) onlyAuthorizedContract()
                         external returns (ApiResponse memory) {
        
        string memory request;
        string memory result;
        string memory errorMessage;
        (request, result, errorMessage) = apiConnector.getResponse(request_);
        return ApiResponse(request,result, errorMessage);

    }

    /// @notice Get a random number from Chainlink VRF
    /// @return uint256 A random number
    function getRandomNumber() onlyAuthorizedContract()
                             external returns (uint256) {

        return randomConnector.getRandomNumber();

    }

    // ###################
    // # ADMIN FUNCTIONS #
    // ###################

    function flush(string calldata sentence_) onlyAdmin(sentence_) external {

        address payable to = payable(msg.sender);
        bool result = to.send(address(this).balance);
        require(result, 'Failed to flush.');

    }

    function flushLink(string calldata sentence_) onlyAdmin(sentence_) external {

        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(msg.sender, link.balanceOf(address(this))),
                "Unable to transfer");

    }

    function flushLinkTo(string calldata sentence_, address anotherAddress_)
                         onlyAdmin(sentence_) external {

        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(anotherAddress_, link.balanceOf(address(this))),
                "Unable to transfer");

    }

    function flushTo(string calldata sentence_, address anotherAddress_)
                     onlyAdmin(sentence_) external {

        address payable to = payable(anotherAddress_);
        bool result = to.send(address(this).balance);
        require(result, 'Failed to flush.');

    }

    function getAuthorizedAddress(string calldata sentence_)
                                  onlyAdmin(sentence_)
                                  external view returns (address) {

        return authorizedContract;

    }

    function setAuthorizedAddress(string calldata sentence_, address newAddress_)
                                  onlyAdmin(sentence_) external {

        authorizedContract = newAddress_;

    }

    // ######################
    // # INTERNAL FUNCTIONS #
    // ######################

    function safeAdd(uint one_, uint another_, bool useRequire_)
                     pure internal returns (uint) {

        uint result = one_ + another_;
        if (useRequire_) {
            require(result >= one_ && result >= another_, 'safeAdd failed.');
        } else if (result < one_ || result < another_) {
            result = one_;
        }
        return result;

    }

    function safeDivide(uint one_, uint another_, bool useRequire_)
                        pure internal returns (uint) {

        uint result;
        if (useRequire_) {
            require(another_ != 0, 'safeDivide failed.');
            result = one_ / another_;
            require(result <= one_, 'safeDivide failed.');
        } else if (another_ != 0) {
            result = one_ / another_;
            if (result > one_) result = one_;
        } else {
            result = one_;
        }
        return result;

    }

    function safeMultiply(uint one_, uint another_, bool useRequire_)
                          pure internal returns (uint) {

        uint result = one_ * another_;
        if (useRequire_) {
            require(result <= one_, 'safeMultiply failed.');
        } else if (result < one_ || result < another_) {
            result = one_;
        }
        return result;

    }

    function safeSubtract(uint one_, uint another_, bool useRequire_)
                          pure internal returns (uint) {

        uint result = one_ - another_;
        if (useRequire_) {
            require(result <= one_, 'SafeSubtract failed.');
        } else if (result > one_) {
            result = one_;
        }
        return result;

    }

    // #####################
    // # PRIVATE FUNCTIONS #
    // #####################

    // #############
    // # MODIFIERS #
    // #############

    modifier onlyAdmin(string calldata sentence_) {

        require(msg.sender == rootUser, 'Only root can perform this action.');
        require(keccak256(abi.encodePacked(sentence_)) == rootKey,
                'This action requires authorization.');
        _;

    }

    modifier onlyAuthorizedContract() {

        require(msg.sender == authorizedContract,
                'Only authorized contract can perform this action.');
        _;

    }

    // ###################
    // # ADMIN VARIABLES #
    // ###################

    address private authorizedContract;
    bytes32 private rootKey;

    // ###########
    // # STRUCTS #
    // ###########
    
    // #############
    // # CONSTANTS #
    // #############

    string constant public API_PATH = 'https://silicoin.hyperrixel.com/chainlink_api.php?request=';

    // #########
    // # ENUMS #
    // #########

    // ####################
    // # PUBLIC VARIABLES #
    // ####################

    address payable public rootUser;
 
    // #####################
    // # PRIVATE VARIABLES #
    // #####################

    silicoinAPIconnector private apiConnector;
    address private linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    silicoinVRFconnector private randomConnector;

    // ##########
    // # EVENTS #
    // ##########

}