// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155HolderUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NFTBrokerUpgradeable is
	OwnableUpgradeable,
	ReentrancyGuardUpgradeable,
	ERC1155HolderUpgradeable
{
	struct NFT {
		address assetAddress;
		uint256[] tokenIds;
	}

	NFT[] private nfts;

	//address -> fromId -> toId -> Rate
	mapping(address => mapping(uint256 => mapping(uint256 => uint8)))
		private rates;

	event Deposit(
		address indexed depositor,
		address nftAddress,
		uint256 tokenId,
		uint256 amount
	);

	event Withdraw(
		address indexed withdrawer,
		address nftAddress,
		uint256 tokenId,
		uint256 amount
	);

	event SetRate(address nftAddress, uint256 fromId, uint256 toId, uint8 rate);

	event RemoveRate(address nftAddress, uint256 fromId, uint256 toId);

	event Swap(
		address indexed _swapper,
		address _nftAddress,
		uint256 _fromId,
		uint256 _toId,
		uint256 _amount
	);

	function initialize() external initializer {
		OwnableUpgradeable.__Ownable_init();
		ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
		ERC1155HolderUpgradeable.__ERC1155Holder_init();
	}

	function getNft(uint256 i) public view returns (NFT memory) {
		return nfts[i];
	}

	function swap(
		address _nftAddress,
		uint256 _fromId,
		uint256 _toId,
		uint256 _amount
	) public nonReentrant {
		require(_nftAddress != address(0), "Cannot be address 0");

		uint8 swapRate = getRate(_nftAddress, _fromId, _toId);
		require(swapRate != 0, "Cannot swap because swap rate is 0");

		//get nft
		IERC1155Upgradeable(_nftAddress).safeTransferFrom(
			msg.sender,
			address(this),
			_fromId,
			_amount,
			"0x00"
		);

		//send nft to nft-sender
		IERC1155Upgradeable(_nftAddress).safeTransferFrom(
			address(this),
			msg.sender,
			_toId,
			(swapRate * _amount),
			"0x00"
		);

		emit Swap(msg.sender, _nftAddress, _fromId, _toId, _amount);
	}

	function deposit(
		address _nftAddress,
		uint256 _amount,
		uint256 _tokenId
	) public onlyOwner nonReentrant {
		require(_amount > 0, "Amount cannot be zero");

		IERC1155Upgradeable(_nftAddress).safeTransferFrom(
			msg.sender,
			address(this),
			_tokenId,
			_amount,
			"0x00"
		);

		_addNft(_nftAddress, _tokenId);

		emit Deposit(msg.sender, _nftAddress, _tokenId, _amount);
	}

	function withdraw(
		address _nftAddress,
		uint256 _amount,
		uint256 _tokenId
	) public onlyOwner nonReentrant {
		require(_amount > 0, "Amount cannot be zero");

		IERC1155Upgradeable(_nftAddress).safeTransferFrom(
			address(this),
			msg.sender,
			_tokenId,
			_amount,
			"0x00"
		);

		emit Withdraw(msg.sender, _nftAddress, _tokenId, _amount);
	}

	function setRate(
		address _nftAddress,
		uint256 _fromId,
		uint256 _toId,
		uint8 _rate
	) public onlyOwner nonReentrant {
		require(_nftAddress != address(0), "Cannot be address 0");
		require(_rate > 0, "Rate cannot be less than 0");
		require(_fromId != _toId, "Token id cannot be the same");

		rates[_nftAddress][_fromId][_toId] = _rate;

		emit SetRate(_nftAddress, _fromId, _toId, _rate);
	}

	function removeRate(
		address _nftAddress,
		uint256 _fromId,
		uint256 _toId
	) public onlyOwner nonReentrant {
		require(_nftAddress != address(0), "Cannot be address 0");

		rates[_nftAddress][_fromId][_toId] = 0;

		emit RemoveRate(_nftAddress, _fromId, _toId);
	}

	function getRate(
		address _nftAddress,
		uint256 _fromId,
		uint256 _toId
	) public view returns (uint8) {
		return rates[_nftAddress][_fromId][_toId];
	}

	function _addNft(address _assetAddress, uint256 _tokenId) private {
		uint256[] memory tokenArr;

		if (nfts.length == 0) {
			nfts.push(NFT({ assetAddress: _assetAddress, tokenIds: tokenArr }));
		}

		for (uint256 i = 0; i < nfts.length; i++) {
			NFT storage nft = nfts[i];
			if (nfts[i].assetAddress == _assetAddress) {
				nft.tokenIds.push(_tokenId);
				return;
			} else {
				tokenArr[0] = _tokenId;
				nfts.push(NFT({ assetAddress: _assetAddress, tokenIds: tokenArr }));
				return;
			}
		}
	}
}
