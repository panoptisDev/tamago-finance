// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IFactory.sol";
import "../interfaces/IRegistry.sol";

contract NFTSwapPair is
  Ownable,
  ReentrancyGuard,
  IERC721Receiver,
  ERC165,
  ERC721Holder,
  ERC1155Holder
{
  using SafeMath for uint256;

  enum ContractState {
    INITIAL,
    NORMAL,
    EMERGENCY,
    EXPIRED
  }

  // Contract state
  ContractState public state;
  string public name;
  string public symbol;

  IRegistry public registry;

  struct Token {
    address assetAddress;
    uint256 tokenId;
    bool is1155;
  }

  Token public token0; // always ERC1155
  Token[] public token1;

  mapping(uint256 => address) public providers;
  uint256 public providerCount;
  uint256 public providerPaidCount;

  mapping(address => uint256) public balanceOf;
  uint256 public totalSupply;
  uint8 public constant decimals = 1;
  bytes32 private constant FACTORY =
    0x464143544f525900000000000000000000000000000000000000000000000000;
  uint8 public MINIMUM_LIQUIDITY = 2;
  uint256 public COOLDOWN = 3 minutes;
  mapping(address => uint256) public timestamps;
  uint256 private nonce;

  event Minted(
    address _recipientAddress,
    address _tokenAddress,
    uint256 _tokenId,
    bool _is1155
  );
  event Burnt(
    address _recipientAddress,
    address _tokenAddress,
    uint256 _tokenId,
    bool _is1155
  );
  event Swapped(
    address _recipientAddress,
    address _fromTokenAddress,
    uint256 _fromTokenId,
    bool _fromTokenIs1155,
    address _toTokenAddress,
    uint256 _toTokenId,
    bool _toTokenIs1155
  );

  constructor(
    string memory _name,
    string memory _symbol,
    address _token0Address,
    uint256 _token0Id,
    address _registry
  ) public {
    name = _name;
    symbol = _symbol;
    state = ContractState.NORMAL;

    // setup token0
    token0.assetAddress = _token0Address;
    token0.tokenId = _token0Id;
    token0.is1155 = true;

    registry = IRegistry(_registry);

    _registerInterface(IERC721Receiver.onERC721Received.selector);
  }

  function mint(
    address _to,
    address _token1Address,
    uint256 _token1Id,
    bool _token1Is1155
  ) public nonReentrant isReady {
    // take the token0's NFT
    IERC1155(token0.assetAddress).safeTransferFrom(
      msg.sender,
      address(this),
      token0.tokenId,
      1,
      "0x00"
    );

    providers[providerCount] = _to;
    providerCount += 1;

    // take the token1's NFT
    if (_token1Is1155) {
      IERC1155(_token1Address).safeTransferFrom(
        msg.sender,
        address(this),
        _token1Id,
        1,
        "0x00"
      );
    } else {
      IERC721(_token1Address).safeTransferFrom(
        msg.sender,
        address(this),
        _token1Id
      );
    }

    token1.push(
      Token({
        assetAddress: _token1Address,
        tokenId: _token1Id,
        is1155: _token1Is1155
      })
    );

    // create a position for the given address
    _createPosition(_to);

    emit Minted(_to, _token1Address, _token1Id, _token1Is1155);
  }

  // burn will return only token1's NFT
  function burn(address _to) public nonReentrant isReady {
    require(token1.length > 0, "No any NFT locked in the contract");

    uint256 idToRemoved = _propose();

    // return token0's NFT to the earliest provider
    _release();

    // return token1's NFT
    if (token1[idToRemoved].is1155) {
      IERC1155(token1[idToRemoved].assetAddress).safeTransferFrom(
        address(this),
        _to,
        token1[idToRemoved].tokenId,
        1,
        "0x00"
      );
    } else {
      IERC721(token1[idToRemoved].assetAddress).safeTransferFrom(
        address(this),
        _to,
        token1[idToRemoved].tokenId
      );
    }

    emit Burnt(
      _to,
      token1[idToRemoved].assetAddress,
      token1[idToRemoved].tokenId,
      token1[idToRemoved].is1155
    );

    // if the number generated not equals the last
    if (idToRemoved != (token1.length - 1)) {
      token1[idToRemoved] = token1[token1.length - 1];
    }

    // remove the last and reduce the array size
    token1.pop();

    _removePosition(_to);
  }

  function swap(
    address _to,
    address _token1Address,
    uint256 _token1Id,
    bool _token1Is1155
  ) public nonReentrant isReady {
    uint256 idToRemoved = _propose();

    _swap(idToRemoved, _to, _token1Address, _token1Id, _token1Is1155);
  }

  function token1Length() public view returns (uint256) {
    return token1.length;
  }

  // can be executed by gateway contract
  function forceSwap(
    uint256 _id,
    address _to,
    address _token1Address,
    uint256 _token1Id,
    bool _token1Is1155
  ) public nonReentrant isReady onlyOwner {
    require(token1.length > _id, "Given id is invalid");

    _swap(_id, _to, _token1Address, _token1Id, _token1Is1155);
  }

  function increaseNonce() public nonReentrant onlyOwner {
    nonce += 1;
  }

  // owner can skip the queue
  function skip(uint256 _value) public nonReentrant onlyOwner {
    require(providerCount >= providerPaidCount.add(_value), "Invalid value");
    providerPaidCount += _value;
  }

  function setMinimumLiquidity(uint8 _value) public nonReentrant onlyOwner {
    require(_value != 0, "Invalid value");
    MINIMUM_LIQUIDITY = _value;
  }

  function setCooldown(uint256 _value) public nonReentrant onlyOwner {
    COOLDOWN = _value;
  }

  // update the contract state
  function setContractState(ContractState _state)
    public
    nonReentrant
    onlyOwner
  {
    state = _state;
  }

  modifier isReady() {
    require((state) == ContractState.NORMAL, "Contract state is not ready");
    _;
  }

  function _propose() internal view returns (uint256) {
    uint256 randomNonce = nonce;

    if (registry.getContractAddress(FACTORY) != address(0)) {
      IFactory factory = IFactory(registry.getContractAddress(FACTORY));
      randomNonce = factory.randomNonce();
    }

    uint256 randomNumber = uint256(
      keccak256(abi.encodePacked(now, msg.sender, randomNonce, address(this)))
    );

    return randomNumber.mod(token1.length);
  }

  function _swap(
    uint256 _idToRemoved,
    address _to,
    address _token1Address,
    uint256 _token1Id,
    bool _token1Is1155
  ) internal {
    require(
      token1.length > 0,
      "No. NFTs deposited less than MINIMUM_LIQUIDITY"
    );
    require(
      block.timestamp >= timestamps[_to] + COOLDOWN,
      "Given recipient address still in cooldown period"
    );

    // taking the token0's NFT
    IERC1155(token0.assetAddress).safeTransferFrom(
      msg.sender,
      address(this),
      token0.tokenId,
      1,
      "0x00"
    );

    providers[providerCount] = _to;
    providerCount += 1;

    // return token0's NFT to the earliest provider
    _release();

    // taking the token1's NFT
    if (_token1Is1155) {
      IERC1155(_token1Address).safeTransferFrom(
        msg.sender,
        address(this),
        _token1Id,
        1,
        "0x00"
      );
    } else {
      IERC721(_token1Address).safeTransferFrom(
        msg.sender,
        address(this),
        _token1Id
      );
    }

    // returning
    if (token1[_idToRemoved].is1155) {
      IERC1155(token1[_idToRemoved].assetAddress).safeTransferFrom(
        address(this),
        _to,
        token1[_idToRemoved].tokenId,
        1,
        "0x00"
      );
    } else {
      IERC721(token1[_idToRemoved].assetAddress).safeTransferFrom(
        address(this),
        _to,
        token1[_idToRemoved].tokenId
      );
    }

    emit Swapped(
      _to,
      _token1Address,
      _token1Id,
      _token1Is1155,
      token1[_idToRemoved].assetAddress,
      token1[_idToRemoved].tokenId,
      token1[_idToRemoved].is1155
    );

    token1[_idToRemoved].assetAddress = _token1Address;
    token1[_idToRemoved].tokenId = _token1Id;
    token1[_idToRemoved].is1155 = _token1Is1155;

    timestamps[_to] = block.timestamp;
  }

  function _release() internal {
    if (providerCount.sub(providerPaidCount) > 0) {
      IERC1155(token0.assetAddress).safeTransferFrom(
        address(this),
        providers[providerPaidCount],
        token0.tokenId,
        1,
        "0x00"
      );
      providerPaidCount += 1;
    }
  }

  function _createPosition(address _address) internal {
    balanceOf[_address] += 1;
    totalSupply += 1;
  }

  function _removePosition(address _address) internal {
    require(totalSupply != 0, "The total supply is zero");
    require(balanceOf[_address] != 0, "The given address has no balance");
    balanceOf[_address] -= 1;
    totalSupply -= 1;
  }
}
