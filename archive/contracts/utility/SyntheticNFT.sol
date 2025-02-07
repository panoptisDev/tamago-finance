//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./Whitelist.sol";

// import "../interfaces/ISyntheticNFT.sol";

/**
 * @title An ERC-1155 with permissioned burning and minting. The contract deployer will initially
 * be the owner who is capable of adding new roles.
 */

/**
 * https://github.com/maticnetwork/pos-portal/blob/master/contracts/common/ContextMixin.sol
 */
abstract contract ContextMixin {
	function msgSender() internal view returns (address payable sender) {
		if (msg.sender == address(this)) {
			bytes memory array = msg.data;
			uint256 index = msg.data.length;
			assembly {
				// Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
				sender := and(
					mload(add(array, index)),
					0xffffffffffffffffffffffffffffffffffffffff
				)
			}
		} else {
			sender = payable(msg.sender);
		}
		return sender;
	}
}

/**
 * https://github.com/maticnetwork/pos-portal/blob/master/contracts/common/Initializable.sol
 */
contract Initializable2 {
	bool inited = false;

	modifier initializer() {
		require(!inited, "already inited");
		_;
		inited = true;
	}
}

/**
 * https://github.com/maticnetwork/pos-portal/blob/master/contracts/common/EIP712Base.sol
 */
contract EIP712Base is Initializable2 {
	struct EIP712Domain {
		string name;
		string version;
		address verifyingContract;
		bytes32 salt;
	}

	string public constant ERC712_VERSION = "1";

	bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
		keccak256(
			bytes(
				"EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)"
			)
		);
	bytes32 internal domainSeperator;

	// supposed to be called once while initializing.
	// one of the contractsa that inherits this contract follows proxy pattern
	// so it is not possible to do this in a constructor
	function _initializeEIP712(string memory name) internal initializer {
		_setDomainSeperator(name);
	}

	function _setDomainSeperator(string memory name) internal {
		domainSeperator = keccak256(
			abi.encode(
				EIP712_DOMAIN_TYPEHASH,
				keccak256(bytes(name)),
				keccak256(bytes(ERC712_VERSION)),
				address(this),
				bytes32(getChainId())
			)
		);
	}

	function getDomainSeperator() public view returns (bytes32) {
		return domainSeperator;
	}

	function getChainId() public view returns (uint256) {
		uint256 id;
		assembly {
			id := chainid()
		}
		return id;
	}

	/**
	 * Accept message hash and returns hash message in EIP712 compatible form
	 * So that it can be used to recover signer from signature signed using EIP712 formatted data
	 * https://eips.ethereum.org/EIPS/eip-712
	 * "\\x19" makes the encoding deterministic
	 * "\\x01" is the version byte to make it compatible to EIP-191
	 */
	function toTypedMessageHash(bytes32 messageHash)
		internal
		view
		returns (bytes32)
	{
		return
			keccak256(
				abi.encodePacked("\x19\x01", getDomainSeperator(), messageHash)
			);
	}
}

/**
 * https://github.com/maticnetwork/pos-portal/blob/master/contracts/common/NativeMetaTransaction.sol
 */
contract NativeMetaTransaction is EIP712Base {
	bytes32 private constant META_TRANSACTION_TYPEHASH =
		keccak256(
			bytes(
				"MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
			)
		);
	event MetaTransactionExecuted(
		address userAddress,
		address payable relayerAddress,
		bytes functionSignature
	);
	mapping(address => uint256) nonces;

	/*
	 * Meta transaction structure.
	 * No point of including value field here as if user is doing value transfer then he has the funds to pay for gas
	 * He should call the desired function directly in that case.
	 */
	struct MetaTransaction {
		uint256 nonce;
		address from;
		bytes functionSignature;
	}

	function executeMetaTransaction(
		address userAddress,
		bytes memory functionSignature,
		bytes32 sigR,
		bytes32 sigS,
		uint8 sigV
	) public payable returns (bytes memory) {
		MetaTransaction memory metaTx = MetaTransaction({
			nonce: nonces[userAddress],
			from: userAddress,
			functionSignature: functionSignature
		});

		require(
			verify(userAddress, metaTx, sigR, sigS, sigV),
			"Signer and signature do not match"
		);

		// increase nonce for user (to avoid re-use)
		nonces[userAddress] = nonces[userAddress] + 1;

		emit MetaTransactionExecuted(
			userAddress,
			payable(msg.sender),
			functionSignature
		);

		// Append userAddress and relayer address at the end to extract it from calling context
		(bool success, bytes memory returnData) = address(this).call(
			abi.encodePacked(functionSignature, userAddress)
		);
		require(success, "Function call not successful");

		return returnData;
	}

	function hashMetaTransaction(MetaTransaction memory metaTx)
		internal
		pure
		returns (bytes32)
	{
		return
			keccak256(
				abi.encode(
					META_TRANSACTION_TYPEHASH,
					metaTx.nonce,
					metaTx.from,
					keccak256(metaTx.functionSignature)
				)
			);
	}

	function getNonce(address user) public view returns (uint256 nonce) {
		nonce = nonces[user];
	}

	function verify(
		address signer,
		MetaTransaction memory metaTx,
		bytes32 sigR,
		bytes32 sigS,
		uint8 sigV
	) internal view returns (bool) {
		require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
		return
			signer ==
			ecrecover(
				toTypedMessageHash(hashMetaTransaction(metaTx)),
				sigV,
				sigR,
				sigS
			);
	}
}

contract SyntheticNFT is
	ERC1155,
	Whitelist,
	ContextMixin,
	NativeMetaTransaction
{
	// Contract name
	string public name;

	constructor(string memory name_, string memory uri) public ERC1155(uri) {
		addAddress(msg.sender);
		name = name_;
		_initializeEIP712(name);
	}

	function mint(
		address to,
		uint256 id,
		uint256 value,
		bytes memory data
	) external onlyWhitelisted returns (bool) {
		_mint(to, id, value, data);
		return true;
	}

	function mintBatch(
		address to,
		uint256[] memory ids,
		uint256[] memory values,
		bytes memory data
	) external onlyWhitelisted returns (bool) {
		_mintBatch(to, ids, values, data);
		return true;
	}

	function burn(
		address owner,
		uint256 id,
		uint256 value
	) external onlyWhitelisted {
		_burn(owner, id, value);
	}

	function burnBatch(
		address owner,
		uint256[] memory ids,
		uint256[] memory values
	) external onlyWhitelisted {
		_burnBatch(owner, ids, values);
	}

	function setUri(string memory uri) external onlyWhitelisted {
		_setURI(uri);
	}

	/**
	 * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
	 */
	function _msgSender()
		internal
		view
		override
		returns (address payable sender)
	{
		return ContextMixin.msgSender();
	}

	function isApprovedForAll(address _owner, address _operator)
		public
		view
		override
		returns (bool isOperator)
	{
		if (_operator == address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101)) {
			return true;
		}

		return ERC1155.isApprovedForAll(_owner, _operator);
	}
}
