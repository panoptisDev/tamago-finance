// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utility/Whitelist.sol";
import "../interfaces/IPriceFeeder.sol";

contract MockPriceFeeder is ReentrancyGuard, Whitelist, IPriceFeeder {

    string public name;

    uint256 public value = 1 * (10 ** 18);
    uint256 private timestamp;

    constructor(string memory _name) public nonReentrant {
        name = _name;
        timestamp = now;
        addAddress(msg.sender);
    }

    function updateValue(uint256 _newValue) public onlyWhitelisted {
        value = _newValue;
        timestamp = now;
    }

    function getValue() public override view returns (uint256) {
        return value;
    }

    function getTimestamp() public override view returns (uint256) {
        return timestamp;
    }

}