// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../utility/LibMath.sol";
import "../utility/Whitelist.sol";
import "../utility/SyntheticNFT.sol";
import "../interfaces/IPriceResolver.sol";
import "../interfaces/ISyntheticNFT.sol";
import "../interfaces/INFTManager.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakeFactory.sol";

/**
 * @title A contract to collaterizes ERC-20 and mints NFT
 * @dev The contract heavily depends on 3rd party modules from QuickSwap, Chainlink to running. Check out docs.tamago.finance for more details
 */

contract NFTManager is
  ReentrancyGuard,
  Whitelist,
  INFTManager,
  ERC1155Holder,
  Pausable
{
  using LibMathSigned for int256;
  using LibMathUnsigned for uint256;

  using SafeERC20 for IERC20;

  struct SyntheticVariant {
    // name of the variant
    string name;
    // token id for this variant
    uint256 tokenId;
    // value
    uint256 tokenValue;
    // raw collateral on this variant
    uint256 totalRawCollateral;
    uint256 totalDebtCollateral;
    // total tokens that been minted
    uint256 totalOutstanding;
    // total tokens that been issued
    uint256 totalIssued;
    // total tokens that been burnt
    uint256 totalBurnt;
    // active status
    bool disabled;
  }

  // Name of the contract
  string public name;
  // Price resolver contract.
  IPriceResolver public priceResolver;
  // Synthetic NFT created by this contract.
  ISyntheticNFT public override syntheticNFT;
  // Collateral share
  IPancakePair public collateralShare;
  // Collateral share's symbol for price calculation
  bytes32 public collateralShareSymbol;
  // Target currency in the registry
  bytes32 public syntheticSymbol;
  // Synthetic NFT variants
  mapping(uint8 => SyntheticVariant) public syntheticVariants;
  // Total Synthetic NFT variants
  uint8 public syntheticVariantCount;
  // Total raw collateral
  uint256 public totalRawCollateral;
  uint256 public totalDebtCollateral;
  // Total NFT synthetics outstanding
  uint256 public totalOutstanding;
  // Dev address
  address public devAddress;
  // Redeem fee
  uint256 public redeemFee;
  // Ignore offset/discount fees when active
  bool public offsetDisabled;
  bool public discountDisabled;
  // max NFT that can be minted per time
  uint256 constant MAX_NFT = 100;

  int256 constant ONE_ETHER = 1 * 10**18;
  uint256 constant UNSIGNED_ONE_ETHER = 10**18;
  uint256 constant TEN_KWEI = 10000;
  uint256 constant MAX_UINT256 = uint256(-1);
  address constant ROUTER_ADDRESS = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; // Quickswap Router
  // 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F; // SushiV2 Router
  int256 constant BASE = 10 ether;
  int256 constant K = 9.3 ether;

  event PositionCreated(
    address minter,
    uint8 variantId,
    uint256 tokenValue,
    uint256 collateralAmount,
    uint256 tokenAmount
  );

  event PositionRemoved(
    address minter,
    uint8 variantId,
    uint256 tokenValue,
    uint256 collateralAmount,
    uint256 tokenAmount
  );

  /// @notice the contructor that requires necessary params to setup ERC-1155 contract
  /// @param _name name of the NFT collection
  /// @param _nftUri base uri for the ERC-1155 NFT
  /// @param _priceResolverAddress the address of the shared price feeder registry
  /// @param _collateralShareAddress the address of LP token to be used as a collateral
  /// @param _collateralShareSymbol the symbol of LP token that defined on the price registry
  /// @param _syntheticSymbol the symbol of value-backed NFT that defined on the price registry
  /// @param _devAddress dev address
  constructor(
    string memory _name,
    string memory _nftUri,
    address _priceResolverAddress,
    address _collateralShareAddress,
    bytes32 _collateralShareSymbol,
    bytes32 _syntheticSymbol,
    address _devAddress
  ) public {
    name = _name;
    syntheticSymbol = _syntheticSymbol;

    collateralShare = IPancakePair(_collateralShareAddress);
    collateralShareSymbol = _collateralShareSymbol;

    priceResolver = IPriceResolver(_priceResolverAddress);

    redeemFee = 300; // 3.0%

    // Deploy the synthetic NFT contract
    SyntheticNFT deployedContract = new SyntheticNFT(_name, _nftUri);
    syntheticNFT = ISyntheticNFT(address(deployedContract));

    devAddress = _devAddress;

    // add dev into the whitelist
    addAddress(_devAddress);

    if (_devAddress != msg.sender) {
      addAddress(msg.sender);
    }

    if (collateralShare.token0() != address(0)) {
      IERC20(collateralShare.token0()).approve(ROUTER_ADDRESS, MAX_UINT256);
      IERC20(collateralShare.token1()).approve(ROUTER_ADDRESS, MAX_UINT256);
      IERC20(address(collateralShare)).approve(ROUTER_ADDRESS, MAX_UINT256);
    }
  }

  /// @notice calculate amount of collateral assets to be placed for minting the NFT
  /// @param _id the NFT's variant id
  /// @param _tokenAmount total NFT to be created
  /// @return baseTokenAmount required amount of token0 on LP
  /// @return pairTokenAmount required amount of token1 on LP
  /// @return lpAmount Estimated LP amount to be deposited as a collateral
  /// @return discount The discount if CR > 1
  function estimateMint(uint8 _id, uint256 _tokenAmount)
    public
    view
    validateId(_id, _tokenAmount)
    returns (
      uint256 baseTokenAmount,
      uint256 pairTokenAmount,
      uint256 lpAmount,
      uint256 discount
    )
  {
    (baseTokenAmount, pairTokenAmount, lpAmount, discount) = _estimateMint(
      _id,
      _tokenAmount
    );
  }

  /// @notice calcualte amount of collateral assets to be returned when burning NFT
  /// @param _id the NFT's variant id
  /// @param _tokenAmount total NFT to be burnt
  /// @return baseTokenAmount redeemed amount of token0 on LP
  /// @return pairTokenAmount redeemed amount of token1 on LP
  /// @return lpAmount Estimated LP amount to be withdrawn from Quickswap
  /// @return offset The offset fee when CR < 1
  function estimateRedeem(uint8 _id, uint256 _tokenAmount)
    public
    view
    validateId(_id, _tokenAmount)
    returns (
      uint256 baseTokenAmount,
      uint256 pairTokenAmount,
      uint256 lpAmount,
      uint256 offset
    )
  {
    (baseTokenAmount, pairTokenAmount, lpAmount, offset) = _estimateRedeem(
      _id,
      _tokenAmount
    );
  }

  /// @notice taking 2 tokens and adding them to Quickswap LP, the returned LP will be locked and be the variant's collateral for the NFT issuing
  /// @param _id the NFT's variant id
  /// @param _tokenAmount total NFT to be created
  /// @param _maxBaseAmount cap amount of token0 that can be sent out from the wallet
  /// @param _maxPairAmount  cap amount of token1 that can be sent out from the wallet
  function mint(
    uint8 _id,
    uint256 _tokenAmount,
    uint256 _maxBaseAmount,
    uint256 _maxPairAmount
  ) public nonReentrant validateId(_id, _tokenAmount) whenNotPaused {
    (uint256 baseAmount, uint256 pairAmount, , ) = _estimateMint(
      _id,
      _tokenAmount
    );

    require(_maxBaseAmount >= baseAmount, "Exceeding _maxBaseAmount");
    require(_maxPairAmount >= pairAmount, "Exceeding _maxPairAmount");

    // takes ERC-20 tokens
    IERC20(collateralShare.token0()).safeTransferFrom(
      msg.sender,
      address(this),
      baseAmount
    );
    IERC20(collateralShare.token1()).safeTransferFrom(
      msg.sender,
      address(this),
      pairAmount
    );

    (, , uint256 lpAmount) = IPancakeRouter02(ROUTER_ADDRESS).addLiquidity(
      collateralShare.token0(),
      collateralShare.token1(),
      baseAmount,
      pairAmount,
      0,
      0,
      address(this),
      now + 86400
    );

    _createPosition(_id, lpAmount, _tokenAmount);

    // mint NFT back to the minter
    syntheticNFT.mint(
      msg.sender,
      syntheticVariants[_id].tokenId,
      _tokenAmount,
      _toBytes(0)
    );
  }

  /// @notice burning NFT and returning collateral assets, the offset fee will be charged when CR < 1
  /// @param _id the NFT's variant id
  /// @param _tokenAmount total NFT to be burnt
  /// @param _minBaseAmount min. amount of token0 expects to receive
  /// @param _minPairAmount min. amount of token1 expects to receive
  function redeem(
    uint8 _id,
    uint256 _tokenAmount,
    uint256 _minBaseAmount,
    uint256 _minPairAmount
  ) public nonReentrant validateId(_id, _tokenAmount) whenNotPaused {
    (, , uint256 lpAmount, ) = _estimateRedeem(_id, _tokenAmount);

    _removePosition(_id, lpAmount, _tokenAmount);

    // burn NFT
    syntheticNFT.safeTransferFrom(
      msg.sender,
      address(this),
      syntheticVariants[_id].tokenId,
      _tokenAmount,
      _toBytes(0)
    );
    syntheticNFT.burn(
      address(this),
      syntheticVariants[_id].tokenId,
      _tokenAmount
    );

    (uint256 baseTokenAmount, uint256 pairTokenAmount) = IPancakeRouter02(
      ROUTER_ADDRESS
    ).removeLiquidity(
        collateralShare.token0(),
        collateralShare.token1(),
        lpAmount,
        _minBaseAmount,
        _minPairAmount,
        address(this),
        now + 86400
      );

    require(baseTokenAmount >= _minBaseAmount, "_minBaseAmount is not reached");
    require(pairTokenAmount >= _minPairAmount, "_minPairAmount is not reached");

    // return tokens back
    if (redeemFee != 0) {
      uint256 baseFee = baseTokenAmount.mul(redeemFee).div(TEN_KWEI);
      uint256 pairFee = pairTokenAmount.mul(redeemFee).div(TEN_KWEI);
      IERC20(collateralShare.token0()).transfer(
        msg.sender,
        baseTokenAmount.sub(baseFee)
      );
      IERC20(collateralShare.token1()).transfer(
        msg.sender,
        pairTokenAmount.sub(pairFee)
      );
      // transfer fees to dev.
      IERC20(collateralShare.token0()).transfer(devAddress, baseFee);
      IERC20(collateralShare.token1()).transfer(devAddress, pairFee);
    } else {
      IERC20(collateralShare.token0()).transfer(msg.sender, baseTokenAmount);
      IERC20(collateralShare.token1()).transfer(msg.sender, pairTokenAmount);
    }
  }

  /// @notice call the price feeder registry to retrieve the latest price of NFT
  /// @return US price per a synthetic token
  function getSyntheticPrice() public view returns (uint256) {
    require(
      priceResolver.isValid(syntheticSymbol),
      "syntheticSymbol is not valid"
    );
    return priceResolver.getCurrentPrice(syntheticSymbol);
  }

  /// @notice call the price feeder registry to retrieve the latest price of LP token
  /// @return US price per a LP token
  function getCollateralSharePrice() public view returns (uint256) {
    require(
      priceResolver.isValid(collateralShareSymbol),
      "collateralShareSymbol is not valid"
    );
    return priceResolver.getCurrentPrice(collateralShareSymbol);
  }

  /// @notice looks for the system collateral ratio basically calculates from total collateral deposited / total NFT minted
  /// @return the system collateral ratio
  function globalCollatelizationRatio() public view returns (uint256) {
    require(totalRawCollateral > 0, "No collaterals in the contract");
    return
      _calculateCollateralizationRatio(totalRawCollateral, totalOutstanding);
  }

  /// @notice looks for the collateral ratio for particular variant
  /// @param _id the NFT's variant id
  /// @return the variant collateral ratio
  function variantCollatelizationRatio(uint8 _id)
    public
    view
    returns (uint256)
  {
    require(syntheticVariantCount > _id, "Invalid given _id");

    if (syntheticVariants[_id].totalRawCollateral > 0) {
      return
        _calculateCollateralizationRatio(
          syntheticVariants[_id].totalRawCollateral,
          syntheticVariants[_id].totalOutstanding
        );
    } else {
      // return 100% when no collaterals
      return UNSIGNED_ONE_ETHER;
    }
  }

  /// @notice calculates the target ratio that we need to either leaving and giving away (as discount) some collaterals to help bring the ratio back to 1
  /// @param _id the NFT's variant id
  /// @return the target ratio when CR < 1
  /// @return the target ratio when CR > 1
  function targetCollatelizationRatio(uint8 _id)
    public
    view
    returns (int256, int256)
  {
    require(syntheticVariantCount > _id, "Invalid given _id");
    return (_calculateTargetCROffset(_id), _calculateTargetCRDiscount(_id));
  }

  // ONLY ADMIN CAN PROCEED

  // pause the contract
  function setPaused() public onlyWhitelisted whenNotPaused {
    _pause();
  }

  // unpause the contract
  function setUnpaused() public onlyWhitelisted whenPaused {
    _unpause();
  }

  // add NFT variant
  function addSyntheticVariant(
    string memory _name,
    uint256 _tokenId,
    uint256 _tokenValue
  ) public nonReentrant onlyWhitelisted {
    syntheticVariants[syntheticVariantCount].name = _name;
    syntheticVariants[syntheticVariantCount].tokenId = _tokenId;
    syntheticVariants[syntheticVariantCount].tokenValue = _tokenValue;

    syntheticVariantCount += 1;
  }

  // enable/disable synthetic NFT variant
  function setSyntheticVariantDisable(uint8 _id, bool _disabled)
    public
    nonReentrant
    onlyWhitelisted
  {
    require(syntheticVariantCount > _id, "Invalid given _id");
    syntheticVariants[_id].disabled = _disabled;
  }

  // emergency withdraw ERC-20 tokens out of the contract
  function withdrawErc20(address _tokenAddress, uint256 _amount)
    public
    nonReentrant
    onlyWhitelisted
  {
    IERC20(_tokenAddress).transfer(msg.sender, _amount);
  }

  // force mint ERC-1155
  function forceMint(
    uint8 _id,
    uint256 _collateralAmount,
    uint256 _tokenAmount
  )
    public
    nonReentrant
    onlyWhitelisted
    validateId(_id, _tokenAmount)
    whenNotPaused
  {
    _createPosition(_id, _collateralAmount, _tokenAmount);

    // take collaterals
    collateralShare.transferFrom(msg.sender, address(this), _collateralAmount);

    // mint NFT back to the minter
    syntheticNFT.mint(
      msg.sender,
      syntheticVariants[_id].tokenId,
      _tokenAmount,
      _toBytes(0)
    );
  }

  // force burn ERC-1155
  function forceRedeem(
    uint8 _id,
    uint256 _collateralAmount,
    uint256 _tokenAmount
  )
    public
    nonReentrant
    onlyWhitelisted
    validateId(_id, _tokenAmount)
    whenNotPaused
  {
    _removePosition(_id, _collateralAmount, _tokenAmount);

    // burn NFT
    syntheticNFT.safeTransferFrom(
      msg.sender,
      address(this),
      syntheticVariants[_id].tokenId,
      _tokenAmount,
      _toBytes(0)
    );
    syntheticNFT.burn(
      address(this),
      syntheticVariants[_id].tokenId,
      _tokenAmount
    );

    // return collaterals back to the minter
    collateralShare.transfer(msg.sender, _collateralAmount);
  }

  // update the price resolver contract
  function setPriceResolver(address _priceResolverAddress)
    public
    nonReentrant
    onlyWhitelisted
  {
    priceResolver = IPriceResolver(_priceResolverAddress);
  }

  // update dev address
  function setDevAddress(address _devAddress)
    public
    nonReentrant
    onlyWhitelisted
  {
    devAddress = _devAddress;
  }

  // update NFT uri
  function setNftUri(string memory _uri) public nonReentrant onlyWhitelisted {
    syntheticNFT.setUri(_uri);
  }

  // update redeem fees
  function setRedeemFee(uint256 _fee) public nonReentrant onlyWhitelisted {
    redeemFee = _fee;
  }

  // enable / disable offset fees
  function setOffsetDisabled(bool _active) public nonReentrant onlyWhitelisted {
    offsetDisabled = _active;
  }

  // enable / disable discount fees
  function setDiscountDisabled(bool _active)
    public
    nonReentrant
    onlyWhitelisted
  {
    discountDisabled = _active;
  }

  // INTERNAL FUNCTIONS

  modifier validateId(uint8 _id, uint256 _tokenAmount) {
    require(syntheticVariantCount > _id, "Invalid given _id");
    require(
      syntheticVariants[_id].disabled == false,
      "The given _id is disabled"
    );
    require(_tokenAmount != 0, "_tokenAmount can't be zero");
    require(MAX_NFT >= _tokenAmount, "Exceed MAX_NFT");
    _;
  }

  function _toBytes(uint256 x) internal pure returns (bytes memory b) {
    b = new bytes(32);
    assembly {
      mstore(add(b, 32), x)
    }
  }

  function _createPosition(
    uint8 _id,
    uint256 _collateralAmount,
    uint256 _tokenAmount
  ) internal {
    syntheticVariants[_id].totalOutstanding = syntheticVariants[_id]
      .totalOutstanding
      .add(syntheticVariants[_id].tokenValue.mul(_tokenAmount));
    syntheticVariants[_id].totalIssued = syntheticVariants[_id].totalIssued.add(
      _tokenAmount
    );
    syntheticVariants[_id].totalRawCollateral = syntheticVariants[_id]
      .totalRawCollateral
      .add(_collateralAmount);

    emit PositionCreated(
      msg.sender,
      _id,
      syntheticVariants[_id].tokenValue,
      _collateralAmount,
      _tokenAmount
    );

    totalRawCollateral = totalRawCollateral.add(_collateralAmount);
    totalOutstanding = totalOutstanding.add(
      syntheticVariants[_id].tokenValue.mul(_tokenAmount)
    );
  }

  function _removePosition(
    uint8 _id,
    uint256 _collateralAmount,
    uint256 _tokenAmount
  ) internal {
    syntheticVariants[_id].totalOutstanding = syntheticVariants[_id]
      .totalOutstanding
      .sub(syntheticVariants[_id].tokenValue.mul(_tokenAmount));
    syntheticVariants[_id].totalBurnt = syntheticVariants[_id].totalBurnt.add(
      _tokenAmount
    );

    // record the debt
    if (_collateralAmount > syntheticVariants[_id].totalRawCollateral) {
      uint256 debt = _collateralAmount.sub(
        syntheticVariants[_id].totalRawCollateral
      );
      syntheticVariants[_id].totalDebtCollateral = syntheticVariants[_id]
        .totalDebtCollateral
        .add(debt);
      totalDebtCollateral = totalDebtCollateral.add(debt);
      _collateralAmount = _collateralAmount.sub(debt);
    }

    syntheticVariants[_id].totalRawCollateral = syntheticVariants[_id]
      .totalRawCollateral
      .sub(_collateralAmount);

    emit PositionRemoved(
      msg.sender,
      _id,
      syntheticVariants[_id].tokenValue,
      _collateralAmount,
      _tokenAmount
    );

    totalRawCollateral = totalRawCollateral.sub(_collateralAmount);
    totalOutstanding = totalOutstanding.sub(
      syntheticVariants[_id].tokenValue.mul(_tokenAmount)
    );
  }

  function _getSyntheticPrice() internal view returns (uint256) {
    require(
      priceResolver.isValid(syntheticSymbol),
      "syntheticSymbol is not valid"
    );
    return priceResolver.getCurrentPrice(syntheticSymbol);
  }

  function _getCollateralSharePrice() internal view returns (uint256) {
    require(
      priceResolver.isValid(collateralShareSymbol),
      "collateralShareSymbol is not valid"
    );
    return priceResolver.getCurrentPrice(collateralShareSymbol);
  }

  function _calculateCollateralizationRatio(
    uint256 collateralAmount,
    uint256 syntheticAmount
  ) internal view returns (uint256) {
    uint256 collateralRate = _getCollateralSharePrice();
    uint256 syntheticRate = _getSyntheticPrice();

    uint256 numerator = collateralRate.wmul(collateralAmount);
    uint256 denominator = syntheticRate.wmul(syntheticAmount);

    // uint256 output = (collateralRate.wdiv(syntheticRate)).wmul(
    //     collateralAmount.wdiv(syntheticAmount)
    // );
    // uint256 output = (collateralRate.wdiv(syntheticRate)).mul(collateralAmount).div(syntheticAmount);

    return numerator.wdiv(denominator);
    // return output;
  }

  function _estimateLPInputs(uint8 _id, uint256 _tokenAmount)
    internal
    view
    returns (
      uint256 baseTokenAmount,
      uint256 pairTokenAmount,
      uint256 lpAmount
    )
  {
    uint256 syntheticPrice = _getSyntheticPrice();
    uint256 sharePrice = _getCollateralSharePrice();
    uint256 mintedValue = syntheticPrice.wmul(
      syntheticVariants[_id].tokenValue.mul(_tokenAmount)
    );
    uint256 lpNeeded = mintedValue.wdiv(sharePrice);

    lpAmount = lpNeeded;

    uint256 baseInLp = IERC20(collateralShare.token0()).balanceOf(
      address(collateralShare)
    );
    uint256 pairInLp = IERC20(collateralShare.token1()).balanceOf(
      address(collateralShare)
    );

    baseTokenAmount = (lpNeeded.mul(baseInLp)).div(
      collateralShare.totalSupply()
    );
    pairTokenAmount = (lpNeeded.mul(pairInLp)).div(
      collateralShare.totalSupply()
    );
  }

  function _estimateRedeem(uint8 _id, uint256 _tokenAmount)
    internal
    view
    returns (
      uint256 baseTokenAmount,
      uint256 pairTokenAmount,
      uint256 lpAmount,
      uint256 offset
    )
  {
    (baseTokenAmount, pairTokenAmount, lpAmount) = _estimateLPInputs(
      _id,
      _tokenAmount
    );

    int256 targetCR = _calculateTargetCROffset(_id);

    // adjusting redeemed amount when CR < 1
    if (targetCR != ONE_ETHER && targetCR > 0 && offsetDisabled == false) {
      uint256 newTotalCollateral = syntheticVariants[_id]
        .totalRawCollateral
        .sub(lpAmount);
      uint256 newCR = _calculateCollateralizationRatio(
        newTotalCollateral,
        syntheticVariants[_id].totalOutstanding.sub(
          syntheticVariants[_id].tokenValue.mul(_tokenAmount)
        )
      );

      uint256 adjustedTotalCollateral = (
        (targetCR.toUint256()).wmul(newTotalCollateral)
      ).wdiv(newCR);
      if (adjustedTotalCollateral > newTotalCollateral) {
        offset = (adjustedTotalCollateral.sub(newTotalCollateral))
          .wmul(lpAmount)
          .wdiv(syntheticVariants[_id].totalRawCollateral);
      }

      uint256 lpAmountWithOffset = lpAmount.sub(offset);

      baseTokenAmount = baseTokenAmount.mul(lpAmountWithOffset).div(lpAmount);
      pairTokenAmount = pairTokenAmount.mul(lpAmountWithOffset).div(lpAmount);
      lpAmount = lpAmountWithOffset;
    }
  }

  function _estimateMint(uint8 _id, uint256 _tokenAmount)
    internal
    view
    returns (
      uint256 baseTokenAmount,
      uint256 pairTokenAmount,
      uint256 lpAmount,
      uint256 discount
    )
  {
    (baseTokenAmount, pairTokenAmount, lpAmount) = _estimateLPInputs(
      _id,
      _tokenAmount
    );

    int256 targetCR = _calculateTargetCRDiscount(_id);

    // adjusting minted amount when target CR > current CR > 1
    if (targetCR > ONE_ETHER && discountDisabled == false) {
      uint256 newTotalCollateral = syntheticVariants[_id]
        .totalRawCollateral
        .add(lpAmount);
      uint256 newCR = _calculateCollateralizationRatio(
        newTotalCollateral,
        syntheticVariants[_id].totalOutstanding.add(
          syntheticVariants[_id].tokenValue.mul(_tokenAmount)
        )
      );

      uint256 adjustedTotalCollateral = (
        (targetCR.toUint256()).wmul(newTotalCollateral)
      ).wdiv(newCR);

      if (newTotalCollateral > adjustedTotalCollateral) {
        discount = newTotalCollateral
          .sub(adjustedTotalCollateral)
          .wmul(lpAmount)
          .wdiv(syntheticVariants[_id].totalRawCollateral);
      }

      uint256 lpAmountWithDiscount = lpAmount.sub(discount);

      baseTokenAmount = baseTokenAmount.mul(lpAmountWithDiscount).div(lpAmount);
      pairTokenAmount = pairTokenAmount.mul(lpAmountWithDiscount).div(lpAmount);
      lpAmount = lpAmountWithDiscount;
    }
  }

  // when cr is between 0 -> 1
  function _calculateTargetCROffset(uint8 _id) internal view returns (int256) {
    int256 cr = variantCollatelizationRatio(_id).toInt256();
    int256 result = _calculateTargetCR(cr);
    if (cr > 0 && ONE_ETHER >= result) {
      return result;
    } else {
      return ONE_ETHER;
    }
  }

  // when cr is between 1 -> infinity
  function _calculateTargetCRDiscount(uint8 _id)
    internal
    view
    returns (int256)
  {
    int256 cr = variantCollatelizationRatio(_id).toInt256();
    int256 result = _calculateTargetCR(cr);
    if (cr > ONE_ETHER && cr > result) {
      return _calculateTargetCR(cr);
    } else {
      return ONE_ETHER;
    }
  }

  // log^b(kx+1)
  function _calculateTargetCR(int256 _cr) internal pure returns (int256) {
    return BASE.logBase((K.wmul(_cr)).add(ONE_ETHER));
  }
}
