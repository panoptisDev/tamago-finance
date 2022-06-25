const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat")
const { fromEther, toEther, fromUsdc, toUsdc, deployPriceResolverMock, deployPriceResolver, deployPriceResolverV2 } = require("../Helpers")

let priceResolver
let nftManager
let registry
let usdcToken
let usdtToken
let daiToken
let shareToken
let syntheticNft

let admin
let alice
let bob
let charlie
let dev

describe("NFTManager v.0.4.x", () => {

    beforeEach(async () => {

        [admin, alice, bob, charlie, dev] = await ethers.getSigners();

        const NFTManagerUpgradeable = await ethers.getContractFactory("NFTManagerUpgradeable")
        const Registry = await ethers.getContractFactory("Registry");
        const MockERC20 = await ethers.getContractFactory("MockERC20");

        registry = await Registry.deploy()
        priceResolver = await deployPriceResolverV2({
            library: ethers,
            admin: admin.address
        })
        // registry it to the registry
        await registry.registerContract(ethers.utils.formatBytes32String("PRICE_RESOLVER"), priceResolver.address)

        // deploy an synthetic NFT contract
        await registry.deploySyntheticNFT(ethers.utils.formatBytes32String("SYNTHETIC_NFT"), "TEST", "https://api.cryptokitties.co/kitties/{id}")

        nftManager = await upgrades.deployProxy(NFTManagerUpgradeable, [
            registry.address,
            ethers.utils.formatBytes32String("USD"),
            ethers.utils.formatBytes32String("PRICE_RESOLVER"),
            ethers.utils.formatBytes32String("SYNTHETIC_NFT"),
            dev.address
        ])
        await registry.registerContract(ethers.utils.formatBytes32String("USD_VOUCHER"), nftManager.address)

        // allow nftManager contract to mint/burn NFT
        await registry.permitToMint(ethers.utils.formatBytes32String("USD_VOUCHER"), ethers.utils.formatBytes32String("SYNTHETIC_NFT"))

        usdcToken = await MockERC20.deploy('Mock USDC', "USDC", 6)
        usdtToken = await MockERC20.deploy('Mock USDT', "USDT", 6)
        daiToken = await MockERC20.deploy('Mock DAI', "DAI", 18)

        for (let i = 0; i < 3; i++) {
            await usdcToken.faucet()
            await daiToken.faucet()
            await usdtToken.faucet()
        }

        // setup collateral assets
        await nftManager.addCollateralAsset(
            "USDC",
            ethers.utils.formatBytes32String("USDC/USD"),
            usdcToken.address,
            6
        )

        await nftManager.addCollateralAsset(
            "USDT",
            ethers.utils.formatBytes32String("USDT/USD"),
            usdtToken.address,
            6
        )

        await nftManager.addCollateralAsset(
            "DAI",
            ethers.utils.formatBytes32String("DAI/USD"),
            daiToken.address,
            18
        )

        // setup variants
        await nftManager.addSyntheticVariant("Voucher 1 USD", 1, toEther(1))
        await nftManager.addSyntheticVariant("Voucher 10 USD", 2, toEther(10))
        await nftManager.addSyntheticVariant("Voucher 100 USD", 3, toEther(100))

        const syntheticNftAddress = await nftManager.syntheticNFT()
        syntheticNft = await ethers.getContractAt("MockERC1155", syntheticNftAddress)
    })

    it('verify initial params', async () => {

        expect(await nftManager.devAddress()).to.equal(dev.address)
        expect(await nftManager.priceResolver()).to.equal(priceResolver.address)

        // check prices
        expect(await nftManager.getSyntheticPrice()).to.equal(toEther(1))

        const syntheticNftAddress = await nftManager.syntheticNFT()
        expect(await registry.getContractAddress(ethers.utils.formatBytes32String("SYNTHETIC_NFT"))).to.equal(syntheticNftAddress)

        // check variants
        const firstVariant = await nftManager.syntheticVariants(0);
        expect(firstVariant[0]).to.equal("Voucher 1 USD")
        expect(firstVariant[1]).to.equal(1)
        expect(firstVariant[2]).to.equal(toEther(1))

        const secondVariant = await nftManager.syntheticVariants(1);
        expect(secondVariant[0]).to.equal("Voucher 10 USD")
        expect(secondVariant[1]).to.equal(2)
        expect(secondVariant[2]).to.equal(toEther(10))

        const thirdVariant = await nftManager.syntheticVariants(2);
        expect(thirdVariant[0]).to.equal("Voucher 100 USD")
        expect(thirdVariant[1]).to.equal(3)
        expect(thirdVariant[2]).to.equal(toEther(100))

    })

    it('able to update the token URI', async () => {
        await nftManager.setNftUri("https://api.cryptokitties.co/kitties/{id}")
        expect(await syntheticNft.uri(0)).to.equal("https://api.cryptokitties.co/kitties/{id}")
    })

    it('able to pause the manager contract', async () => {
        await nftManager.setPaused()

        try {
            // should be failed when the contract is paused
            await nftManager.forceMint(0, 0, 0, 1)
        } catch (e) {
            expect(e.message.indexOf("Pausable: paused") !== -1).to.true
        }

    })

    it('able to forcefully mint $100 NFT from a single type of collateral', async () => {

        const syntheticPrice = fromEther(await nftManager.getSyntheticPrice())
        const collateralPrice = fromEther(await nftManager.getCollateralPrice(0))

        const nftValue = fromEther((await nftManager.syntheticVariants(2))['tokenValue'])
        const usdcPerNft = Number(nftValue) * Number(syntheticPrice) / Number(collateralPrice)

        // this is fake USDC with 18 decimals
        await usdcToken.approve(nftManager.address, ethers.constants.MaxUint256)

        await nftManager.forceMint(2, 0, toUsdc(usdcPerNft.toFixed(6)), 1)

        expect((await syntheticNft.balanceOf(admin.address, 3))).to.equal(1)

        let variantInfo = await nftManager.syntheticVariants(2)

        expect(variantInfo.totalOutstanding).to.equal(toEther(100))
        expect((variantInfo.totalIssued)).to.equal(1)
        expect(fromUsdc(await nftManager.getVariantCollateral(2, 0))).to.equal(usdcPerNft.toFixed(6))
        expect(fromUsdc(await nftManager.totalRawCollateral(0))).to.equal(usdcPerNft.toFixed(6))
        expect((await nftManager.totalOutstanding())).to.equal(toEther(100))

        // check the collatelization ratio
        expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("0.999999999999")
        expect(fromEther(await nftManager.variantCollatelizationRatio(0))).to.equal("1.0")
        expect(fromEther(await nftManager.variantCollatelizationRatio(1))).to.equal("1.0")
        expect(fromEther(await nftManager.variantCollatelizationRatio(2))).to.equal("0.999999999999")

        await syntheticNft.setApprovalForAll(nftManager.address, true)

        // redeem it
        await nftManager.forceRedeem(2, 0, toUsdc(usdcPerNft.toFixed(6)), 1)

        variantInfo = await nftManager.syntheticVariants(2)

        expect(variantInfo.totalOutstanding).to.equal(0)
        expect((variantInfo.totalBurnt)).to.equal(1)

        expect((await nftManager.totalRawCollateral(0))).to.equal(0)
        expect((await nftManager.totalRawCollateral(0))).to.equal(0)
        expect(await nftManager.totalOutstanding()).to.equal(0)
    })

    it('verify returned CR is correct', async () => {

        const syntheticPrice = fromEther(await nftManager.getSyntheticPrice())
        const collateralPrice = fromEther(await nftManager.getCollateralPrice(0))

        const nftValue = fromEther((await nftManager.syntheticVariants(2))['tokenValue'])
        let usdcPerNft = Number(nftValue) * Number(syntheticPrice) / Number(collateralPrice)

        await usdcToken.approve(nftManager.address, ethers.constants.MaxUint256)

        // mint 1x$100 with 50% of value 
        const halfValue = usdcPerNft * 0.5
        await nftManager.forceMint(2, 0, toUsdc(halfValue.toFixed(6)), 1)

        expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("0.500000004999")

        // check normalized CR
        expect(fromEther((await nftManager.targetCollatelizationRatio())[0])).to.equal("0.752048451393005676") // offset
        expect(fromEther((await nftManager.targetCollatelizationRatio())[1])).to.equal("1.0")  // discount

        // mint 1x 1 NFT with 300% value to shifting the CR > 1
        const tripleValue = usdcPerNft * 3
        await nftManager.forceMint(2, 0, toUsdc(tripleValue.toFixed(6)), 1)

        expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("1.750000002498")

        // check normalized CR
        expect(fromEther((await nftManager.targetCollatelizationRatio())[0])).to.equal("1.0") // offset
        expect(fromEther((await nftManager.targetCollatelizationRatio())[1])).to.equal("1.237418056630274733")  // discount

    })

    it('able to mint $1, $10, $100 NFT from a single type of collateral worth of $10k', async () => {

        const variants = [0, 1, 2] // $1, $10, $100

        await usdcToken.approve(nftManager.address, ethers.constants.MaxUint256)

        for (let variant of variants) {
            const maxCollateralAmount = await nftManager.estimateMint(variant, 0, 100)
            await nftManager.mint(variant, 0, 100, maxCollateralAmount)

            expect((await syntheticNft.balanceOf(admin.address, variant + 1))).to.equal(100)

            const variantInfo = await nftManager.syntheticVariants(variant)

            expect(variantInfo.totalOutstanding).to.equal(toEther(100 * 10 ** variant))
            expect((variantInfo.totalIssued)).to.equal(100)
            expect((fromEther(await nftManager.variantCollatelizationRatio(variant)))).to.equal("0.9999")
        }

        expect(fromUsdc((await usdcToken.balanceOf(nftManager.address)))).to.equal("11100.0")
        expect((fromEther(await nftManager.globalCollatelizationRatio()))).to.equal("0.9999")

        // mint some NFT without collaterals to bring down the CR
        for (let variant of variants) {
            await nftManager.forceMint(variant, 0, 0, 4)
        }
        // CR is now 0.96
        expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("0.961442307692307692")

        await syntheticNft.setApprovalForAll(nftManager.address, true)

        // redeem x10 NFT from each variant
        for (let variant of variants) {
            const amountToRedeem = 10

            const minOutput = await nftManager.estimateRedeem(variant, 0, amountToRedeem)
            await nftManager.redeem(variant, 0, amountToRedeem, minOutput)

            const variantInfo = await nftManager.syntheticVariants(variant)

            expect((variantInfo.totalBurnt)).to.equal(amountToRedeem)
        }

        // TODO : validate balances

    })

    it('able to mint all NFTs from multi-collateral assets', async () => {

        const variants = [0, 1, 2] // $1, $10, $100

        await usdcToken.approve(nftManager.address, ethers.constants.MaxUint256)
        await usdtToken.approve(nftManager.address, ethers.constants.MaxUint256)
        await daiToken.approve(nftManager.address, ethers.constants.MaxUint256)

        for (let variant of variants) {
            // const token = variant === 0 ? usdcToken : variant === 1 ? usdcToken : daiToken
            const collateralId = variant

            const maxCollateralAmount = await nftManager.estimateMint(variant, collateralId, 100)
            await nftManager.mint(variant, collateralId, 100, maxCollateralAmount)

            expect((await syntheticNft.balanceOf(admin.address, variant + 1))).to.equal(100)

            const variantInfo = await nftManager.syntheticVariants(variant)

            expect(variantInfo.totalOutstanding).to.equal(toEther(100 * 10 ** variant))
            expect((variantInfo.totalIssued)).to.equal(100)
            expect((fromEther(await nftManager.variantCollatelizationRatio(variant)))).to.equal("0.9999")
        }

        expect(fromUsdc( await usdcToken.balanceOf(nftManager.address) )).to.equal("100.0")
        expect(fromUsdc( await usdtToken.balanceOf(nftManager.address) )).to.equal("999.9")
        expect(fromEther( await daiToken.balanceOf(nftManager.address) )).to.equal("10004.002001000500250125")

        expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("0.9999")

        // TODO : validate balances
    })

    it('able to mint with discount when the reserve is over-collatelized', async () => {

        await usdcToken.approve(nftManager.address, ethers.constants.MaxUint256)
        await nftManager.setDiscountFee(100) // set discount 1%

        const maxCollateralAmount = await nftManager.estimateMint(2, 0, 100)
        await nftManager.mint(2, 0, 10, maxCollateralAmount)

        expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("0.9999")
        expect(fromUsdc(await nftManager.estimateMint(2, 0, 1))).to.equal("101.010101")
        expect(fromUsdc(await nftManager.estimateRedeem(2, 0, 1))).to.equal("99.009901")

        // mint 1x $100 NFT with 1000 USDC
        await nftManager.forceMint(2, 0, toUsdc(1000), 1)

        expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("1.818")
        // having a discount
        expect(fromUsdc(await nftManager.estimateMint(2, 0, 1))).to.equal("100.0")
        expect(fromUsdc(await nftManager.estimateRedeem(2, 0, 1))).to.equal("99.009901")

    })

    it('able to mint and reem the NFT without any fee', async () => {

        await usdcToken.approve(nftManager.address, ethers.constants.MaxUint256)

        await nftManager.setMintFee(0)
        await nftManager.setOffsetFee(0)
        await nftManager.setRedeemFee(0)
        await nftManager.setDiscountFee(0)
        const maxCollateralAmount = await nftManager.estimateMint(2, 0, 1)
        await nftManager.mint(2, 0, 1, maxCollateralAmount)

        const minOutput = await nftManager.estimateRedeem(2, 0, 1)

        expect(maxCollateralAmount ).to.equal(minOutput)

        await syntheticNft.setApprovalForAll(nftManager.address, true)

        await nftManager.redeem(2,0,1, minOutput)

    })

})