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
import "./MockERC721.sol";

contract MockP2P is
  ReentrancyGuard,
  Ownable,
  IERC721Receiver,
  ERC1155Holder,
  ERC721Holder
{
  uint256 public feeBps;
  uint256 public price;
  MockERC721 public nft;

  event Swap(address indexed buyer, uint256 tokenId);
  event SetPrice(uint256 price);

  constructor(
    uint256 _price,
    string memory _name,
    string memory _symbol
  ) public {
    price = _price;

    nft = new MockERC721(_name, _symbol);

    emit SetPrice(_price);
  }

  /// @dev Updates price. Only callable by owner.
  function setPrice(uint256 _price) external onlyOwner {
    price = _price;
    emit SetPrice(_price);
  }

  /// @dev Withdraw trading fees. Only called by owner.
  function withdraw(uint256 amount) external onlyOwner {
    payable(msg.sender).transfer(amount == 0 ? address(this).balance : amount);
  }

  /// @dev Buy nft from the contract.
  function buy() external payable nonReentrant {
    require(msg.value == price, "!not enough or more over");
    uint256 tokenId = nft.totalSupply();
    nft.mint(msg.sender, tokenId);

    emit Swap(msg.sender, tokenId);
  }
}
