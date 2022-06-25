// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utility/Whitelist.sol";
import "../interfaces/IPriceFeeder.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../utility/LibMath.sol";

contract QuickswapTokenFeeder is IPriceFeeder {
    using LibMathUnsigned for uint256;
    using LibMathSigned for int256;

    // for identification
    string public name;
    address public baseTokenAddress;
    uint256 public baseDecimals;
    address public pairTokenAddress;
    uint256 public pairDecimals;

    address constant ROUTER_ADDRESS = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; // Quickswap Router

    constructor(
        string memory _name,
        address _baseTokenAddress,
        uint256 _baseDecimals,
        address _pairTokenAddress,
        uint256 _pairDecimals
    ) public {

        name = _name;
        baseTokenAddress = _baseTokenAddress;
        baseDecimals = _baseDecimals;
        pairTokenAddress = _pairTokenAddress;
        pairDecimals = _pairDecimals;

    }

    // get current price
    function getValue() external view override returns (uint256) {
        IPancakeRouter02 router = IPancakeRouter02(ROUTER_ADDRESS);

        address[] memory path = new address[](2);

        path[0] = baseTokenAddress;
        path[1] = pairTokenAddress;

        uint256 output = router.getAmountsOut(1 * (10 ** baseDecimals), path)[1];

        if (pairDecimals == 18) {
            return output;
        }

        return output * (10** (18 - pairDecimals));
    }

    // get current timmestamp
    function getTimestamp() external view override returns (uint256) {
        return now;
    }

}