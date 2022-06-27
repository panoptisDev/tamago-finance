// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Multi-chain P2P marketplace
 */

contract NFTMarketplace is
    ReentrancyGuard,
    IERC721Receiver,
    ERC165,
    ERC721Holder,
    ERC1155Holder,
    Pausable
{
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    enum Role {
        UNAUTHORIZED,
        ADMIN,
        RELAYER,
        VALIDATOR
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
        bool isCrosschain; // when true, the order can be fulfilled by the gateway contract
    }

    // Order Id => Order
    mapping(uint256 => Order) public orders;
    // Max. orders can be executed on swapBatch()
    uint256 maxBatchOrders;
    // ACL
    mapping(address => Role) private permissions;
    // Fees
    uint256 public swapFee;
    // Dev address
    address public devAddress;

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

    event OrderCrosschainCreated(uint256 indexed orderId);

    event OrderCanceled(uint256 indexed orderId, address owner);

    event Swapped(uint256 indexed orderId, address fromAddress);

    event SwappedBatch(uint256[] indexed orderId, address fromAddress);

    constructor(address _devAddress) public {
        permissions[_devAddress] = Role.ADMIN;

        maxBatchOrders = 10;

        if (_devAddress != msg.sender) {
            permissions[msg.sender] = Role.ADMIN;
        }

        devAddress = _devAddress;
        // set default fees
        swapFee = 100; // 1%

        _registerInterface(IERC721Receiver.onERC721Received.selector);
    }

    /// @notice create an order and deposit NFT to the contract
    /// @param _orderId ID for the order
    /// @param _assetAddress NFT contract address being listed
    /// @param _tokenId NFT token ID being listed
    /// @param _is1155 NFT's being listed ERC1155 flag
    /// @param _root in the barter list in merkle tree root
    function createOrder(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenId,
        bool _is1155,
        bytes32 _root,
        bool _isCrosschain
    ) external nonReentrant whenNotPaused {
        _createOrder(
            _orderId,
            _assetAddress,
            _tokenId,
            _is1155,
            _root,
            _isCrosschain
        );

        emit OrderCreated(
            _orderId,
            _assetAddress,
            _tokenId,
            _is1155,
            msg.sender,
            _root
        );
    }

    /// @notice create an order and deposit NFT to the contract
    /// @param _orderIds ID for the order
    /// @param _assetAddresses NFT contract address being listed
    /// @param _tokenIds NFT token ID being listed
    /// @param _is1155s NFT's being listed ERC1155 flag
    /// @param _roots in the barter list in merkle tree root
    function createBatchOrders(
        uint256[] calldata _orderIds,
        address[] calldata _assetAddresses,
        uint256[] calldata _tokenIds,
        bool[] calldata _is1155s,
        bytes32[] calldata _roots,
        bool[] calldata _isCrosschains
    ) external whenNotPaused nonReentrant {
        require(maxBatchOrders >= _orderIds.length, "Exceed batch size");

        for (uint256 i = 0; i < _orderIds.length; i++) {
            _createOrder(
                _orderIds[i],
                _assetAddresses[i],
                _tokenIds[i],
                _is1155s[i],
                _roots[i],
                _isCrosschains[i]
            );
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

    /// @notice cancel the order and return NFT back to the original holder
    /// @param _orderId ID that want to cancel
    function cancelOrder(uint256 _orderId) external whenNotPaused nonReentrant {
        require(orders[_orderId].active == true, "Given ID is invalid");
        require(orders[_orderId].owner == msg.sender, "You are not the owner");
        require(
            orders[_orderId].isCrosschain == false,
            "Only admin is allows to cancel a crosschain's order"
        );

        TokenType currentType = TokenType.ERC721;

        if (orders[_orderId].is1155 == true) {
            currentType = TokenType.ERC1155;
        }   

        _give(
            orders[_orderId].assetAddress,
            orders[_orderId].tokenId,
            currentType,
            msg.sender
        );

        orders[_orderId].canceled = true;
        orders[_orderId].ended = true;

        emit OrderCanceled(_orderId, msg.sender);
    }

    function cancelCrosschainOrder(uint256 _orderId, address _to) external onlyAdmin nonReentrant {
        require(orders[_orderId].active == true, "Given ID is invalid");
        require(
            orders[_orderId].isCrosschain == true,
            "You can cancel only a crosschain's order"
        );

        TokenType currentType = TokenType.ERC721;

        if (orders[_orderId].is1155 == true) {
            currentType = TokenType.ERC1155;
        }   

        _give(
            orders[_orderId].assetAddress,
            orders[_orderId].tokenId,
            currentType,
            _to
        );

        orders[_orderId].canceled = true;
        orders[_orderId].ended = true;
    }

    /// @notice check whether the buyer can swap the NFT against given order ID
    /// @param _orderId ID for the order
    /// @param _assetAddress NFT or ERC20 contract address want to swap
    /// @param _tokenIdOrAmount NFT's token ID or ERC20 token amount want to swap
    /// @param _proof the proof generated from off-chain
    function eligibleToSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) external view validateId(_orderId) returns (bool) {
        return
            _eligibleToSwap(_orderId, _assetAddress, _tokenIdOrAmount, _proof);
    }

    /// @notice performs swap the NFT to NFT against given order ID
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

    /// @notice performs swap the NFT against given order ID
    /// @param _orderIds ID for the order
    /// @param _assetAddresses NFT or ERC20 contract address want to swap
    /// @param _tokenIdOrAmounts NFT's token ID or ERC20 token amount want to swap
    /// @param _tokenTypes Token type that want to swap
    /// @param _proofs the proof generated from off-chain
    function swapBatch(
        uint256[] calldata _orderIds,
        address[] calldata _assetAddresses,
        uint256[] calldata _tokenIdOrAmounts,
        TokenType[] calldata _tokenTypes,
        bytes32[][] calldata _proofs
    ) external validateIds(_orderIds) whenNotPaused nonReentrant {
        for (uint256 i = 0; i < _orderIds.length; i++) {
            _swap(
                _orderIds[i],
                _assetAddresses[i],
                _tokenIdOrAmounts[i],
                _tokenTypes[i],
                _proofs[i]
            );
        }

        emit SwappedBatch(_orderIds, msg.sender);
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

    // set max. orders can be created and swapped per time
    function setMaxBatchOrders(uint256 _value) external onlyAdmin {
        require(_value != 0, "Invalid value");
        maxBatchOrders = _value;
    }

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

    // INTERNAL FUNCTIONS

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

    modifier onlyAdmin() {
        require(
            permissions[msg.sender] == Role.ADMIN,
            "Caller is not the admin"
        );
        _;
    }

    modifier onlyRelayer() {
        require(
            permissions[msg.sender] == Role.RELAYER,
            "Caller is not the relayer"
        );
        _;
    }

    modifier onlyValidator() {
        require(
            permissions[msg.sender] == Role.VALIDATOR,
            "Caller is not the validator"
        );
        _;
    }

    function _eligibleToSwap(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        require(
            orders[_orderId].isCrosschain == false,
            "Your order can be fulfilled by gateway contract only"
        );
        bytes32 leaf = keccak256(
            abi.encodePacked(_assetAddress, _tokenIdOrAmount)
        );
        return MerkleProof.verify(_proof, orders[_orderId].root, leaf);
    }

    function _createOrder(
        uint256 _orderId,
        address _assetAddress,
        uint256 _tokenId,
        bool _is1155,
        bytes32 _root,
        bool _isCrosschain
    ) internal {
        require(orders[_orderId].active == false, "Given ID is occupied");

        orders[_orderId].active = true;
        orders[_orderId].assetAddress = _assetAddress;
        orders[_orderId].tokenId = _tokenId;
        orders[_orderId].is1155 = _is1155;
        orders[_orderId].root = _root;
        orders[_orderId].owner = msg.sender;
        orders[_orderId].isCrosschain = _isCrosschain;

        TokenType currentType = TokenType.ERC721;

        if (_is1155) {
            currentType = TokenType.ERC1155;
        }

        _take(_assetAddress, _tokenId, currentType, address(this));

        if (_isCrosschain) {
            emit OrderCrosschainCreated(_orderId);
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
            orders[_orderId].assetAddress,
            orders[_orderId].tokenId,
            nftType,
            msg.sender
        );

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
            IERC721(_assetAddress).safeTransferFrom(msg.sender, _to, _tokenIdOrAmount);
        } else {
            // taking swap fees
            if (swapFee != 0) {
                uint256 fee = _tokenIdOrAmount.mul(swapFee).div(10000);
                IERC20(_assetAddress).safeTransferFrom( msg.sender , devAddress, fee );
            }

            IERC20(_assetAddress).safeTransferFrom( msg.sender , _to, _tokenIdOrAmount );
        }
    }

    function _give(
        address _assetAddress,
        uint256 _tokenIdOrAmount,
        TokenType _type,
        address _to
    ) internal {
        if (_type == TokenType.ERC1155) {
            IERC1155(_assetAddress).safeTransferFrom(
                address(this),
                _to,
                _tokenIdOrAmount,
                1,
                "0x00"
            );
        } else if (_type == TokenType.ERC721) { 
            IERC721(_assetAddress).safeTransferFrom(
                address(this),
                _to,
                _tokenIdOrAmount
            );
        } else {
            IERC20(_assetAddress).safeTransferFrom( address(this), msg.sender , _tokenIdOrAmount );
        }
    }
}
