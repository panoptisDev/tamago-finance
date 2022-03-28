// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";

import "./utility/Whitelist.sol";

/**
 * @title Luckbox v.2
 * @dev A contract aims to help distribute NFTs for collectors to users who met the conditions
 */

contract LuckBox is
  Whitelist,
  ReentrancyGuard,
  IERC721Receiver,
  ERC165,
  ERC721Holder,
  ERC1155Holder
{
  using SafeMath for uint256;
  using Address for address;

  // POAP info
  struct Poap {
    address assetAddress;
    uint256 tokenId;
    bool is1155;
  }

  // Event Info
  struct Event {
    string name;
    uint256[] poaps;
    bytes32 merkleRoot; // to claim
    mapping(address => bool) claimed;
    uint256 claimCount;
    bool ended;
    bool active;
  }

  // Project Info
  struct Project {
    string name;
    bytes32 merkleRoot;
    uint256 timestamp;
    bool active;
  }

  // Poap Id => Poap
  mapping(uint256 => Poap) public poaps;
  // Event Id => Event
  mapping(uint256 => Event) public events;
  // Project Id => Project
  mapping(uint256 => Project) public projects;

  event EventCreated(uint256 indexed eventId, string name, uint256[] poaps);

  event PoapCreated(
    uint256 indexed poapId,
    address assetAddress,
    uint256 tokenId,
    bool is1155
  );

  event Deposited(
    address from,
    address assetAddress,
    uint256 tokenId,
    uint256 amount,
    bool is1155
  );

  event Claimed(
    address to,
    uint256 eventId,
    address assetAddress,
    uint256 tokenId,
    bool is1155
  );

  event ProjectCreated(uint256 indexed projectId, string name);

  event SetEndEvent(uint256 indexed projectId, bool isEnd);

  constructor() public {
    _registerInterface(IERC721Receiver.onERC721Received.selector);
  }

  /// @notice check whether the given address has held NFTs or not
  /// @param _projectId the project ID
  /// @param _address the wallet address that want to check
  /// @param _proof the proof generated off-chain
  /// @return output the result
  function eligible(
    uint256 _projectId,
    address _address,
    bytes32[] memory _proof
  ) public view returns (bool output) {
    output = _eligible(_projectId, _address, _proof);
  }

  /// @notice check whether the caller can claim a POAP NFT or not
  /// @param _eventId the event that the caller wants to claim the prize
  /// @param _poapId ID of the POAP NFT recorded on this contract
  /// @param _proof the proof generated off-chain
  /// @return output the result
  function checkClaim(
    uint256 _eventId,
    uint256 _poapId,
    bytes32[] memory _proof
  ) public view returns (bool output) {
    output = _checkClaim(_eventId, _poapId, _proof);
  }

  /// @notice claim the NFT if the caller is eligible for
  /// @param _eventId the event that the caller wants to claim the prize
  /// @param _poapId ID of the POAP NFT recorded on this contract
  /// @param _proof the proof generated off-chain
  function claim(
    uint256 _eventId,
    uint256 _poapId,
    bytes32[] memory _proof
  ) public nonReentrant {
    require(events[_eventId].active == true, "Given Event ID is invalid");
    require(events[_eventId].ended == false, "The event is ended");
    require(
      events[_eventId].claimed[msg.sender] == false,
      "The caller is already claimed"
    );
    require(
      _checkClaim(_eventId, _poapId, _proof) == true,
      "The caller is not eligible to claim the given poap"
    );

    if (poaps[_poapId].is1155) {
      IERC1155(poaps[_poapId].assetAddress).safeTransferFrom(
        address(this),
        msg.sender,
        poaps[_poapId].tokenId,
        1,
        "0x00"
      );
    } else {
      IERC721(poaps[_poapId].assetAddress).safeTransferFrom(
        address(this),
        msg.sender,
        poaps[_poapId].tokenId
      );
    }

    events[_eventId].claimed[msg.sender] = true;
    events[_eventId].claimCount += 1;

    emit Claimed(
      msg.sender,
      _eventId,
      poaps[_poapId].assetAddress,
      poaps[_poapId].tokenId,
      poaps[_poapId].is1155
    );
  }

  /// @notice deposit ERC-1155 NFT prior to the claim, ideally should be called by the event's owner
  /// @param _assetAddress the NFT asset address
  /// @param _tokenId the token ID on the NFT
  /// @param _amount the amount of NFT to be deposited
  function depositERC1155(
    address _assetAddress,
    uint256 _tokenId,
    uint256 _amount
  ) public nonReentrant {
    IERC1155(_assetAddress).safeTransferFrom(
      msg.sender,
      address(this),
      _tokenId,
      _amount,
      "0x00"
    );

    emit Deposited(msg.sender, _assetAddress, _tokenId, _amount, true);
  }

  /// @notice deposit ERC-721 NFT prior to the claim, ideally should be called by the event's owner
  /// @param _assetAddress the NFT asset address
  /// @param _tokenId the token ID on the NFT
  function depositERC721(address _assetAddress, uint256 _tokenId)
    public
    nonReentrant
  {
    IERC721(_assetAddress).safeTransferFrom(
      msg.sender,
      address(this),
      _tokenId
    );

    emit Deposited(msg.sender, _assetAddress, _tokenId, 1, false);
  }

  /// @notice create a record for POAP NFT which will be used during a claim period for mapping POAP ID <-> ASSET ADDRESS
  /// @param _poapId ID for the POAP
  /// @param _assetAddress the NFT asset address
  /// @param _tokenId the token ID on the NFT
  /// @param _is1155 ERC-1155 flags
  function createPoap(
    uint256 _poapId,
    address _assetAddress,
    uint256 _tokenId,
    bool _is1155
  ) public nonReentrant onlyWhitelisted {
    require(poaps[_poapId].assetAddress == address(0), "Given ID is occupied");

    poaps[_poapId].assetAddress = _assetAddress;
    poaps[_poapId].tokenId = _tokenId;
    poaps[_poapId].is1155 = _is1155;

    emit PoapCreated(_poapId, _assetAddress, _tokenId, _is1155);
  }

  /// @notice create a campaign
  /// @param _eventId ID for the event
  /// @param _name name of the event
  /// @param _poaps NFT that will be distributed
  function createEvent(
    uint256 _eventId,
    string memory _name,
    uint256[] memory _poaps
  ) public nonReentrant onlyWhitelisted {
    require(events[_eventId].active == false, "Given ID is occupied");

    events[_eventId].active = true;
    events[_eventId].name = _name;
    events[_eventId].poaps = _poaps;

    emit EventCreated(_eventId, _name, _poaps);
  }

  /// @notice create a project, once set it allows users to verify that they  having the project's NFTs in the wallet
  /// @param _projectId ID for the project
  /// @param _name name of the project
  function createProject(uint256 _projectId, string memory _name)
    public
    nonReentrant
    onlyWhitelisted
  {
    require(projects[_projectId].active == false, "Given ID is occupied");

    projects[_projectId].active = true;
    projects[_projectId].name = _name;

    emit ProjectCreated(_projectId, _name);
  }

  /// @notice upload the root of the proof identifies who will be able to claim the prizes
  /// @param _eventId ID for the event
  /// @param _merkleRoot the root of the proof to be uploaded
  function attachClaim(uint256 _eventId, bytes32 _merkleRoot)
    public
    nonReentrant
    onlyWhitelisted
  {
    require(events[_eventId].active == true, "Given ID is invalid");

    events[_eventId].merkleRoot = _merkleRoot;
  }

  /// @notice upload the root of the proof identifies who is holding the project's NFTs
  /// @param _projectId ID for the project
  /// @param _merkleRoot the root of the proof to be uploaded
  function attachWhitelist(uint256 _projectId, bytes32 _merkleRoot)
    public
    nonReentrant
    onlyWhitelisted
  {
    require(projects[_projectId].active == true, "Given ID is invalid");

    projects[_projectId].merkleRoot = _merkleRoot;
    projects[_projectId].timestamp = now;
  }

  /// @notice upload the root of the proof identifies who is holding the project's NFTs (in batch)
  /// @param _projectIds array of ID for the project
  /// @param _merkleRoots array of the root of the proof to be uploaded
  function attachWhitelistBatch(
    uint256[] memory _projectIds,
    bytes32[] memory _merkleRoots
  ) public nonReentrant onlyWhitelisted {
    require(
      _projectIds.length == _merkleRoots.length,
      "Array size is not the same length"
    );

    for (uint256 i = 0; i < _projectIds.length; i++) {
      projects[_projectIds[i]].merkleRoot = _merkleRoots[i];
      projects[_projectIds[i]].timestamp = now;
    }
  }

  /// @notice replace POAP NFTs to be distributed on the event
  /// @param _eventId ID of the event
  /// @param _poaps array of the POAP ID
  function updatePoaps(uint256 _eventId, uint256[] memory _poaps)
    public
    nonReentrant
    onlyWhitelisted
  {
    require(events[_eventId].active == true, "Given ID is invalid");

    events[_eventId].poaps = _poaps;
  }

  /// @notice withdraw ERC-1155 NFTs locked in the contract
  function emergencyWithdrawERC1155(
    address _to,
    address _tokenAddress,
    uint256 _tokenId,
    uint256 _amount
  ) public nonReentrant onlyWhitelisted {
    IERC1155(_tokenAddress).safeTransferFrom(
      address(this),
      _to,
      _tokenId,
      _amount,
      "0x00"
    );
  }

  /// @notice withdraw ERC-721 NFTs locked in the contract
  function emergencyWithdrawERC721(
    address _to,
    address _tokenAddress,
    uint256 _tokenId
  ) public nonReentrant onlyWhitelisted {
    IERC721(_tokenAddress).safeTransferFrom(address(this), _to, _tokenId);
  }

  /// @notice set end flag to event
  function setEndEvent(uint256 _eventId, bool _isEnd) external onlyWhitelisted {
    events[_eventId].ended = _isEnd;

    emit SetEndEvent(_eventId, _isEnd);
  }

  // PRIVATE FUNCTIONS

  function _checkClaim(
    uint256 _eventId,
    uint256 _poapId,
    bytes32[] memory _proof
  ) internal view returns (bool) {
    uint256 test = 1;
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _poapId));
    return MerkleProof.verify(_proof, events[_eventId].merkleRoot, leaf);
  }

  function _eligible(
    uint256 _projectId,
    address _address,
    bytes32[] memory _proof
  ) internal view returns (bool) {
    require(projects[_projectId].active == true, "Given ID is invalid");

    bytes32 leaf = keccak256(abi.encodePacked(_address));

    return MerkleProof.verify(_proof, projects[_projectId].merkleRoot, leaf);
  }
}
