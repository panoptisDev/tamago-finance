//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISyntheticToken is IERC20 {

    function burn(uint256 value) external;

    function mint(address to, uint256 value) external returns (bool);

}