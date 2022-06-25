//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface INFTBroker {
  function getRate(
    address _nftAddress,
    uint256 _fromId,
    uint256 _toId
  ) external view returns (uint8);

  function swap(
    address _nftAddress,
    uint256 _fromId,
    uint256 _toId,
    uint256 _amount
  ) external;
}
