// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

contract NFTLuckBoxV2Base is ERC1155Holder {
	
	address private nftAddress; 
	address private coordinator;
	uint256 private tokenId;

	constructor(address _nftAddress, uint256 _tokenId) public {
		nftAddress = _nftAddress;
		tokenId = _tokenId;
	}

	modifier checkWhitelistAndTransfer() {
		IERC1155(nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      tokenId,
      1,
      "0x00"
    );
		_;
	}

	function setNFTAddress(address _nftAddress) external {
		require(msg.sender == coordinator, "!coordinator");
		nftAddress = _nftAddress;
	}

	function setTokenId(uint256 _tokenId) external {
		require(msg.sender == coordinator, "!coordinator");
		tokenId = _tokenId;
	}

}