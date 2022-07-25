// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Whitelist is Ownable {
  bytes32 private rootHash;
  bytes32 private rootHashToken;
  mapping(address => bool) public isClaimWhitelisted;

  constructor(bytes32 _rootHash, bytes32 _rootHashToken) {
    rootHash = _rootHash;
    rootHashToken = _rootHashToken;
  }

  function isWhitelisted(bytes32[] memory proof) internal view returns (bool) {
    require(!isClaimWhitelisted[msg.sender], "already claimed !");
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    return MerkleProof.verify(proof, rootHash, leaf);
  }

  function isTokenWhitelisted(bytes32[] memory proof, address assetAddress) internal view returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(assetAddress));
    return MerkleProof.verify(proof, rootHashToken, leaf);
  }

  function setRootHash(bytes32 _rootHash) external onlyOwner {
    require(_rootHash.length > 0, "no proof !");
    rootHash = _rootHash;
  }

  function setRootHashToken(bytes32 _rootHashToken) external onlyOwner {
    require(_rootHashToken.length > 0, "no proof !");
    rootHashToken = _rootHashToken;
  }

  function _setClaimWhitelisted(address claimer) internal {
    isClaimWhitelisted[claimer] = true;
  }
}
