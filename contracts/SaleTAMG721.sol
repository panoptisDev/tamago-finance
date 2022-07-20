// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interfaces/ITAMG721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract SaleTAMG721 is Ownable, ReentrancyGuard {
  uint256 public constant PUBLIC_MINT_AMOUNT = 1;

  ITAMG721 public nft;
  bytes32 public currentPrivateRound;
  bytes32 public merkleRoot;

  bool public isPrivate = false;
  bool public isPublic = false;

  address public signer;

	uint256 public privateAmount;

  mapping(address => mapping(bytes32 => bool)) internal _isPrivateUserMinted;
  mapping(address => mapping(bytes32 => uint256))
    internal _privateUserMintedAmount;
  mapping(address => bool) internal _isPublicUserMinted;

  // Events
  event PrivateMinted(address indexed user, uint256 amount, uint256 timestamp);
  event PublicMinted(address indexed user, uint256 amount, uint256 timestamp);
  event NFTChanged(address oldNFT, address newNFT);
  event MerkleRootChanged(bytes32 merkleRootBefore, bytes32 newMerkleRoot);
  event PrivateRoundChanged(bytes32 oldRound, bytes32 newRound);
  event SignerChanged(address oldSigner, address afterSigner);
  event Withdraw(address to, uint256 balanceOFContract, uint256 timestamp);
  event WithdrawToken(
    address to,
    address currency,
    uint256 balanceOfContract,
    uint256 timestamp
  );
  event PublicMintChanged(bool boolean);
  event PrivateMintChanged(bool boolean);

  constructor(ITAMG721 _nft) {
    setNFT(_nft);
  }

  function setPublicMint(bool _bool) public onlyOwner {
    isPublic = _bool;

    emit PublicMintChanged(_bool);
  }

  function setPrivateMint(bool _bool) public onlyOwner {
    isPrivate = _bool;

    emit PrivateMintChanged(_bool);
  }

  function setNFT(ITAMG721 _nft) public onlyOwner {
    address oldNFT = address(nft);
    nft = _nft;
    address newNFT = address(_nft);
    emit NFTChanged(oldNFT, newNFT);
  }

  function setPrivateRound(bytes32 _round) public onlyOwner {
    bytes32 _oldRound = currentPrivateRound;
    currentPrivateRound = _round;

    emit PrivateRoundChanged(_oldRound, _round);
  }

  function setSigner(address _signer) public onlyOwner {
    address _oldSigner = signer;
    signer = _signer;

    emit SignerChanged(_oldSigner, _signer);
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    bytes32 _oldMerkleRoot = merkleRoot;
    merkleRoot = _merkleRoot;

    emit MerkleRootChanged(_oldMerkleRoot, _merkleRoot);
  }

  function privateMint(
    bytes32[] calldata _proof,
    uint256 _amount,
    bytes32 _round
  ) public payable nonReentrant {
    // This is payable function.

    require(isPrivate == true, "Private mint is not open.");
    require(
      currentPrivateRound == _round,
      "Contract are not in this minting round."
    );
    require(getTotalSupply() + _amount <= privateAmount, "Over supply amount.");
    require(
      isPrivateUserMinted(msg.sender, _round) == false,
      "You are already minted."
    );
    require(
      MerkleProof.verify(
        _proof,
        merkleRoot,
        keccak256(abi.encodePacked(msg.sender, _amount, _round))
      ),
      "Unauthorized whitelist mint this user."
    );

    _isPrivateUserMinted[msg.sender][_round] = true;
    _privateUserMintedAmount[msg.sender][_round] += _amount;

    nft.mint(msg.sender, _amount);

    emit PrivateMinted(msg.sender, _amount, block.timestamp);
  }

  function verifySignature(bytes calldata _signature, address _user)
    public
    view
    returns (bool)
  {
    bytes32 hashMessage = keccak256(abi.encodePacked(_user, address(this)));
    bytes32 message = ECDSA.toEthSignedMessageHash(hashMessage);
    address receivedAddress = ECDSA.recover(message, _signature);

    return receivedAddress != address(0) && receivedAddress == signer;
  }

  function publicMint(bytes calldata _sig) public payable nonReentrant {
    require(isPublic == true, "Public mint is not open.");
    require(tx.origin == msg.sender, "haha Contract can't call me");
    require(isPublicUserMinted(msg.sender) != true, "You are already minted.");
    require(getTotalSupply() + PUBLIC_MINT_AMOUNT <= getMaxSupply(), "Over supply amount");
    require(
      verifySignature(_sig, msg.sender),
      "Unauthorized public mint this user."
    );

    _isPublicUserMinted[msg.sender] = true;

    nft.mint(msg.sender, PUBLIC_MINT_AMOUNT);

    emit PublicMinted(msg.sender, PUBLIC_MINT_AMOUNT, block.timestamp);
  }

  function isPublicUserMinted(address _addr) public view returns (bool) {
    return _isPublicUserMinted[_addr];
  }

  function withdraw(address _to) public onlyOwner {
    uint256 balanceOFContract = address(this).balance;
    require(balanceOFContract > 0, "Insufficient balance");
    (bool status, ) = _to.call{ value: balanceOFContract }("");
    require(status);

    emit Withdraw(_to, balanceOFContract, block.timestamp);
  }

  function withdrawToken(address _to, address _token) public onlyOwner {
    uint256 balanceOfContract = IERC20(_token).balanceOf(address(this));
    require(balanceOfContract > 0, "Insufficient balance");
    IERC20(_token).transfer(_to, balanceOfContract);

    emit WithdrawToken(_to, _token, balanceOfContract, block.timestamp);
  }

  function isPrivateUserMinted(address _user, bytes32 _round)
    public
    view
    returns (bool)
  {
    return _isPrivateUserMinted[_user][_round];
  }

  function privateUserMintedAmount(address _user, bytes32 _round)
    public
    view
    returns (uint256)
  {
    return _privateUserMintedAmount[_user][_round];
  }

  function getTotalSupply() public view returns (uint256) {
    return nft.totalSupply();
  }

  function getMaxSupply() public view returns (uint256) {
    return nft.maxSupply();
  }
}
