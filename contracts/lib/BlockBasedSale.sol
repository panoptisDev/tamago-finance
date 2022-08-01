// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BlockBasedSale is Ownable {
  using SafeMath for uint256;

  enum OverrideSaleState {
    None,
    Pause,
    Close
  }

  enum SalePhase {
    None,
    Private,
    Public
  }

  OverrideSaleState public overridedSaleState = OverrideSaleState.None;
  SalePhase public salePhase = SalePhase.None;

  uint256 public maxPrivateSalePerTx = 10;
  uint256 public maxPublicSalePerTx = 20;

  uint256 public privateSaleCapped = 690;
  uint256 public totalPrivateSaleMinted = 0;

  uint256 public totalPublicMinted = 0;
  uint256 public totalReserveMinted = 0;
  uint256 public maxSupply = 6969;
  uint256 public maxReserve = 169;

  struct SaleConfig {
    uint256 beginBlock;
    uint256 endBlock;
    uint256 nativePrice;
    uint256 stablePrice;
  }

  SaleConfig public privateSale;
  SaleConfig public publicSale;

	constructor(SaleConfig memory _privateSale, SaleConfig memory _publicSale) {
		privateSale = _privateSale;
		publicSale = _publicSale;
	}

  function setTransactionLimit(
    uint256 privateSaleLimit,
    uint256 publicSaleLimit
  ) external onlyOwner {
    require(privateSaleLimit > 0);
    require(publicSaleLimit > 0);
    maxPrivateSalePerTx = privateSaleLimit;
    maxPublicSalePerTx = publicSaleLimit;
  }

  function setPrivateSaleConfig(SaleConfig memory _privateSale)
    external
    onlyOwner
  {
    privateSale = _privateSale;
  }

  function setPublicSaleConfig(SaleConfig memory _publicSale)
    external
    onlyOwner
  {
    publicSale = _publicSale;
  }

  function setCloseSale() external onlyOwner {
    overridedSaleState = OverrideSaleState.Close;
  }

  function setPauseSale() external onlyOwner {
    overridedSaleState = OverrideSaleState.Pause;
  }

  function resetOverridedSaleState() external onlyOwner {
    overridedSaleState = OverrideSaleState.None;
  }

  function setReserve(uint256 reserve) external onlyOwner {
    maxReserve = reserve;
  }

  function setPrivateSaleCap(uint256 cap) external onlyOwner {
    privateSaleCapped = cap;
  }

  function isPrivateSaleSoldOut() external view returns (bool) {
    return totalPrivateSaleMinted == privateSaleCapped;
  }

  function isPublicSaleSoldOut() external view returns (bool) {
    uint256 supplyWithoutReserve = maxSupply - maxReserve;
    uint256 mintedWithoutReserve = totalPublicMinted + totalPrivateSaleMinted;
    return supplyWithoutReserve == mintedWithoutReserve;
  }

  function enablePublicSale() external onlyOwner {
    salePhase = SalePhase.Public;
  }

  function enablePrivateSale() external onlyOwner {
    salePhase = SalePhase.Private;
  }
}
