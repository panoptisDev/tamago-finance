// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./utility/LibMath.sol";
import "./utility/WhitelistUpgradeable.sol";
import "./utility/SyntheticNFT.sol";
import "./interfaces/IPriceResolver.sol";
import "./interfaces/ISyntheticNFT.sol";
import "./interfaces/INFTManager.sol";
import "./interfaces/IRegistry.sol";

/**
 * @title A contract to collaterizes ERC-20 and mints NFT
 */

contract NFTManagerUpgradeable is
    Initializable,
    ReentrancyGuardUpgradeable,
    WhitelistUpgradeable,
    INFTManager,
    ERC1155HolderUpgradeable,
    PausableUpgradeable
{
    using LibMathSigned for int256;
    using LibMathUnsigned for uint256;

    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct CollateralAsset {
        // name of the collateral
        string name;
        // Price feeder name
        bytes32 priceFeeder;
        // ERC-20 contract address
        address tokenAddress;
        // ERC-20 decimals
        uint8 decimals;
        // status
        bool disabled;
    }

    struct SyntheticVariant {
        // name of the variant
        string name;
        // token id for this variant
        uint256 tokenId;
        // value
        uint256 tokenValue;
        // raw collateral on this variant
        mapping(uint8 => uint256) totalRawCollateral;
        // total tokens that been minted
        uint256 totalOutstanding;
        // total tokens that been issued
        uint256 totalIssued;
        // total tokens that been burnt
        uint256 totalBurnt;
        // active status
        bool disabled;
    }

    // Registry contract
    IRegistry public registry;
    // Price resolver contract.
    IPriceResolver public priceResolver;
    // Synthetic NFT created by this contract.
    ISyntheticNFT public override syntheticNFT;
    // Collateral currencies that supported
    mapping(uint8 => CollateralAsset) public collaterals;
    // Total Collateral Assets
    uint8 public collateralCount;
    // Synthetic NFT variants
    mapping(uint8 => SyntheticVariant) public syntheticVariants;
    // Total Synthetic NFT variants
    uint8 public syntheticVariantCount;
    // Target currency in the registry
    bytes32 public targetCurrency;

    // Total raw collateral
    mapping(uint8 => uint256) public totalRawCollateral;
    // Total NFT synthetics outstanding
    uint256 public totalOutstanding;
    // Dev address
    address public devAddress;
    // Fees
    uint256 public mintFee;
    uint256 public redeemFee;
    uint256 public offsetFee;
    uint256 public discountFee;

    // Router
    address public ROUTER_ADDRESS;
    // max NFT that can be minted per time
    uint256 maxNft;

    int256 constant ONE_ETHER = 10**18;
    uint256 constant UNSIGNED_ONE_ETHER = 10**18;
    uint256 constant TEN_KWEI = 10000;
    uint256 constant MAX_UINT256 = uint256(-1);

    int256 constant BASE = 10 ether;
    int256 constant K = 9.3 ether;

    event PositionCreated(
        address minter,
        uint8 variantId,
        uint8 collateralId,
        uint256 tokenValue,
        uint256 collateralAmount,
        uint256 tokenAmount
    );

    event PositionRemoved(
        address minter,
        uint8 variantId,
        uint8 collateralId,
        uint256 tokenValue,
        uint256 collateralAmount,
        uint256 tokenAmount
    );

    /// @notice the contructor
    /// @param _registryAddress the address of the registry contract
    /// @param _devAddress dev address
    function initialize(
        address _registryAddress,
        bytes32 _targetCurrency,
        bytes32 _priceResolver,
        bytes32 _syntheticNFT,
        address _devAddress
    ) external initializer {
        ERC1155HolderUpgradeable.__ERC1155Holder_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        WhitelistUpgradeable.__Whitelist_init();
        PausableUpgradeable.__Pausable_init();

        // set initial params
        targetCurrency = _targetCurrency;
        registry = IRegistry(_registryAddress);

        priceResolver = IPriceResolver(
            registry.getContractAddress(_priceResolver)
        );

        devAddress = _devAddress;

        maxNft = 100;

        // set default fees
        mintFee = 100; // 1.0%
        redeemFee = 100; // 1.0%
        // discountFee = 100;  // 1.0%
        offsetFee = 100; // 1.0%

        // Deploy the synthetic NFT contract
        syntheticNFT = ISyntheticNFT(
            registry.getContractAddress(_syntheticNFT)
        );

        // add dev into the whitelist
        addAddress(_devAddress);

        if (_devAddress != msg.sender) {
            addAddress(msg.sender);
        }
    }

    /// @notice calculate amount of collateral assets to be placed for minting the NFT
    /// @param _variantId the NFT's variant id
    /// @param _collateralId the collateral asset to use
    /// @param _tokenAmount total NFT to be created
    /// @return amount the amount of the collateral need for minting
    function estimateMint(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _tokenAmount
    )
        public
        view
        validateId(_variantId, _collateralId, _tokenAmount)
        returns (uint256 amount)
    {
        amount = _estimateMint(
            _variantId,
            _collateralId,
            _tokenAmount
        );
    }

    /// @notice calculate amount of collateral assets to be returned when burning NFT
    /// @param _variantId the NFT's variant id
    /// @param _collateralId the collateral asset to use
    /// @param _tokenAmount total NFT to be burnt
    /// @return amount amount of collateral to be returned
    function estimateRedeem(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _tokenAmount
    )
        public
        view
        validateId(_variantId, _collateralId, _tokenAmount)
        returns (uint256 amount)
    {
        amount = _estimateRedeem(
            _variantId,
            _collateralId,
            _tokenAmount
        );
    }

    /// @notice taking collateral tokens to mint the NFT
    /// @param _variantId the NFT's variant id
    /// @param _collateralId the collateral id
    /// @param _tokenAmount total NFT to be created
    /// @param _maxCollateralAmount cap. amount of token that can be sent out from the wallet
    function mint(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _tokenAmount,
        uint256 _maxCollateralAmount
    )
        public
        nonReentrant
        validateId(_variantId, _collateralId, _tokenAmount)
        whenNotPaused
    {
        uint256 amount  = _estimateMint(
            _variantId,
            _collateralId,
            _tokenAmount
        );

        require(
            _maxCollateralAmount >= amount,
            "Exceeding _maxCollateralAmount"
        );

        uint256 fee = amount.mul(mintFee).div(10000);

        // takes ERC-20 tokens
        IERC20Upgradeable(collaterals[_collateralId].tokenAddress)
            .safeTransferFrom(msg.sender, address(this), amount);
        // send a fee to dev
        IERC20Upgradeable(collaterals[_collateralId].tokenAddress).transfer( devAddress, fee );
        
        _createPosition(_variantId, _collateralId, amount.sub(fee), _tokenAmount);

        // mint NFT back to the minter
        syntheticNFT.mint(
            msg.sender,
            syntheticVariants[_variantId].tokenId,
            _tokenAmount,
            _toBytes(0)
        );
    }

    /// @notice burning NFT and returning collateral assets, the offset fee will be charged when CR < 1
    /// @param _variantId the NFT's variant id
    /// @param _collateralId the collateral id
    /// @param _tokenAmount total NFT to be burnt
    /// @param _minAmount min. amount of collateral token expects to receive
    function redeem(
    	uint8 _variantId,
        uint8 _collateralId,
    	uint256 _tokenAmount,
        uint256 _minAmount
    ) public nonReentrant validateId(_variantId, _collateralId, _tokenAmount) whenNotPaused {
    	uint256 amount = _estimateRedeem(_variantId, _collateralId, _tokenAmount);

        require(
            amount >= _minAmount,
            "_minAmount is not reached"
        );

    	_removePosition(_variantId, _collateralId , amount, _tokenAmount);

    	// burn NFT
    	syntheticNFT.safeTransferFrom(
    		msg.sender,
    		address(this),
    		syntheticVariants[_variantId].tokenId,
    		_tokenAmount,
    		_toBytes(0)
    	);
    	syntheticNFT.burn(
    		address(this),
    		syntheticVariants[_variantId].tokenId,
    		_tokenAmount
    	);

        IERC20Upgradeable(collaterals[_collateralId].tokenAddress).transfer(
    			msg.sender,
    			amount
    	);
        // send tokens to dev
        if (redeemFee != 0) {
            uint256 fee = amount.mul(redeemFee).div(10000);
            IERC20Upgradeable(collaterals[_collateralId].tokenAddress).transfer( devAddress, fee );
        }

    }

    /// @notice call the price feeder registry to retrieve the latest price of NFT
    /// @return US price per a synthetic token
    function getSyntheticPrice() public view returns (uint256) {
        return _getSyntheticPrice();
    }

    /// @notice call the price feeder registry to retrieve the latest price of collateral token
    /// @param _collateralId the collateral id
    /// @return US price per a collateral token
    function getCollateralPrice(uint8 _collateralId)
        public
        view
        returns (uint256)
    {
        return _getCollateralPrice(_collateralId);
    }

    /// @notice check variant collateral
    /// @param _collateralId the collateral id
    /// @return amount total amount of collateral
    function getVariantCollateral(uint8 _variantId, uint8 _collateralId)
        public
        view
        returns (uint256)
    {
        return syntheticVariants[_variantId].totalRawCollateral[_collateralId];
    }

    

    /// @notice looks for the system collateral ratio basically calculates from total collateral deposited / total NFT minted
    /// @return the system collateral ratio
    function globalCollatelizationRatio() public view returns (uint256) {
        return _globalCollatelizationRatio();
    }

    /// @notice calculates the collateral ratio for particular variant
    /// @param _id the NFT's variant id
    /// @return the variant collateral ratio
    function variantCollatelizationRatio(uint8 _id)
        public
        view
        returns (uint256)
    {
        return _variantCollatelizationRatio(_id);
    }

    /// @notice calculates the normalized collateral ratio
    /// @return the target ratio when CR < 1
    /// @return the target ratio when CR > 1
    function targetCollatelizationRatio() public view returns (int256, int256) {
        return _targetCollatelizationRatio();
    }

    // ONLY ADMIN CAN PROCEED

    // pause the contract
    function setPaused() public onlyWhitelisted whenNotPaused {
        _pause();
    }

    // unpause the contract
    function setUnpaused() public onlyWhitelisted whenPaused {
        _unpause();
    }

    // add NFT variant
    function addSyntheticVariant(
        string memory _name,
        uint256 _tokenId,
        uint256 _tokenValue
    ) public nonReentrant onlyWhitelisted {

        syntheticVariants[syntheticVariantCount].name = _name;
        syntheticVariants[syntheticVariantCount].tokenId = _tokenId;
        syntheticVariants[syntheticVariantCount].tokenValue = _tokenValue;

        syntheticVariantCount += 1;
    }

    function setSyntheticNFT(address _syntheticNFT)
        public
        nonReentrant
        onlyWhitelisted
    {
        require(_syntheticNFT != address(0), "!address(0)");
        syntheticNFT = ISyntheticNFT(_syntheticNFT);
    }

    // enable/disable synthetic NFT variant
    function setSyntheticVariantDisable(uint8 _id, bool _disabled)
        public
        nonReentrant
        onlyWhitelisted
    {
        require(syntheticVariantCount > _id, "Invalid given _id");
        syntheticVariants[_id].disabled = _disabled;
    }

    // Add collateral asset to be supported
    function addCollateralAsset(
        string memory _name,
        bytes32 _priceFeeder,
        address _tokenAddress,
        uint8 _decimals
    ) public nonReentrant onlyWhitelisted {
        require( 18 >= _decimals, "_decimals should not be exceeded 18" );

        collaterals[collateralCount].name = _name;
        collaterals[collateralCount].priceFeeder = _priceFeeder;
        collaterals[collateralCount].tokenAddress = _tokenAddress;
        collaterals[collateralCount].decimals = _decimals;

        collateralCount += 1;
    }

    // enable/disable synthetic NFT variant
    function setCollateralAssetDisable(uint8 _id, bool _disabled)
        public
        nonReentrant
        onlyWhitelisted
    {
        require(collateralCount > _id, "Invalid given _id");
        collaterals[collateralCount].disabled = _disabled;
    }

    // emergency withdraw ERC-20 tokens out of the contract
    function withdrawErc20(address _tokenAddress, uint256 _amount)
        public
        nonReentrant
        onlyWhitelisted
    {
        IERC20Upgradeable(_tokenAddress).transfer(msg.sender, _amount);
    }

    // force mint ERC-1155
    function forceMint(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _collateralAmount,
        uint256 _tokenAmount
    )
        public
        nonReentrant
        onlyWhitelisted
        validateId(_variantId, _collateralId, _tokenAmount)
        whenNotPaused
    {
        _createPosition(
            _variantId,
            _collateralId,
            _collateralAmount,
            _tokenAmount
        );

        // take collaterals
        IERC20Upgradeable(collaterals[_collateralId].tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _collateralAmount
            );

        // mint NFT back to the minter
        syntheticNFT.mint(
            msg.sender,
            syntheticVariants[_variantId].tokenId,
            _tokenAmount,
            _toBytes(0)
        );
    }

    // force burn ERC-1155
    function forceRedeem(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _collateralAmount,
        uint256 _tokenAmount
    )
        public
        nonReentrant
        onlyWhitelisted
        validateId(_variantId, _collateralId, _tokenAmount)
        whenNotPaused
    {
        _removePosition(
            _variantId,
            _collateralId,
            _collateralAmount,
            _tokenAmount
        );

        // burn NFT
        syntheticNFT.safeTransferFrom(
            msg.sender,
            address(this),
            syntheticVariants[_variantId].tokenId,
            _tokenAmount,
            _toBytes(0)
        );
        syntheticNFT.burn(
            address(this),
            syntheticVariants[_variantId].tokenId,
            _tokenAmount
        );

        // return collaterals back to the minter
        IERC20Upgradeable(collaterals[_collateralId].tokenAddress).transfer(
            msg.sender,
            _collateralAmount
        );
    }

    // update the price resolver contract
    function setPriceResolver(address _priceResolverAddress)
        public
        nonReentrant
        onlyWhitelisted
    {
        priceResolver = IPriceResolver(_priceResolverAddress);
    }

    // update dev address
    function setDevAddress(address _devAddress)
        public
        nonReentrant
        onlyWhitelisted
    {
        devAddress = _devAddress;
    }

    // update NFT uri
    function setNftUri(string memory _uri) public nonReentrant onlyWhitelisted {
        syntheticNFT.setUri(_uri);
    }

    // update max. amount of NFT that can be minted/redeemed per time
    function setMaxNft(uint256 _value) public nonReentrant onlyWhitelisted {
        maxNft = _value;
    }

    // update mint fees
    function setMintFee(uint256 _fee) public nonReentrant onlyWhitelisted {
        mintFee = _fee;
    }

    // update redeem fees
    function setRedeemFee(uint256 _fee) public nonReentrant onlyWhitelisted {
        redeemFee = _fee;
    }

    // update discount fees
    function setDiscountFee(uint256 _fee) public nonReentrant onlyWhitelisted {
        discountFee = _fee;
    }

    // update offset fees
    function setOffsetFee(uint256 _fee) public nonReentrant onlyWhitelisted {
        offsetFee = _fee;
    }

    // INTERNAL FUNCTIONS

    modifier validateId(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _tokenAmount
    ) {
        require(syntheticVariantCount > _variantId, "Invalid given _id");
        require(
            syntheticVariants[_variantId].disabled == false,
            "The given _variantId is disabled"
        );
        require(collateralCount > _collateralId, "Invalid given _collateralId");
        require(
            collaterals[_collateralId].disabled == false,
            "The given _collateralId is disabled"
        );
        require(_tokenAmount != 0, "_tokenAmount can't be zero");
        require(maxNft >= _tokenAmount, "Exceed MAX_NFT");
        _;
    }

    function _toBytes(uint256 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }

    function _createPosition(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _collateralAmount,
        uint256 _tokenAmount
    ) internal {
        syntheticVariants[_variantId].totalOutstanding = syntheticVariants[
            _variantId
        ].totalOutstanding.add(
                syntheticVariants[_variantId].tokenValue.mul(_tokenAmount)
            );
        syntheticVariants[_variantId].totalIssued = syntheticVariants[
            _variantId
        ].totalIssued.add(_tokenAmount);
        syntheticVariants[_variantId].totalRawCollateral[
            _collateralId
        ] = syntheticVariants[_variantId].totalRawCollateral[_collateralId].add(
            _collateralAmount
        );

        emit PositionCreated(
            msg.sender,
            _variantId,
            _collateralId,
            syntheticVariants[_variantId].tokenValue,
            _collateralAmount,
            _tokenAmount
        );

        totalRawCollateral[_collateralId] = totalRawCollateral[_collateralId]
            .add(_collateralAmount);
        totalOutstanding = totalOutstanding.add(
            syntheticVariants[_variantId].tokenValue.mul(_tokenAmount)
        );
    }

    function _removePosition(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _collateralAmount,
        uint256 _tokenAmount
    ) internal {
        syntheticVariants[_variantId].totalOutstanding = syntheticVariants[
            _variantId
        ].totalOutstanding.sub(
                syntheticVariants[_variantId].tokenValue.mul(_tokenAmount)
            );
        syntheticVariants[_variantId].totalBurnt = syntheticVariants[_variantId]
            .totalBurnt
            .add(_tokenAmount);

        syntheticVariants[_variantId].totalRawCollateral[
            _collateralId
        ] = syntheticVariants[_variantId].totalRawCollateral[_collateralId].sub(
            _collateralAmount
        );

        emit PositionRemoved(
            msg.sender,
            _variantId,
            _collateralId,
            syntheticVariants[_variantId].tokenValue,
            _collateralAmount,
            _tokenAmount
        );

        totalRawCollateral[_collateralId] = totalRawCollateral[_collateralId]
            .sub(_collateralAmount);
        totalOutstanding = totalOutstanding.sub(
            syntheticVariants[_variantId].tokenValue.mul(_tokenAmount)
        );
    }

    function _getSyntheticPrice() internal view returns (uint256) {
        require(
            priceResolver.isValid(targetCurrency),
            "targetCurrency is not valid"
        );
        return priceResolver.getCurrentPrice(targetCurrency);
    }

    function _getCollateralPrice(uint8 _collateralId)
        internal
        view
        returns (uint256)
    {
        require(collateralCount > _collateralId, "Invalid given _collateralId");
        require(
            collaterals[_collateralId].disabled == false,
            "The given _collateralId is disabled"
        );
        require(
            priceResolver.isValid(collaterals[_collateralId].priceFeeder),
            "collateralShareSymbol is not valid"
        );
        return
            priceResolver.getCurrentPrice(
                collaterals[_collateralId].priceFeeder
            );
    }

    // find the CR for the variant
    function _variantCollatelizationRatio(uint8 _id)
        internal
        view
        returns (uint256)
    {
        require(syntheticVariantCount > _id, "Invalid given _id");

        uint256 totalCollateral = 0;

        for (uint8 i = 0; i < collateralCount; i++) {
            uint256 collateralRate = _getCollateralPrice(i);
            uint256 totalCollateralSynthetic = syntheticVariants[_id].totalRawCollateral[i];

            if (collaterals[i].decimals != 18) {
                uint256 offset = uint256(18-collaterals[i].decimals);
                totalCollateralSynthetic = totalCollateralSynthetic.mul(10**offset);
            }

            totalCollateral = totalCollateral.add(
                collateralRate.wmul(
                    totalCollateralSynthetic
                )
            );
        }

        if (totalCollateral == 0) {
            // return 100% when no collaterals
            return UNSIGNED_ONE_ETHER;
        } else {
            uint256 syntheticRate = _getSyntheticPrice();
            uint256 totalOutstanding = syntheticRate.wmul(
                syntheticVariants[_id].totalOutstanding
            );
            return totalCollateral.wdiv(totalOutstanding);
        }
    }

    // calculates the global CR
    function _globalCollatelizationRatio() public view returns (uint256) {
        // return 100% if there is no collateral
        if (totalOutstanding == 0) {
            return UNSIGNED_ONE_ETHER;
        }

        uint256 numerator = 0;

        for (uint8 y = 0; y < collateralCount; y++) {
            uint256 collateralRate = _getCollateralPrice(y);
            uint256 totalCollateral = totalRawCollateral[y];
            if (collaterals[y].decimals != 18) {
                uint256 offset = uint256(18-collaterals[y].decimals);
                totalCollateral = totalCollateral.mul(10**offset);
            }
            numerator = numerator.add(
                collateralRate.wmul(totalCollateral)
            );
        }

        uint256 syntheticRate = _getSyntheticPrice();
        uint256 denominator = syntheticRate.wmul(totalOutstanding);

        return numerator.wdiv(denominator);
    }


    function _estimateInput(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _tokenAmount
    ) internal view returns (uint256 amount) {
        uint256 syntheticPrice = _getSyntheticPrice();
        uint256 collateralPrice = _getCollateralPrice(_collateralId);
        uint256 mintedValue = syntheticPrice.wmul(
            syntheticVariants[_variantId].tokenValue.mul(_tokenAmount)
        );
        amount = mintedValue.wdiv(collateralPrice);
        
        if (collaterals[_collateralId].decimals != 18) {
            uint256 offset = uint256(18 - collaterals[_collateralId].decimals);
            amount = amount.div(10**offset);
        }
    }

    function _estimateRedeem(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _tokenAmount
    ) internal view returns (uint256 amount) {
        amount = _estimateInput(_variantId, _collateralId, _tokenAmount);

        (int256 targetCR, ) = _targetCollatelizationRatio();

        // apply the offset if CR < 1
        if (targetCR != ONE_ETHER) {
            uint256 offset = amount.mul(offsetFee).div(10000);
            amount = amount.sub(offset);
        }

        uint256 fee = amount.mul(redeemFee).div(10000);
        amount = amount.sub( fee );
    }

    function _estimateMint(
        uint8 _variantId,
        uint8 _collateralId,
        uint256 _tokenAmount
    ) internal view returns (uint256 amount) {
        amount = _estimateInput(_variantId, _collateralId, _tokenAmount);

        (, int256 normalizedCR) = _targetCollatelizationRatio();

        // apply the discount if targetCR > 1
        if (normalizedCR != ONE_ETHER) {
            uint256 discount = amount.mul(discountFee).div(10000);
            amount = amount.sub(discount);
        }
        uint256 fee = amount.mul(mintFee).div(10000);
        amount = amount.add( fee );
    }

    function _targetCollatelizationRatio()
        internal
        view
        returns (int256 crOffset, int256 crDiscount)
    {
        int256 currentCr = _globalCollatelizationRatio().toInt256();
        int256 normalizedCr = _calculateTargetCR(currentCr);

        // when cr is between 0 -> 1, the offset is deducted
        if (currentCr > 0 && ONE_ETHER >= normalizedCr) {
            crOffset = normalizedCr;
        } else {
            crOffset = ONE_ETHER;
        }

        // when cr is between 1 -> infinity, the discount is applied
        if (currentCr > ONE_ETHER && currentCr > normalizedCr) {
            crDiscount = normalizedCr;
        } else {
            crDiscount = ONE_ETHER;
        }
    }

    // log^b(kx+1)
    function _calculateTargetCR(int256 _cr) internal pure returns (int256) {
        return BASE.logBase((K.wmul(_cr)).add(ONE_ETHER));
    }
}
