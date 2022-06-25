// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPriceResolver {

    function getCurrentPrice(bytes32 _symbol) external view returns (uint256);

    function isValid(bytes32 _symbol) external view returns (bool);

}