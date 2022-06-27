//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

interface ISyntheticNFT is IERC1155Upgradeable {

    function mint(address to, uint256 id, uint256 value, bytes memory data) external returns (bool);

    function mintBatch(address to,  uint256[] memory ids, uint256[] memory values, bytes memory data) external returns (bool);

    function burn(address owner, uint256 id, uint256 value) external;

    function burnBatch( address owner, uint256[] memory ids, uint256[] memory values) external;

    function setUri(string memory uri) external;

    function addAddress(address _address) external;

}