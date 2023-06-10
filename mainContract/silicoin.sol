// SPDX-License-Identifier: Copyright
pragma solidity ^0.8.18;

import './silicoinLinkService.sol';

/// @title silicoin - main contract
/// @author rixel
/// @notice silicoin is a blockchain powered marketplace for artificial
/// @notice intelligence and machine learning models.
/// @notice ---
/// @notice Made for Chainlink Spring 2023 Hackathon
contract silicoin {

    // ###############
    // # CONSTRUCTOR #
    // ###############

    /// @notice Construct the contract
    /// @param  sentence_ The Id of the model to get folder to
    /// @param  silicoinLinkService_ Address of the silicoin backend contract
    constructor(string memory sentence_, address silicoinLinkService_) {

        rootUser = payable(msg.sender);
        rootKey = keccak256(abi.encodePacked(sentence_));
        silicoinLinkServiceAddress = silicoinLinkService_;
        availableBalance = 0;
        _feePercentage = DEFAULT_FEE_PERCENTAGE;

    }

    // ##################
    // # USER FUNCTIONS #
    // ##################

    /// @notice Add feedback to the model
    /// @param  id_ The Id of the model to add feedback to
    /// @param  feedback_ The Id of the feedback type
    /// @notice ---
    /// @notice This is a payable method
    function addFeedback(uint256 id_, uint8 feedback_)
                         onlyExistingModel(id_) external payable {

        require(msg.value >= FEEDBACK_PRICE,
                'This action costs about 0.1 LINK.');
        bool success = false;
        Feedbacks feedbacks;
        availableBalance = safeAdd(availableBalance, msg.value, false);
        if (feedback_ == 1) {
            feedbacks = Feedbacks.Like;
            success = true;
            _models[id_].likes++;
        } else if (feedback_ ==2) {
            feedbacks = Feedbacks.DisLike;
            success = true;
            _models[id_].disLikes++;
        }
        if (success) emit ModelFeedback(id_, feedbacks, _models[id_].likes,
                                        _models[id_].disLikes);

    }
    
    /// @notice Add a new model
    /// @param  ownerName_ The name of the owner of the model
    /// @param  modelName_ The name of the model
    /// @param  description_ The description of the model
    /// @param  link_ The link or base link of the model
    /// @param  accesType_ The access strategy identifier of the model
    /// @return uint256 The Id of the new model
    /// @dev    ---
    /// @dev    Frontend developers should care to call setModelDetails() to
    /// @dev    fulfill the whole model registration process
    function addModel(string calldata ownerName_, string calldata modelName_,
                      string calldata description_, string calldata link_,
                      uint8 accesType_) external returns (uint256) {

        uint256 modelID =  silicoinLinkService(silicoinLinkServiceAddress)
                                               .getRandomNumber();
        while (_modelOwners[modelID] == address(0)) {
            modelID =  silicoinLinkService(silicoinLinkServiceAddress)
                                               .getRandomNumber();
        }
        LinkAccessTypes accesType = LinkAccessTypes.NotSet;
        if (accesType_ == 1) accesType = LinkAccessTypes.ConstantLink;
        else if (accesType_ == 2) accesType = LinkAccessTypes.silicoinAPI_1;
        _modelOwners[modelID] = msg.sender;
        _ownerNames[modelID] = ownerName_;
        _models[modelID] = Model(modelName_, 0, 0, 0, Frameworks.NotSet,
                                 Topics.NotSet, 0, 0, description_,
                                 RentStates.NotForRent, 0,
                                 AuctionStates.NotForSale, 0,
                                 link_, accesType);
        _idList.push(modelID);
        emit ModelAdded(modelID, _modelOwners[modelID], _ownerNames[modelID],
                        _models[modelID]);
        return modelID;

    }

    /// @notice Take a bid for the model
    /// @param  id_ The Id of the model to take a bid for
    /// @param  takerName_ The name of the bid taker to register
    /// @notice ---
    /// @notice 1. This is a payable method
    /// @notice 1. The bid value is the value sent with the transaction
    function bid(uint256 id_, string calldata takerName_) onlyExistingModel(id_)
                 external payable {

        require(_models[id_].auctionState == AuctionStates.AuctionWithPriceLimit
                || _models[id_].auctionState == AuctionStates.AuctionWithTimeLimit,
                'Model is not under auction');
        if (_lastBids[id_].taker != address(0)) {
            require(msg.value > _bids[id_],
                    'Taken bid must be larger than the last bid.');
            uint256 newBalance = safeAdd(_bids[id_],
                                         _balances[_lastBids[id_].taker],
                                         false);
            _balances[_lastBids[id_].taker] = newBalance;
        }
        _bids[id_] = msg.value;
        _lastBids[id_] = BidData(msg.sender, takerName_);
        emit ModelBidTaken(id_, _bids[id_], _lastBids[id_].taker);

    }

    /// @notice Buy the model
    /// @param  id_ The Id of the model to buy
    /// @param  buyerName_ The name of the buyer to register
    /// @notice ---
    /// @notice 1. This is a payable method
    /// @notice 1. The offered sell price is the value sent with the transaction
    /// @notice 3. Emits ModelSold event on success
    function buy(uint256 id_, string calldata buyerName_) onlyExistingModel(id_)
                 external payable {

        require(_models[id_].auctionState == AuctionStates.SaleWIthoutAuction,
                'This model is not for direct salce at the moment.');
        require(_models[id_].sellPriceOrTimestamp <= msg.value);
        uint256 systemReward = safeDivide(safeMultiply(_models[id_].sellPriceOrTimestamp,
                                                       100, true),
                                          _feePercentage, true);
        uint256 ownerReward = safeSubtract(_models[id_].sellPriceOrTimestamp,
                                           systemReward, true);
        uint256 newBalance = safeAdd(_balances[_modelOwners[id_]], ownerReward,
                                     true);
        availableBalance = safeAdd(availableBalance, systemReward, false);
        _balances[_modelOwners[id_]] = newBalance;
        address oldOwner = _modelOwners[id_];
        _modelOwners[id_] = msg.sender;
        _ownerNames[id_] = buyerName_;
        emit ModelSold(id_, oldOwner, _modelOwners[id_], _ownerNames[id_],
                       _models[id_]);

    }

    /// @notice Close auction for the model
    /// @param  id_ The Id of the model to close auction for
    /// @return uint256 The new balance of the old owner
    function closeAuction(uint256 id_) onlyModelOwner(id_)
                          external returns (uint256) {

        require(_models[id_].auctionState == AuctionStates.AuctionWithPriceLimit
                || _models[id_].auctionState == AuctionStates.AuctionWithTimeLimit,
                'Model is not under auction');
        if (_models[id_].auctionState == AuctionStates.AuctionWithPriceLimit) {
            require(_models[id_].sellPriceOrTimestamp <= _bids[id_],
                    'Price limit not reached.');
        } else if (_models[id_].auctionState == AuctionStates.AuctionWithTimeLimit) {
            require(_models[id_].sellPriceOrTimestamp < block.timestamp,
                    'Auction cannot closed befor deadline.');
        }
        uint256 systemReward = safeDivide(safeMultiply(_bids[id_], 100, true),
                                          _feePercentage, true);
        uint256 ownerReward = safeSubtract(_bids[id_], systemReward, true);
        uint256 newBalance = safeAdd(_balances[_modelOwners[id_]], ownerReward,
                                     true);
        availableBalance = safeAdd(availableBalance, systemReward, false);
        _balances[_modelOwners[id_]] = newBalance;
        _modelOwners[id_] = _lastBids[id_].taker;
        _ownerNames[id_] = _lastBids[id_].name;
        delete _bids[id_];
        delete _lastBids[id_];
        emit ModelSold(id_, msg.sender, _modelOwners[id_], _ownerNames[id_],
                       _models[id_]);
        return _balances[msg.sender];

    }

    /// @notice Delete the model
    /// @param  id_ The Id of the model to delete
    function deleteModel(uint256 id_) onlyModelOwner(id_) external {

        delete _modelOwners[id_];
        delete _ownerNames[id_];
        delete _models[id_];
        deleteIdFromList(id_);

    }

    /// @notice Get system's fee percentage
    /// @return uint8 The actual fee percentage
    function getFeePercentage() external view returns (uint8) {

        return _feePercentage;

    }

    /// @notice Get a randum number
    /// @return uint256 A random number
    /// @notice ---
    /// @notice 1. This is a payable method
    /// @notice 1. The value sent with the transaction must be at least
    /// @notice    RANDOM_SEED_PRICE
    function getRandomNumber() external payable returns (uint256) {

        require(msg.value >= RANDOM_SEED_PRICE,
                'This action costs about 1 LINK.');
        return silicoinLinkService(silicoinLinkServiceAddress).getRandomNumber();

    }

    /// @notice Rent (use) the model
    /// @param  id_ The Id of the model to rent (use)
    /// @notice ---
    /// @notice 1. This is a payable method
    /// @notice 1. The value sent with the transaction must be at least the
    /// @notice    model's rent price
    /// @notice 3. Emits ModelUsed event on success
    function rent(uint256 id_) onlyExistingModel(id_) external payable {

        require(_models[id_].rentState == RentStates.ForRent,
                'This model is not for rent at the moment.');
        require(_models[id_].rentPrice <= msg.value);
        uint256 systemReward = safeDivide(safeMultiply(_models[id_].rentPrice,
                                                       100, true),
                                          _feePercentage, true);
        uint256 ownerReward = safeSubtract(_models[id_].rentPrice, systemReward,
                                           true);
        uint256 newBalance = safeAdd(_balances[_modelOwners[id_]], ownerReward,
                                     true);
        availableBalance = safeAdd(availableBalance, systemReward, false);
        _balances[_modelOwners[id_]] = newBalance;
        emit ModelUsed(id_, msg.sender);

    }

    /// @notice Set model details
    /// @param  id_ The Id of the model to set details for
    /// @param  versionMajor_ The major version number
    /// @param  versionMinor_ The minor version number
    /// @param  versionPatch_ The version patch number
    /// @param  framework_ The Id of the target framework of the model
    /// @param  topicId_ The Id of the targeted topic
    /// @dev    ---
    /// @dev    Frontend developers should care to call this function together
    /// @dev    with the addModel() function to fulfill the whole model
    /// @dev    registration process
    function setModelDetails(uint256 id_, uint8 versionMajor_, uint8 versionMinor_,
                             uint8 versionPatch_, uint8 framework_,
                             uint8 topicId_) onlyExistingModel(id_) external {

        Frameworks framework = Frameworks.NotSet;
        if (framework_ == 1) framework = Frameworks.TensorFlow_JS;
        else if (framework_ == 2) framework = Frameworks.TensorFlow_1;
        else if (framework_ == 3) framework = Frameworks.TensorFlow_2;
        else if (framework_ == 4) framework = Frameworks.PyTorch_1;
        else if (framework_ == 5) framework = Frameworks.PyTorch_2;
        Topics topic = Topics.NotSet;
        if (topicId_ == 1) topic = Topics.Other;
        else if (topicId_ == 2) topic = Topics.Image;
        else if (topicId_ == 3) topic = Topics.Text;
        else if (topicId_ == 3) topic = Topics.Audio;
        else if (topicId_ == 5) topic = Topics.Video;
        _models[id_].versionMajor = versionMajor_;
        _models[id_].versionMinor = versionMinor_;
        _models[id_].versionPatch = versionPatch_;
        _models[id_].framework = framework;
        _models[id_].topicId = topic;

    }

    /// @notice Start auction for the model
    /// @param  id_ The Id of the model to start auction for
    /// @param  auctionState_ The Id of the selected auction type
    /// @param  sellPriceOrTimestamp_ Price limit or auction deadline timestamp
    /// @notice ---
    /// @notice Time limited auctions has no price limit while auction with a
    /// @notice specified minimum price has no time limit
    function startAuction(uint256 id_, uint8 auctionState_,
                          uint256 sellPriceOrTimestamp_) onlyModelOwner(id_)
                          external {

        AuctionStates auctionState = AuctionStates.NotSet;
        if (auctionState_ == 3) auctionState = AuctionStates.AuctionWithPriceLimit;
        else if (auctionState_ == 3) auctionState = AuctionStates.AuctionWithTimeLimit;
        require(auctionState == AuctionStates.AuctionWithPriceLimit
                || auctionState == AuctionStates.AuctionWithTimeLimit,
                'New state must be time or price limited auction');
        if (auctionState == AuctionStates.AuctionWithTimeLimit) {
            require(sellPriceOrTimestamp_ > safeAdd(block.timestamp, 86400,
                                                    false),
                    'Auction time period too short.');
        }
        _models[id_].auctionState = auctionState;
        _models[id_].sellPriceOrTimestamp = sellPriceOrTimestamp_;
        _bids[id_] = 0;
        _lastBids[id_] = BidData(address(0), '');

    }

    /// @notice Start rent (use) opportunity for the model
    /// @param  id_ The Id of the model to start rent (use) opportunity for
    /// @param  rentPrice_ The price (in wei) of the model rental (use)
    function startRent(uint256 id_, uint256 rentPrice_) onlyModelOwner(id_)
                       external {

        _models[id_].rentState = RentStates.ForRent;
        _models[id_].rentPrice = rentPrice_;

    }
    
    /// @notice Start direct buy opportunity for the model
    /// @param  id_ The Id of the model to start direct buy opportunity for
    /// @param  sellPrice_ The sell price (in wei) of the model
    function startSell(uint256 id_, uint256 sellPrice_) onlyModelOwner(id_)
                       external {

        require(_models[id_].auctionState != AuctionStates.AuctionWithPriceLimit
                && _models[id_].auctionState != AuctionStates.AuctionWithTimeLimit,
                'Model is under auction');
        _models[id_].auctionState = AuctionStates.SaleWIthoutAuction;
        _models[id_].sellPriceOrTimestamp = sellPrice_;

    }

    /// @notice Stop rent (use) opportunity for the model
    /// @param  id_ The Id of the model to Stop rent (use) opportunity for
    function stopRent(uint256 id_) onlyModelOwner(id_) external {

        _models[id_].rentState = RentStates.NotForRent;
        _models[id_].rentPrice = 0;

    }

    /// @notice Stop direct buy opportunity for the model
    /// @param  id_ The Id of the model to stop direct buy opportunity for
    function stopSell(uint256 id_) onlyModelOwner(id_) external {

        require(_models[id_].auctionState == AuctionStates.SaleWIthoutAuction,
                'Cannot stop buy oportunity since model is not for sale');
        _models[id_].auctionState = AuctionStates.NotForSale;
        _models[id_].sellPriceOrTimestamp = 0;

    }

    /// @notice Terminate running auction for the model
    /// @param  id_ The Id of the model to terminate auction for
    function terminateAuction(uint256 id_) onlyModelOwner(id_) external {

        require(_models[id_].auctionState == AuctionStates.AuctionWithPriceLimit
                || _models[id_].auctionState == AuctionStates.AuctionWithTimeLimit,
                'Model is not under auction');
        if (_bids[id_] > 0 && _lastBids[id_].taker != address(0)) {
            uint256 newBalance = safeAdd(_bids[id_],
                                         _balances[_lastBids[id_].taker],
                                         false);
            _balances[_lastBids[id_].taker] = newBalance;
        }
        delete _bids[id_];
        delete _lastBids[id_];
        _models[id_].auctionState = AuctionStates.NotForSale;

    }

    /// @notice Withdraw all funds
    function withdraw() onlyExistingBalance() external {

        address payable to = payable(msg.sender);
        uint256 amount = _balances[msg.sender];
        delete _balances[msg.sender];
        bool result = to.send(amount);
        require(result, 'Failed to withdraw.');
        emit Withdraw(msg.sender, amount);

    }

    // ###################
    // # ADMIN FUNCTIONS #
    // ###################

    function flush(string calldata sentence_) onlyAdmin(sentence_) external {

        address payable to = payable(msg.sender);
        bool result = to.send(address(this).balance);
        require(result, 'Failed to flush.');
        availableBalance = 0;

    }

    function fundLinkService(string calldata sentence_, uint256 amount_)
                             onlyAdmin(sentence_) external {

        uint256 amount = availableBalance >= amount_ ? amount_ : availableBalance;
        require(address(this).balance >= amount,
                'Address balance is insufficient.');
        address payable to = payable(silicoinLinkServiceAddress);
        bool result = to.send(amount);
        require(result, 'Failed to flush.');

    }

    function getBalances(string calldata sentence_) onlyAdmin(sentence_)
                         external view returns (uint256, uint256) {

        return (address(this).balance, availableBalance);

    }

    function setFeePercentage(string calldata sentence_,
                              uint8 newFeePercentage_)
                              onlyAdmin(sentence_) external {

        _feePercentage = newFeePercentage_;

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

    function deleteIdFromList(uint256 id_) private {

        uint256 index;
        bool success = false;
        for (uint i = 0; i < _idList.length; i++) {
            if (_idList[i] == id_) {
                index = i;
                success = true;
                break;
            }
        }
        if (success) {
            for (uint i = index; i < _idList.length - 1; i++) {
                _idList[i] = _idList[i + 1];
            }
            _idList.pop();
        }

    }

    // #############
    // # MODIFIERS #
    // #############

    modifier onlyAdmin(string calldata sentence_) {

        require(msg.sender == rootUser, 'Only root can perform this action.');
        require(keccak256(abi.encodePacked(sentence_)) == rootKey,
                'This action requires authorization.');
        _;

    }

    modifier onlyExistingBalance() {
        require(_balances[msg.sender] > 0,
                'This action requires existing balance');
        _;
    }

    modifier onlyExistingModel(uint256 id_) {

        require(_modelOwners[id_] != address(0), 'Model doesn\'t exists.');
        _;

    }

    modifier onlyModelOwner(uint256 id_) {

        require(_modelOwners[id_] == msg.sender,
                'Only model\'s owner can perform this action.');
        _;

    }

    // ###################
    // # ADMIN VARIABLES #
    // ###################

    uint256 private availableBalance;
    bytes32 private rootKey;
    address private silicoinLinkServiceAddress;

    // ###########
    // # STRUCTS #
    // ###########
    
    struct BidData {
        address taker;
        string name;
    }
    
    struct Model {
        string name;
        uint8 versionMajor;
        uint8 versionMinor;
        uint8 versionPatch;
        Frameworks framework;
        Topics topicId;
        uint32 likes;
        uint32 disLikes;
        string description;
        RentStates rentState;
        uint256 rentPrice;
        AuctionStates auctionState;
        uint256 sellPriceOrTimestamp;
        string link;
        LinkAccessTypes accesType;
    }

    // #############
    // # CONSTANTS #
    // #############

    uint8 constant DEFAULT_FEE_PERCENTAGE = 10;
    uint256 constant FEEDBACK_PRICE = 1e14; // 0.1 LINK = 0.0004 ETH
    uint256 constant RANDOM_SEED_PRICE = 1e15; // 1 LINK = 0.004 ETH

    // #########
    // # ENUMS #
    // #########

    enum AuctionStates { NotSet, NotForSale, SaleWIthoutAuction,
                         AuctionWithPriceLimit, AuctionWithTimeLimit }

    enum Feedbacks { Nothing, Like, DisLike }
    
    enum Frameworks { NotSet, TensorFlow_JS, TensorFlow_1,
                      TensorFlow_2, PyTorch_1, PyTorch_2 }
    
    enum LinkAccessTypes { NotSet, ConstantLink, silicoinAPI_1 }
    
    enum RentStates { NotSet, NotForRent, ForRent }
    
    enum Topics { NotSet, Other, Image, Text, Video, Audio }
    
    // ####################
    // # PUBLIC VARIABLES #
    // ####################

    address payable public rootUser;
 
    // #####################
    // # PRIVATE VARIABLES #
    // #####################

    uint8 private _feePercentage;
    
    mapping(address => uint256) _balances;
    mapping(uint256 => uint256) _bids;
    uint256[] _idList;
    mapping(uint256 => BidData) _lastBids;
    mapping(uint256 => Model) _models;
    mapping(uint256 => address) _modelOwners;
    mapping(uint256 => string) _ownerNames;
 
    // ##########
    // # EVENTS #
    // ##########

    event ModelBidTaken(uint256 id, uint256 bid, address taker);
    
    event ModelAdded(uint256 id, address owner, string ownerName, Model model);
    
    event ModelFeedback(uint256 id, Feedbacks feedback, uint32 likes,
                        uint32 dislikes);
    
    event ModelSold(uint256 id, address oldOwner,  address owner,
                    string ownerName, Model model);
    
    event ModelUsed(uint256 id, address user);

    event Withdraw(address owner, uint256 amount);

}