// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/EIP712Whitelisting.sol";
import "./lib/BlockBasedSale.sol";

contract TAMG721 is
  Ownable,
  ERC721,
  ERC721Enumerable,
  EIP712Whitelisting,
  BlockBasedSale,
  ReentrancyGuard
{
  using Address for address;
  using SafeMath for uint256;

  enum SaleState {
    NotStarted,
    PrivateSaleBeforeWithoutBlock,
    PrivateSaleBeforeWithBlock,
    PrivateSaleDuring,
    PrivateSaleEnd,
    PrivateSaleEndSoldOut,
    PublicSaleBeforeWithoutBlock,
    PublicSaleBeforeWithBlock,
    PublicSaleDuring,
    PublicSaleEnd,
    PublicSaleEndSoldOut,
    PauseSale,
    AllSalesEnd
  }

  bool public beneficiaryAssigned = false;

  uint256 public seed = 0;

  mapping(address => uint256) private _privateSaleClaimed;

  string public _tokenBaseURI;

  constructor(
    uint256 _privateSalePrice,
    uint256 _publicSalePrice,
    string memory name,
    string memory symbol,
    uint256 _maxSupply,
    SaleConfig memory privateSale,
    SaleConfig memory publicSale
  ) ERC721(name, symbol) BlockBasedSale(privateSale, publicSale) {
    maxSupply = _maxSupply;
    publicSalePrice = _publicSalePrice;
    privateSalePrice = _privateSalePrice;
  }

  function mintToken(uint256 amount, bytes calldata signature)
    external
    payable
    nonReentrant
    returns (bool)
  {
    require(!msg.sender.isContract(), "Contract is not allowed.");
    require(
      getState() == SaleState.PrivateSaleDuring ||
        getState() == SaleState.PublicSaleDuring,
      "Sale not available."
    );

    if (getState() == SaleState.PublicSaleDuring) {
      require(amount <= maxPublicSalePerTx, "Mint exceed transaction limits.");
      require(msg.value >= amount.mul(getPriceByMode()), "Insufficient funds.");
      require(
        totalSupply().add(amount).add(availableReserve()) <= maxSupply,
        "Purchase exceed max supply."
      );
    }

    if (getState() == SaleState.PrivateSaleDuring) {
      require(isEIP712WhiteListed(signature), "Not whitelisted.");
      require(amount <= maxPrivateSalePerTx, "Mint exceed transaction limits");
      require(
        totalPrivateSaleMinted.add(amount) <= privateSaleCapped,
        "Purchase exceed private sale capped."
      );

      require(msg.value >= amount.mul(getPriceByMode()), "Insufficient funds.");
    }

    if (
      getState() == SaleState.PrivateSaleDuring ||
      getState() == SaleState.PublicSaleDuring
    ) {
      _mintToken(msg.sender, amount);
      if (getState() == SaleState.PublicSaleDuring) {
        totalPublicMinted = totalPublicMinted + amount;
      }
      if (getState() == SaleState.PrivateSaleDuring) {
        _privateSaleClaimed[msg.sender] =
          _privateSaleClaimed[msg.sender] +
          amount;
        totalPrivateSaleMinted = totalPrivateSaleMinted + amount;
      }
    }

    return true;
  }

  function setBaseURI(string memory baseURI) external onlyOwner {
    _tokenBaseURI = baseURI;
  }

  function getState() public view returns (SaleState) {
    uint256 supplyWithoutReserve = maxSupply - maxReserve;
    uint256 mintedWithoutReserve = totalPublicMinted + totalPrivateSaleMinted;

    if (
      salePhase != SalePhase.None &&
      overridedSaleState == OverrideSaleState.Close
    ) {
      return SaleState.AllSalesEnd;
    }

    if (
      salePhase != SalePhase.None &&
      overridedSaleState == OverrideSaleState.Pause
    ) {
      return SaleState.PauseSale;
    }

    if (
      salePhase == SalePhase.Public &&
      mintedWithoutReserve == supplyWithoutReserve
    ) {
      return SaleState.PublicSaleEndSoldOut;
    }

    if (salePhase == SalePhase.None) {
      return SaleState.NotStarted;
    }

    if (
      salePhase == SalePhase.Public &&
      publicSale.endBlock > 0 &&
      block.number > publicSale.endBlock
    ) {
      return SaleState.PublicSaleEnd;
    }

    if (
      salePhase == SalePhase.Public &&
      publicSale.beginBlock > 0 &&
      block.number >= publicSale.beginBlock
    ) {
      return SaleState.PublicSaleDuring;
    }

    if (
      salePhase == SalePhase.Public &&
      publicSale.beginBlock > 0 &&
      block.number < publicSale.beginBlock &&
      block.number > privateSale.endBlock
    ) {
      return SaleState.PublicSaleBeforeWithBlock;
    }

    if (
      salePhase == SalePhase.Public &&
      publicSale.beginBlock == 0 &&
      block.number > privateSale.endBlock
    ) {
      return SaleState.PublicSaleBeforeWithoutBlock;
    }

    if (
      salePhase == SalePhase.Private &&
      totalPrivateSaleMinted == privateSaleCapped
    ) {
      return SaleState.PrivateSaleEndSoldOut;
    }

    if (
      salePhase == SalePhase.Private &&
      privateSale.endBlock > 0 &&
      block.number > privateSale.endBlock
    ) {
      return SaleState.PrivateSaleEnd;
    }

    if (
      salePhase == SalePhase.Private &&
      privateSale.beginBlock > 0 &&
      block.number >= privateSale.beginBlock
    ) {
      return SaleState.PrivateSaleDuring;
    }

    if (
      salePhase == SalePhase.Private &&
      privateSale.beginBlock > 0 &&
      block.number < privateSale.beginBlock
    ) {
      return SaleState.PrivateSaleBeforeWithBlock;
    }

    if (salePhase == SalePhase.Private && privateSale.beginBlock == 0) {
      return SaleState.PrivateSaleBeforeWithoutBlock;
    }

    return SaleState.NotStarted;
  }

  function getStartSaleBlock() external view returns (uint256) {
    if (
      SaleState.PrivateSaleBeforeWithBlock == getState() ||
      SaleState.PrivateSaleDuring == getState()
    ) {
      return privateSale.beginBlock;
    }

    if (
      SaleState.PublicSaleBeforeWithBlock == getState() ||
      SaleState.PublicSaleDuring == getState()
    ) {
      return publicSale.beginBlock;
    }

    return 0;
  }

  function getEndSaleBlock() external view returns (uint256) {
    if (
      SaleState.PrivateSaleBeforeWithBlock == getState() ||
      SaleState.PrivateSaleDuring == getState()
    ) {
      return privateSale.endBlock;
    }

    if (
      SaleState.PublicSaleBeforeWithBlock == getState() ||
      SaleState.PublicSaleDuring == getState()
    ) {
      return publicSale.endBlock;
    }

    return 0;
  }

  function tokenBaseURI() external view returns (string memory) {
    return _tokenBaseURI;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721)
    returns (string memory)
  {
    require(tokenId < totalSupply() + 1, "Token not exist.");

    return string(abi.encodePacked(_tokenBaseURI, tokenId, ".json"));
  }

  function availableReserve() public view returns (uint256) {
    return maxReserve - totalReserveMinted;
  }

  function getMaxSupplyByMode() public view returns (uint256) {
    if (getState() == SaleState.PrivateSaleDuring) return privateSaleCapped;
    if (getState() == SaleState.PublicSaleDuring)
      return maxSupply - totalPrivateSaleMinted - maxReserve;
    return 0;
  }

  function getMintedByMode() external view returns (uint256) {
    if (getState() == SaleState.PrivateSaleDuring)
      return totalPrivateSaleMinted;
    if (getState() == SaleState.PublicSaleDuring) return totalPublicMinted;
    return 0;
  }

  function getTransactionCappedByMode() external view returns (uint256) {
    return
      getState() == SaleState.PrivateSaleDuring
        ? maxPrivateSalePerTx
        : maxPublicSalePerTx;
  }

  function availableForSale() external view returns (uint256) {
    return maxSupply - totalSupply();
  }

  function getPriceByMode() public view returns (uint256) {
    if (getState() == SaleState.PrivateSaleDuring) return privateSalePrice;

    return publicSalePrice;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function startPublicSaleBlock() external view returns (uint256) {
    return publicSale.beginBlock;
  }

  function endPublicSaleBlock() external view returns (uint256) {
    return publicSale.endBlock;
  }

  function startPrivateSaleBlock() external view returns (uint256) {
    return privateSale.beginBlock;
  }

  function endPrivateSaleBlock() external view returns (uint256) {
    return privateSale.endBlock;
  }

  function withdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  function _mintToken(address addr, uint256 amount) internal returns (bool) {
    for (uint256 i = 0; i < amount; i++) {
      uint256 tokenIndex = totalSupply();
      if (tokenIndex < maxSupply) _safeMint(addr, tokenIndex + 1);
    }
    return true;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }
}
