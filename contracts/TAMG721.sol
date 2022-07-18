// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TAMG721 is ERC721A, ERC721AQueryable, ERC721ABurnable, Ownable {
  using Strings for uint256;

  string private baseURI;
  string public baseExtension = ".json";
  uint256 public maxSupply;
  uint256 public randomHash;

  event SetBaseURI(string OldBaseURI, string NewBaseURI);

  constructor(
    string memory _initBaseURI,
    address _preMintAddress,
    string memory _name,
    string memory _symbol,
    uint256 _maxSupply,
    uint256 _randomHash
  ) ERC721A(_name, _symbol) {
    maxSupply = _maxSupply;
    randomHash = _randomHash;

    setBaseURI(_initBaseURI);
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    string memory _oldBaseURI = baseURI;
    baseURI = _newBaseURI;

    emit SetBaseURI(_oldBaseURI, baseURI);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override(ERC721A)
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return
      bytes(currentBaseURI).length > 0
        ? string(
          abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)
        )
        : "";
  }

  function safeMint(address to, uint256 amount) public {
    require(totalSupply() + amount <= maxSupply, "Over max supply");
    _safeMint(to, amount);
  }

  function _beforeTokenTransfers(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal override {
    super._beforeTokenTransfers(from, to, startTokenId, quantity);
  }

  // The following functions are overrides required by Solidity.
  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721A)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function _startTokenId() internal view virtual override returns (uint256) {
    return 1;
  }
}
