// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract MockNFTDex is
  ReentrancyGuard,
  Ownable,
  IERC721Receiver,
  ERC1155Holder,
  ERC721Holder
{
  using EnumerableSet for EnumerableSet.UintSet;
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 public feeBps;
  mapping(address => mapping(address => EnumerableSet.UintSet))
    private myTokenIdSet; // user address => nft address => id
  mapping(address => EnumerableSet.AddressSet) private myNFTSet; // user address => nft adress

  EnumerableSet.AddressSet private nftSet;
  mapping(address => EnumerableSet.UintSet) private tokenIdSet;

  mapping(address => mapping(uint256 => uint256)) public prices; // nft => tokenId => price
  mapping(uint256 => mapping(address => address)) public listers; // tokenId => nft => lister

  event List(
    address indexed nft,
    uint256 indexed id,
    address indexed lister,
    uint256 price
  );
  event Unlist(address indexed nft, uint256 indexed id, address indexed lister);
  event Buy(
    address nft,
    uint256 indexed id,
    address indexed seller,
    address indexed buyer,
    uint256 price,
    uint256 fee
  );
  event SetFeeBps(uint256 feeBps);

  constructor(uint256 _feeBps) public {
    feeBps = _feeBps;

    emit SetFeeBps(_feeBps);
  }

  /// @dev Updates fee. Only callable by owner.
  function setFeeBps(uint256 _feeBps) external onlyOwner {
    feeBps = _feeBps;
    emit SetFeeBps(_feeBps);
  }

  /// @dev Lists the given summoner. This contract will take custody until bought / unlisted.
  function list(
    address nft,
    uint256 tokenId,
    uint256 price
  ) external nonReentrant {
    require(price > 0, "bad price");
    require(prices[nft][tokenId] == 0, "already listed");
    IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);
    prices[nft][tokenId] = price;
    listers[tokenId][nft] = msg.sender;
    nftSet.add(nft);
    tokenIdSet[nft].add(tokenId);
    myTokenIdSet[msg.sender][nft].add(tokenId);
    myNFTSet[msg.sender].add(nft);
    emit List(nft, tokenId, msg.sender, price);
  }

  /// @dev Unlists the given summoner. Must be the lister.
  function unlist(address nft, uint256 tokenId) external nonReentrant {
    require(prices[nft][tokenId] > 0, "not listed");
    require(listers[tokenId][nft] == msg.sender, "not lister");
    prices[nft][tokenId] = 0;
    listers[tokenId][nft] = address(0);
    IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);
    nftSet.remove(nft);
    tokenIdSet[nft].remove(tokenId);
    myTokenIdSet[msg.sender][nft].remove(tokenId);
    myNFTSet[msg.sender].remove(nft);
    emit Unlist(nft, tokenId, msg.sender);
  }

  /// @dev Buys the given summoner. Must pay the exact correct prirce.
  function buy(address nft, uint256 tokenId) external payable nonReentrant {
    uint256 price = prices[nft][tokenId];
    require(price > 0, "not listed");
    require(msg.value == price, "bad msg.value");
    uint256 fee = (price * feeBps) / 10000;
    uint256 get = price - fee;
    address lister = listers[tokenId][nft];
    prices[nft][tokenId] = 0;
    listers[tokenId][nft] = address(0);
    IERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);
    payable(lister).transfer(get);
    nftSet.remove(nft);
    tokenIdSet[nft].remove(tokenId);
    myTokenIdSet[msg.sender][nft].remove(tokenId);
    myNFTSet[msg.sender].remove(nft);
    emit Buy(nft, tokenId, lister, msg.sender, price, fee);
  }

  /// @dev Withdraw trading fees. Only called by owner.
  function withdraw(uint256 amount) external onlyOwner {
    payable(msg.sender).transfer(amount == 0 ? address(this).balance : amount);
  }

  /// @dev Returns list the total number of listed nft.
  function nftListLength() external view returns (uint256) {
    return nftSet.length();
  }

  /// @dev Returns list the total number of listed tokenId.
  function tokenIdListLength(address nft) external view returns (uint256) {
    return tokenIdSet[nft].length();
  }

  /// @dev Returns list the total number of listed nft of the given user.
  function myNFTListLength(address user) external view returns (uint256) {
    return myNFTSet[msg.sender].length();
  }

  /// @dev Returns list the total number of listed nft of the given user.
  function myListLength(address user, address nft)
    external
    view
    returns (uint256)
  {
    return myTokenIdSet[msg.sender][nft].length();
  }
}
