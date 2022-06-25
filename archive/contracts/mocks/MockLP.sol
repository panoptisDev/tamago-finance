//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./MockERC20.sol";

contract MockLP is MockERC20 {

    address public token0;
    address public token1;

    constructor(
        string memory name,
        string memory symbol
    ) public MockERC20(name, symbol, 18) {
       
    }

}
