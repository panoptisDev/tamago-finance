// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utility/Whitelist.sol";
import "../interfaces/IPriceFeeder.sol";
import "../interfaces/IPancakePair.sol";
import "../utility/LibMath.sol";

contract QuickswapLPFeeder is IPriceFeeder {
    using LibMathUnsigned for uint256;
    using LibMathSigned for int256;

    // for identification
    string public name;
    IPancakePair public lp;
    IPriceFeeder public baseTokenPriceFeeder;
    IPriceFeeder public pairTokenPriceFeeder;
    uint256 public baseTokenDecimals;
    uint256 public pairTokenDecimals;

    address constant ROUTER_ADDRESS = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; // Quickswap Router

    constructor(
        string memory _name,
        address _lpAddress,
        address _baseTokenPriceFeederAddress,
        uint256 _baseTokenDecimals,
        address _pairTokenPriceFeederAddress,
        uint256 _pairTokenDecimals
    ) public {

        name = _name;
        lp = IPancakePair(_lpAddress);
        baseTokenPriceFeeder = IPriceFeeder(_baseTokenPriceFeederAddress);
        pairTokenPriceFeeder = IPriceFeeder(_pairTokenPriceFeederAddress);

        baseTokenDecimals = _baseTokenDecimals;
        pairTokenDecimals = _pairTokenDecimals;
    }

    // get current price
    function getValue() external view override returns (uint256) {

        IERC20 baseToken = IERC20(lp.token0());
        IERC20 pairToken = IERC20(lp.token1());

        uint256 totalBaseToken = baseToken.balanceOf(address(lp));

        if (baseTokenDecimals != 18) {
            totalBaseToken = totalBaseToken * (10**(18-baseTokenDecimals));
        }

        uint256 totalPairToken = pairToken.balanceOf(address(lp));

        if (pairTokenDecimals != 18) {
            totalPairToken = totalPairToken * (10**(18-pairTokenDecimals));
        }

        uint256 baseTokenValue = totalBaseToken.wmul( baseTokenPriceFeeder.getValue());
        uint256 pairTokenValue = totalPairToken.wmul( pairTokenPriceFeeder.getValue());

        return (baseTokenValue.add(pairTokenValue)).wdiv( lp.totalSupply() );
    }

    // get current timmestamp
    function getTimestamp() external view override returns (uint256) {
        // return _getTimestamp();
        return now;
    }

}