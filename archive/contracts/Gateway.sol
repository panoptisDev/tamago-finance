// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "./NFTMarketplace.sol";

/**
 * @title Gateway Contract
 */

contract Gateway is ReentrancyGuard, NFTMarketplace {
    using Address for address;

    struct RelayMessage {
        bytes32 root;
        address relayer;
        uint256 timestamp;
    }

    struct ClearingMessage {
        bytes32 root;
        address validator;
        uint256 timestamp;
    }

    struct PartialOrder {
        bool active;
        bool ended;
        address buyer;
        address assetAddress;
        uint256 tokenIdOrAmount;
        TokenType tokenType;
    }

    // Chain ID
    uint256 public chainId;
    // Each message contains Merkle Tree's root of all orders listed from all EVM chains
    mapping(uint256 => RelayMessage) public messages;
    uint256 public messageCount;
    // Clearance messages contains the hash
    mapping(uint256 => ClearingMessage) public clearances;
    uint256 public clearanceCount;

    // Orders that have been partially fulfilled (orderId -> struct)
    mapping(uint256 => PartialOrder) public outstandings;

    event PartialSwapped(uint256 indexed orderId, address fromAddress);
    event Claimed(uint256 indexed orderId, address fromAddress, bool isOriginChain);

    constructor(address _devAddress) public NFTMarketplace(_devAddress) {
        chainId = _getCurrentChainID();
    }

    /// @notice check whether the buyer can swap the NFT against given order ID
    /// @param _orderId ID for the order
    /// @param _assetAddress NFT or ERC20 contract address want to swap
    /// @param _tokenIdOrAmount NFT's token ID or ERC20 token amount want to swap
    /// @param _proof the proof generated from off-chain
    function eligibleToPartialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) external view returns (bool) {
        return
            _eligibleToPartialSwap(
                _orderId,
                _assetAddress,
                _tokenIdOrAmount,
                _proof
            );
    }

    /// @notice check whether the caller can claim tokens from the given order
    /// @param _orderId ID for the order
    /// @param _claimer NFT or ERC20 contract address want to swap
    /// @param _isOriginChain represents whether it's on source chain or destination chain
    /// @param _proof the proof generated from off-chain
    function eligibleToClaim(
        uint256 _orderId,
        address _claimer,
        bool _isOriginChain,
        bytes32[] memory _proof
    ) external view returns (bool) {
        return _eligibleToClaim(_orderId, _claimer, _isOriginChain, _proof);
    }

    /// @notice claim the NFT 
    /// @param _orderId ID for the order
    /// @param _isOriginChain represents whether it's on source chain or destination chain
    /// @param _proof the proof generated from off-chain
    function claim(
        uint256 _orderId,
        bool _isOriginChain,
        bytes32[] memory _proof
    ) external nonReentrant {
        require(
            _eligibleToClaim(_orderId, msg.sender, _isOriginChain, _proof) ==
                true,
            "The caller is not eligible to claim the NFT"
        );

        // giving NFT
        if (_isOriginChain == true) {
            require( orders[_orderId].isCrosschain == true, "The order must set to be crosschain enabled"  );
            TokenType nftType = TokenType.ERC721;
            if (orders[_orderId].is1155 == true) {
                nftType = TokenType.ERC1155;
            }
            _give(
                orders[_orderId].assetAddress,
                orders[_orderId].tokenId,
                nftType,
                msg.sender
            );

            orders[_orderId].ended = true;
        } else {
            _give(
                outstandings[_orderId].assetAddress,
                outstandings[_orderId].tokenIdOrAmount,
                outstandings[_orderId].tokenType,
                msg.sender
            );

            outstandings[_orderId].ended = true;
        }

        emit Claimed( _orderId, msg.sender, _isOriginChain );
    }

    /// @notice deposit the NFT on destination chain, later the validator will check and allow the buyer to claim on the source chain 
    /// @param _orderId ID for the order
    /// @param _assetAddress NFT's contract address to be deposited
    /// @param _tokenIdOrAmount NFT's token ID or ERC-20 amount to be deposited
    /// @param _type type of token to be deposited
    /// @param _proof proof generated from off-chain
    function partialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        bytes32[] memory _proof
    ) external whenNotPaused nonReentrant {
        _partialSwap(_orderId, _assetAddress, _tokenIdOrAmount, _type, _proof);

        emit PartialSwapped(_orderId, msg.sender);
    }

    // override the chain ID
    function setChainId(uint256 _value) external onlyAdmin {
        chainId = _value;
    }

    // attaches the all order data in hash
    function attachRelayMessage(bytes32 _root)
        external
        onlyRelayer
        nonReentrant
    {
        messageCount += 1;
        messages[messageCount].root = _root;
        messages[messageCount].relayer = msg.sender;
        messages[messageCount].timestamp = now;
    }

    // attaches the confirmation in hash
    function attachClearanceMessage(bytes32 _root)
        external
        onlyValidator
        nonReentrant
    {
        clearanceCount += 1;
        clearances[clearanceCount].root = _root;
        clearances[clearanceCount].validator = msg.sender;
        clearances[clearanceCount].timestamp = now;
    }

    // cancel the order
    function cancelPartialSwapOrder(uint256 _orderId, address _to)
        external
        onlyAdmin
        nonReentrant
    {
        require(outstandings[_orderId].active == true, "Invalid order");

        _give(
            outstandings[_orderId].assetAddress,
            outstandings[_orderId].tokenIdOrAmount,
            outstandings[_orderId].tokenType,
            _to
        );

        outstandings[_orderId].active = false;
    }

    // INTERNAL FUNCTIONS

    function _getCurrentChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function _partialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        bytes32[] memory _proof
    ) internal {
        require(
            outstandings[_orderId].active == false,
            "The order is already active"
        );
        require(
            _eligibleToPartialSwap(
                _orderId,
                _assetAddress,
                _tokenIdOrAmount,
                _proof
            ) == true,
            "The caller is not eligible to claim the NFT"
        );

        // deposit NFT or tokens until the NFT locked in the origin chain is being transfered to the buyer
        _take(_assetAddress, _tokenIdOrAmount, _type, address(this));

        outstandings[_orderId].active = true;
        outstandings[_orderId].buyer = msg.sender;
        outstandings[_orderId].assetAddress = _assetAddress;
        outstandings[_orderId].tokenIdOrAmount = _tokenIdOrAmount;
        outstandings[_orderId].tokenType = _type;
    }

    function _eligibleToPartialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(
            abi.encodePacked(
                _orderId,
                chainId,
                _assetAddress,
                _tokenIdOrAmount
            )
        );
        bytes32 latestRoot = messages[messageCount].root;
        return MerkleProof.verify(_proof, latestRoot, leaf);
    }

    function _eligibleToClaim(
        uint256 _orderId,
        address _claimer,
        bool _isOriginChain,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(
            abi.encodePacked(
                _orderId,
                chainId,
                _claimer,
                _isOriginChain
            )
        );
        bytes32 latestRoot = clearances[clearanceCount].root;
        return MerkleProof.verify(_proof, latestRoot, leaf);
    }
}
