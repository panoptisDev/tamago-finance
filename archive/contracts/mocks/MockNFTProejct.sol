//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../NFTLuckBoxV2/NFTLuckBoxV2Base.sol";

contract MockNFTProject is ERC721, NFTLuckBoxV2Base {
  constructor(
    string memory name,
    string memory symbol,
    address nftAddress,
    uint256 tokenId
  ) public ERC721(name, symbol) NFTLuckBoxV2Base(nftAddress, tokenId) {
    // Use CryptoKitties as a base URI for this mock collection
    _setBaseURI("https://api.cryptokitties.co/kitties/");
  }

  function exists(uint256 tokenId) public view returns (bool) {
    return _exists(tokenId);
  }

  function setTokenURI(uint256 tokenId, string memory uri) public {
    _setTokenURI(tokenId, uri);
  }

  function setBaseURI(string memory baseURI) public {
    _setBaseURI(baseURI);
  }

  function mint(address to, uint256 tokenId) public checkWhitelistAndTransfer {
    _mint(to, tokenId);
  }

  function safeMint(address to, uint256 tokenId) public {
    _safeMint(to, tokenId);
  }

  function safeMint(
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public {
    _safeMint(to, tokenId, _data);
  }

  function burn(uint256 tokenId) public {
    _burn(tokenId);
  }
}
