// SPDX-License-Identifier: Copyright

pragma solidity ^0.8.18;

/// @title silicoin - connection interace for silicoin blockchainbackend
/// @author rixel
/// @notice silicoin is a blockchain powered marketplace for artificial
/// @notice intelligence and machine learning models.
/// @notice ---
/// @notice Made for Chainlink Spring 2023 Hackathon
interface silicoinLinkService {

    /// @notice Get a response from off-chain server
    /// @param  request_ The request to get response for
    /// @return ApiResponse The the request and the full response
    function getResponse(string calldata request_)
                         external returns (ApiResponse calldata);
    
    /// @notice Get a random number from Chainlink VRF
    /// @return uint256 A random number
    function getRandomNumber() external returns (uint256);

    struct ApiResponse {
        string request;
        string result;
        string errorMessage;
    }

}
