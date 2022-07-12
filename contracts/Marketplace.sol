// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;


import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol"; 
import "./interfaces/IGateway.sol";

/**
 * @title Multi-Chain Marketplace
 */

contract Marketplace is
    ReentrancyGuard,
    IERC721Receiver,
    ERC721Holder,
    ERC1155Holder,
    Pausable
{
    using Address for address;
    using SafeERC20 for IERC20;

    enum Role {
        UNAUTHORIZED,
        ADMIN
    }

    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Order {
        address assetAddress;
        uint256 tokenId;
        bool is1155;
        address owner;
        bytes32 root;
        bool canceled;
        bool ended;
        bool active;
    }

    // order that's half-fulfilled at destination chain
    struct PartialOrder {
        bool active;
        bool ended;
        address buyer;
        address assetAddress;
        uint256 tokenIdOrAmount;
        TokenType tokenType;
    }

    // ACL
    mapping(address => Role) private permissions;
    // Gateway contract
    IGateway private gateway;
    // Fees (when claim with ERC-20)
    uint256 public swapFee;
    // Dev address
    address public devAddress;
    // Order Id => Order
    mapping(uint256 => Order) public orders;
    // Partially fulfilled orders (orderId -> struct)
    mapping(uint256 => PartialOrder) public partialOrders;
    // Max. orders can be executed on swapBatch()
    uint256 maxBatchOrders;

    event OrderCreated(
        uint256 indexed orderId,
        address assetAddress,
        uint256 tokenId,
        bool is1155,
        address owner,
        bytes32 root
    );
    event OrderCreatedBatch(
        uint256[] indexed orderIds,
        address[] assetAddresses,
        uint256[] tokenIds,
        bool[] is1155s,
        address owner,
        bytes32[] roots
    );

    event OrderCanceled(uint256 indexed orderId, address owner);
    event OrderCanceledBatch(uint256[] indexed orderId, address owner);
    event Swapped(uint256 indexed orderId, address fromAddress);
    event SwappedBatch(uint256[] indexed orderIds, address fromAddress);
    event PartialSwapped(uint256 indexed orderId, address fromAddress);
    event PartialSwappedBatch(uint256[] indexed orderIds, address fromAddress);
    event Claimed(uint256 indexed orderId, address fromAddress, bool isOriginChain);
    event ClaimedBatch(uint256[] indexed orderIds, address fromAddress, bool isOriginChain);

    constructor(address _devAddress, address _gatewayAddress) {
        gateway = IGateway(_gatewayAddress);
        devAddress = _devAddress;

        maxBatchOrders = 20;

        permissions[_devAddress] = Role.ADMIN;

        if (_devAddress != msg.sender) {
            permissions[msg.sender] = Role.ADMIN;
        }

        // set swap fees for ERC-20
        // swapFee = 100; // 1%
    }

    /// @notice create an order 
    /// @param _orderId ID for the order
    /// @param _assetAddress NFT contract address being listed
    /// @param _tokenId NFT token ID being listed
    /// @param _is1155 NFT's being listed ERC1155 flag
    /// @param _root in the barter list in merkle tree root
    function create(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenId,
        bool _is1155,
        bytes32 _root
    ) external nonReentrant whenNotPaused {
        _create(_orderId, _assetAddress, _tokenId, _is1155, _root);

        emit OrderCreated(
            _orderId,
            _assetAddress,
            _tokenId,
            _is1155,
            msg.sender,
            _root
        );
    }

    /// @notice create multiple orders
    /// @param _orderIds ID for the order
    /// @param _assetAddresses NFT contract address being listed
    /// @param _tokenIds NFT token ID being listed
    /// @param _is1155s NFT's being listed ERC1155 flag
    /// @param _roots in the barter list in merkle tree root
    function createBatch(
        uint256[] calldata _orderIds,
        address[] calldata _assetAddresses,
        uint256[] calldata _tokenIds,
        bool[] calldata _is1155s,
        bytes32[] calldata _roots
    ) external nonReentrant whenNotPaused {
        require(maxBatchOrders >= _orderIds.length, "Exceed batch size");

        for (uint256 i = 0; i < _orderIds.length; i++) {
            _create(_orderIds[i], _assetAddresses[i], _tokenIds[i], _is1155s[i], _roots[i]);
        }

        emit OrderCreatedBatch(
            _orderIds,
            _assetAddresses,
            _tokenIds,
            _is1155s,
            msg.sender,
            _roots
        );
    }

    /// @notice cancel the order
    /// @param _orderId ID that want to cancel
    function cancel(uint256 _orderId) external whenNotPaused nonReentrant {
        
        _cancel(_orderId);

        emit OrderCanceled(_orderId, msg.sender);
    }

    /// @notice cancel multiple orders
    /// @param _orderIds ID that want to cancel
    function cancelBatch(uint256[] calldata _orderIds) external whenNotPaused nonReentrant {
        
        for (uint256 i = 0; i < _orderIds.length; i++) {
           _cancel(_orderIds[i]);
        }

        emit OrderCanceledBatch(_orderIds, msg.sender);
    }

    /// @notice buy the NFT from the given order ID
    /// @param _orderId ID for the order
    /// @param _assetAddress NFT or ERC20 contract address want to swap
    /// @param _tokenIdOrAmount NFT's token ID or ERC20 token amount want to swap
    /// @param _type Token type that want to swap
    /// @param _proof the proof generated from off-chain
    function swap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        bytes32[] memory _proof
    ) external validateId(_orderId) whenNotPaused nonReentrant {
        _swap(_orderId, _assetAddress, _tokenIdOrAmount, _type, _proof);

        emit Swapped(_orderId, msg.sender);
    }

    /// @notice buy the NFT in batch
    /// @param _orderIds ID for the order
    /// @param _assetAddresses NFT or ERC20 contract address want to swap
    /// @param _tokenIdOrAmounts NFT's token ID or ERC20 token amount want to swap
    /// @param _types Token type that want to swap
    /// @param _proofs the proof generated from off-chain
    function swapBatch(
        uint256[] calldata _orderIds,
        address[] calldata _assetAddresses,
        uint256[] calldata _tokenIdOrAmounts,
        TokenType[] calldata _types,
        bytes32[][] calldata _proofs
    ) validateIds(_orderIds) external whenNotPaused nonReentrant {
            
        for (uint256 i = 0; i < _orderIds.length; i++) {
            _swap(
                _orderIds[i],
                _assetAddresses[i],
                _tokenIdOrAmounts[i],
                _types[i],
                _proofs[i]
            );
        }

        emit SwappedBatch(_orderIds, msg.sender);
    }

    // cross-chain swaps, deposit the NFT on the destination chain and wait for the validator to approve the claim
    function partialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        bytes32[] memory _proof
    ) external whenNotPaused nonReentrant {
        _partialSwap(_orderId, _assetAddress, _tokenIdOrAmount, _type, _proof);

        emit PartialSwapped(_orderId, msg.sender);
    }

    // cross-chain swaps in batch
     function partialSwapBatch(
        uint256[] calldata _orderIds,
        address[] calldata _assetAddresses,
        uint256[] calldata _tokenIdOrAmounts,
        TokenType[] calldata _types,
        bytes32[][] calldata _proofs
    ) external whenNotPaused nonReentrant {

        for (uint256 i = 0; i < _orderIds.length; i++) {
            _partialSwap(_orderIds[i], _assetAddresses[i], _tokenIdOrAmounts[i], _types[i], _proofs[i]);
        }

        emit PartialSwappedBatch(_orderIds, msg.sender);
    }

    // check whether can do intra-chain swaps
    function eligibleToSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) external view validateId(_orderId) returns (bool) {
        return
            _eligibleToSwap(_orderId, _assetAddress, _tokenIdOrAmount, _proof);
    }

    // check if the caller can claim the NFT (that approved by the validator )
    function eligibleToClaim(
        uint256 _orderId,
        address _claimer,
        bool _isOriginChain,
        bytes32[] memory _proof
    ) external view returns (bool) {
        return _eligibleToClaim(_orderId, _claimer, _isOriginChain, _proof);
    }

    // check if the caller can deposit the nft
    function eligibleToPartialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) external view returns (bool) {
        return
            _eligibleToPartialSwap(
                _orderId,
                _assetAddress,
                _tokenIdOrAmount,
                _proof
            );
    }

    // claim the NFT (that approved by the validator )
    function claim(
        uint256 _orderId,
        bool _isOriginChain,
        bytes32[] memory _proof
    ) external whenNotPaused nonReentrant {
        
        _claim(_orderId, _isOriginChain, _proof);

        emit Claimed( _orderId, msg.sender, _isOriginChain );
    }

    function claimBatch(
        uint256[] calldata _orderIds,
        bool _isOriginChain,
        bytes32[][] calldata _proofs
    ) external whenNotPaused nonReentrant {
        
        for (uint256 i = 0; i < _orderIds.length; i++) {
            _claim(_orderIds[i], _isOriginChain, _proofs[i]);
        }
        
        emit ClaimedBatch(_orderIds, msg.sender, _isOriginChain);
    }

    // ADMIN FUNCTIONS

    // give a specific permission to the given address
    function grant(address _address, Role _role) external onlyAdmin {
        require(_address != msg.sender, "You cannot grant yourself");
        permissions[_address] = _role;
    }

    // remove any permission binded to the given address
    function revoke(address _address) external onlyAdmin {
        require(_address != msg.sender, "You cannot revoke yourself");
        permissions[_address] = Role.UNAUTHORIZED;
    }

    // pause the contract
    function setPaused() external onlyAdmin whenNotPaused {
        _pause();
    }

    // unpause the contract
    function setUnpaused() external onlyAdmin whenPaused {
        _unpause();
    }

    // update dev address
    function setDevAddress(address _devAddress) external onlyAdmin {
        devAddress = _devAddress;
    }

    // update swap fees
    function setSwapFee(uint256 _fee) external onlyAdmin {
        swapFee = _fee;
    }

    // only admin can cancel the partial swap 
    function cancelPartialSwap(uint256 _orderId, address _to)
        external
        onlyAdmin
        nonReentrant
    {
        require(partialOrders[_orderId].active == true, "Invalid order");

        _give(
            partialOrders[_orderId].buyer,
            partialOrders[_orderId].assetAddress,
            partialOrders[_orderId].tokenIdOrAmount,
            partialOrders[_orderId].tokenType,
            _to
        );

        partialOrders[_orderId].active = false;
    }

    // set max. orders can be created and swapped per time
    function setMaxBatchOrders(uint256 _value) external onlyAdmin {
        require(_value != 0, "Invalid value");
        maxBatchOrders = _value;
    }


    // INTERNAL FUCNTIONS

    modifier onlyAdmin() {
        require(
            permissions[msg.sender] == Role.ADMIN,
            "Caller is not the admin"
        );
        _;
    }

    modifier validateId(uint256 _orderId) {
        require(orders[_orderId].active == true, "Given ID is invalid");
        require(
            orders[_orderId].canceled == false,
            "The order has been cancelled"
        );
        require(
            orders[_orderId].ended == false,
            "The order has been fulfilled"
        );
        _;
    }

    modifier validateIds(uint256[] memory _orderIds) {
        require(maxBatchOrders >= _orderIds.length, "Exceed batch size");
        for (uint256 i = 0; i < _orderIds.length; i++) {
            require(orders[i].active == true, "Given ID is invalid");
            require(
                orders[i].canceled == false,
                "The order has been cancelled"
            );
            require(orders[i].ended == false, "The order has been fulfilled");
        }
        _;
    }

    function _create(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenId,
        bool _is1155,
        bytes32 _root
    ) internal {
        require(orders[_orderId].active == false, "Given ID is occupied");

        orders[_orderId].active = true;
        orders[_orderId].assetAddress = _assetAddress;
        orders[_orderId].tokenId = _tokenId;
        orders[_orderId].is1155 = _is1155;
        orders[_orderId].root = _root;
        orders[_orderId].owner = msg.sender;

        TokenType currentType = TokenType.ERC721;

        if (_is1155) {
            currentType = TokenType.ERC1155;
        }
        
    }

    function _swap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenId,
        TokenType _type,
        bytes32[] memory _proof
    ) internal {
        require(
            _eligibleToSwap(_orderId, _assetAddress, _tokenId, _proof) == true,
            "The caller is not eligible to claim the NFT"
        );

        // taking NFT
        _take(_assetAddress, _tokenId, _type, orders[_orderId].owner);

        // giving NFT
        TokenType nftType = TokenType.ERC721;
        if (orders[_orderId].is1155 == true) {
            nftType = TokenType.ERC1155;
        }
        _give(
            orders[_orderId].owner,
            orders[_orderId].assetAddress,
            orders[_orderId].tokenId,
            nftType,
            msg.sender
        );

        orders[_orderId].ended = true;
    }

    function _partialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        bytes32[] memory _proof
    ) internal {
        require(
            partialOrders[_orderId].active == false,
            "The order is already active"
        );
        require(
            _eligibleToPartialSwap(
                _orderId,
                _assetAddress,
                _tokenIdOrAmount,
                _proof
            ) == true,
            "The caller is not eligible to claim the NFT"
        );

        // deposit NFT or tokens until the NFT locked in the origin chain is being transfered to the buyer
        _take(_assetAddress, _tokenIdOrAmount, _type, address(this));

        partialOrders[_orderId].active = true;
        partialOrders[_orderId].buyer = msg.sender;
        partialOrders[_orderId].assetAddress = _assetAddress;
        partialOrders[_orderId].tokenIdOrAmount = _tokenIdOrAmount;
        partialOrders[_orderId].tokenType = _type;
    }

    function _claim(
        uint256 _orderId,
        bool _isOriginChain,
        bytes32[] memory _proof
    ) internal {
        require(
            _eligibleToClaim(_orderId, msg.sender, _isOriginChain, _proof) ==
                true,
            "The caller is not eligible to claim the NFT"
        );

        // giving NFT
        if (_isOriginChain == true) {
            TokenType nftType = TokenType.ERC721;
            if (orders[_orderId].is1155 == true) {
                nftType = TokenType.ERC1155;
            }
            _give(
                orders[_orderId].owner,
                orders[_orderId].assetAddress,
                orders[_orderId].tokenId,
                nftType,
                msg.sender
            );

            orders[_orderId].ended = true;
        } else {
            _give(
                address(this),
                partialOrders[_orderId].assetAddress,
                partialOrders[_orderId].tokenIdOrAmount,
                partialOrders[_orderId].tokenType,
                msg.sender
            );

            partialOrders[_orderId].ended = true;
        }

    }

    function _eligibleToSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) internal view returns (bool) { 
        bytes32 leaf = keccak256(
            abi.encodePacked(_assetAddress, _tokenIdOrAmount)
        );
        return MerkleProof.verify(_proof, orders[_orderId].root, leaf);
    }

    function _eligibleToPartialSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(
            abi.encodePacked(
                _orderId,
                gateway.chainId(),
                _assetAddress,
                _tokenIdOrAmount
            )
        );
        return MerkleProof.verify(_proof, gateway.relayRoot(), leaf);
    }

    function _eligibleToClaim(
        uint256 _orderId,
        address _claimer,
        bool _isOriginChain,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(
            abi.encodePacked(
                _orderId,
                gateway.chainId(),
                _claimer,
                _isOriginChain
            )
        );
        return MerkleProof.verify(_proof, gateway.claimRoot(), leaf);
    }

    function _cancel(uint256 _orderId) internal {
        require(orders[_orderId].active == true, "Given ID is invalid");
        require(orders[_orderId].owner == msg.sender, "You are not the owner");

        TokenType currentType = TokenType.ERC721;

        if (orders[_orderId].is1155 == true) {
            currentType = TokenType.ERC1155;
        }

        orders[_orderId].canceled = true;
        orders[_orderId].ended = true;
    }

    function _take(
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        address _to
    ) internal {
        if (_type == TokenType.ERC1155) {
            IERC1155(_assetAddress).safeTransferFrom(
                msg.sender,
                _to,
                _tokenIdOrAmount,
                1,
                "0x00"
            );
        } else if (_type == TokenType.ERC721) {
            IERC721(_assetAddress).safeTransferFrom(
                msg.sender,
                _to,
                _tokenIdOrAmount
            );
        } else {
            // taking swap fees
            if (swapFee != 0) {
                uint256 fee = (_tokenIdOrAmount * (swapFee)) / (10000);
                IERC20(_assetAddress).safeTransferFrom(
                    msg.sender,
                    devAddress,
                    fee
                );
            }

            IERC20(_assetAddress).safeTransferFrom(
                msg.sender,
                _to,
                _tokenIdOrAmount
            );
        }
    }

    function _give(
        address _fromAddress,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        address _to
    ) internal {
        if (_type == TokenType.ERC1155) {
            IERC1155(_assetAddress).safeTransferFrom(
                _fromAddress,
                _to,
                _tokenIdOrAmount,
                1,
                "0x00"
            );
        } else if (_type == TokenType.ERC721) {
            IERC721(_assetAddress).safeTransferFrom(
                _fromAddress,
                _to,
                _tokenIdOrAmount
            );
        } else {

            if (_fromAddress == address(this)) {
                IERC20(_assetAddress).safeTransfer(
                    msg.sender,
                    _tokenIdOrAmount
                );
            } else {
                IERC20(_assetAddress).safeTransferFrom(
                    _fromAddress,
                    msg.sender,
                    _tokenIdOrAmount
                );
            }
 
            
        }
    }
}
