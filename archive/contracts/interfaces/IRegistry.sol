
//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRegistry {

    function contractCount() external pure returns (uint256);

    function registerContract(bytes32 name, address contractAddress) external;

    function updateContract(bytes32 name, address contractAddress) external;

    function getContractAddress(bytes32 _name) external view returns (address);

}
