// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./utility/Whitelist.sol";
import "./interfaces/IRegistry.sol";
import "./utility/SyntheticNFT.sol";
import "./interfaces/ISyntheticNFT.sol";

/**
 * @title A contract to keep track of all contract in the system
 */

contract Registry is ReentrancyGuard, Whitelist, IRegistry {

    mapping(bytes32 => address) public contracts;
    mapping(uint256 => bytes32) public indexToContract;

    // total contract in the system
    uint256 public override contractCount;

    event ContractAdded(bytes32 name, address contractAddress);
    event ContractUpdated(bytes32 name, address contractAddress);
    event PermittedToMint(address managerAddress, address nftAddress);

    /// @notice register a new contract 
    /// @param _name the name for resolve
    /// @param _contractAddress the contract address
    function registerContract(bytes32 _name, address _contractAddress) public override nonReentrant onlyWhitelisted {
        require( contracts[_name] == address(0) , "The given name is occupied" );
        require(_name != "0x00", "Invalid _name");
        require(_contractAddress != address(0), "Invalid _contractAddress");

        _registerContract(_name, _contractAddress);
    } 

    /// @notice update a contract address from a given name
    /// @param _name the contract name
    /// @param _contractAddress the new contract address
    function updateContract(bytes32 _name, address _contractAddress) public override nonReentrant onlyWhitelisted {
        require( contracts[_name] != address(0) , "The given name is incorrect" );

        _updateContract(_name, _contractAddress);
    }

    /// @notice deploy and register the synthetic NFT contract
    /// @param _name the name for resolve
    /// @param _nftName the name for ERC1155 NFT
    /// @param _nftUri the URI for ERC1155 NFT
    function deploySyntheticNFT(
        bytes32 _name,
        string memory _nftName,
        string memory _nftUri
    ) public nonReentrant onlyWhitelisted {
        require( contracts[_name] == address(0) , "The given name is occupied" );

        // Deploy the synthetic NFT contract
		SyntheticNFT deployedContract = new SyntheticNFT(_nftName, _nftUri);

        _registerContract(_name, address(deployedContract));
    }

    /// @notice give a permission to mint NFTs
    /// @param _nftManagerName the name of the NFT Manager contract
    /// @param _syntheticNftName the name of the synthetic NFT contract
    function permitToMint(bytes32 _nftManagerName, bytes32 _syntheticNftName) public nonReentrant onlyWhitelisted {
        require( contracts[_nftManagerName] != address(0) , "The given _nftManagerName is incorrect" );
        require( contracts[_syntheticNftName] != address(0) , "The given _syntheticNftName is incorrect" );

        address nftAddress = contracts[_syntheticNftName];
        address managerAddress = contracts[_nftManagerName];

        ISyntheticNFT(nftAddress).addAddress(managerAddress);

        emit PermittedToMint(managerAddress, nftAddress);
    }

    /// @notice retrieve a contract address from a given name
    /// @param _name the contract name
    /// @return the contract address 
    function getContractAddress(bytes32 _name) public override view returns (address) {
        require( contracts[_name] != address(0) , "The given name is incorrect" );
        return contracts[_name];
    }

    function _registerContract(bytes32 _name, address _contractAddress) internal {
        contracts[_name] = _contractAddress;

        indexToContract[contractCount] = _name;
        contractCount += 1;

        emit ContractAdded(_name, _contractAddress);
    }

    function _updateContract(bytes32 _name, address _contractAddress) internal {
        contracts[_name] = _contractAddress;

        emit ContractUpdated(_name, _contractAddress);
    }

}
