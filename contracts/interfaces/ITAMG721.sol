// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a/contracts/IERC721A.sol";
import "erc721a/contracts/extensions/IERC721ABurnable.sol";
import "erc721a/contracts/extensions/IERC721AQueryable.sol";

interface ITAMG721 is IERC721A, IERC721AQueryable {
  function maxSupply() external view returns (uint256);

  function mint(address to, uint256 amount) external;
}
