// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utility/Whitelist.sol";
import "../utility/LibMath.sol";
import "../interfaces/IPriceResolver.sol";
import "../interfaces/IPriceFeeder.sol";

/**
 * @title A contract to resolves the asset price
 */

contract PriceResolver is ReentrancyGuard, Whitelist, IPriceResolver {
  using LibMathSigned for int256;
  using LibMathUnsigned for uint256;

  struct PriceFeeder {
    address priceFeederAddress;
    bool disabled;
    bool invert;
    uint256 fallbackValue; // use this value when disabled is set
  }

  mapping(bytes32 => PriceFeeder) public priceFeeders;
  mapping(uint256 => bytes32) public indexToPriceFeeder;

  uint256 public priceFeederCount;

  uint256 constant ONE = 1000000000000000000; // 1

  event PriceFeederAdded(
    bytes32 symbol,
    address priceFeederAddress,
    bool invert
  );

  constructor(address _devAddress) public nonReentrant {
    addAddress(_devAddress);

    if (_devAddress != msg.sender) {
      addAddress(msg.sender);
    }
  }

  /// @notice get the latest price of the given symbol, return the fallback value if the symbol has been disabled
  /// @param _symbol the currency symbol that has registered to the contract
  /// @return the price in Wei unit
  function getCurrentPrice(bytes32 _symbol)
    external
    view
    override
    returns (uint256)
  {
    require(
      priceFeeders[_symbol].priceFeederAddress != address(0),
      "Given symbol is invalid"
    );

    if (priceFeeders[_symbol].disabled == false) {
      uint256 value = IPriceFeeder(priceFeeders[_symbol].priceFeederAddress)
        .getValue();

      if (priceFeeders[_symbol].invert == false) {
        return value;
      } else {
        return ONE.wdiv(value);
      }
    } else {
      // use fallback values

      uint256 fallbackValue = priceFeeders[_symbol].fallbackValue;

      if (priceFeeders[_symbol].invert == false) {
        return fallbackValue;
      } else {
        return ONE.wdiv(fallbackValue);
      }
    }
  }

  // ADMIN FUNCTIONS

  // Add the price feeder record
  function registerPriceFeeder(
    bytes32 _symbol,
    address _priceFeederAddress,
    bool _invert,
    uint256 _fallbackValue
  ) public nonReentrant onlyWhitelisted {
    require(_symbol != "0x00", "Invalid _symbol");
    require(_priceFeederAddress != address(0), "Invalid _priceFeederAddress");
    require(
      priceFeeders[_symbol].priceFeederAddress == address(0),
      "_symbol is duplicated"
    );

    priceFeeders[_symbol].priceFeederAddress = _priceFeederAddress;
    priceFeeders[_symbol].invert = _invert;
    priceFeeders[_symbol].disabled = false;
    priceFeeders[_symbol].fallbackValue = _fallbackValue;

    indexToPriceFeeder[priceFeederCount] = _symbol;
    priceFeederCount += 1;

    emit PriceFeederAdded(_symbol, _priceFeederAddress, _invert);
  }

  // Enable/Disable particular price feeder
  function setPriceFeederDisable(bytes32 _symbol, bool _disabled)
    public
    nonReentrant
    onlyWhitelisted
  {
    priceFeeders[_symbol].disabled = _disabled;
  }

  // Update particular price feeder address
  function setPriceFeederAddress(bytes32 _symbol, address _priceFeederAddress)
    public
    nonReentrant
    onlyWhitelisted
  {
    priceFeeders[_symbol].priceFeederAddress = _priceFeederAddress;
  }

  // Update invert flag
  function setPriceFeederInvertFlag(bytes32 _symbol, bool _invert)
    public
    nonReentrant
    onlyWhitelisted
  {
    priceFeeders[_symbol].invert = _invert;
  }

  // Update fallback value
  function setPriceFeederFallbackValue(bytes32 _symbol, uint256 _fallbackValue)
    public
    nonReentrant
    onlyWhitelisted
  {
    priceFeeders[_symbol].fallbackValue = _fallbackValue;
  }

  // Validate the given symbol
  function isValid(bytes32 _symbol) external view override returns (bool) {
    return (priceFeeders[_symbol].priceFeederAddress != address(0));
  }
}
