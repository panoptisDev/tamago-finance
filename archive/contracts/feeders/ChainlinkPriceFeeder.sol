// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utility/Whitelist.sol";
import "../interfaces/IPriceFeeder.sol";
import "../utility/LibMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceFeeder is IPriceFeeder {
    using LibMathUnsigned for uint256;
    using LibMathSigned for int256;

    // for identification
    string public name;
    AggregatorV3Interface internal chainlinkPriceFeed;
    uint8 public decimals;
    uint256 private timestamp;

    /*
        Example:
        _name : Facebook
        _chainlinkPriceFeedAddress : 0xCe1051646393087e706288C1B57Fd26446657A7f
        _decimals : 8
    */

    constructor(
        string memory _name,
        address _chainlinkPriceFeedAddress,
        uint8 _decimals
    ) public {
        require(
            _decimals == 8 || _decimals == 18,
            "Decimals must be either 8 or 18"
        );

        name = _name;
        decimals = _decimals; 
        chainlinkPriceFeed = AggregatorV3Interface(_chainlinkPriceFeedAddress);
    }

    // get current price
    function getValue() external view override returns (uint256) {
        (uint256 value, ) = _getCurrentValue();
        return value;
    }

    // get current timmestamp
    function getTimestamp() external view override returns (uint256) {
        return _getTimestamp();
    }

    // PRIVATE FUNCTIONS

    function _getTimestamp() internal view returns (uint256) {
        (, , , uint256 timeStamp, ) = chainlinkPriceFeed.latestRoundData();

        return uint256(timeStamp);
    }

    function _getCurrentValue() internal view returns (uint256, uint256) {
        (, int256 price, , uint256 timeStamp, ) = chainlinkPriceFeed
            .latestRoundData();

        uint256 output = uint256(price);

        if (decimals == 8) {
            output = output.mul(10**10);
        }

        return (output, timeStamp);
    }

}