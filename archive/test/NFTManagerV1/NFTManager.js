// const { expect } = require("chai");
// const { ethers } = require("hardhat")
// const { fromEther, toEther, deployPriceResolverMock, deployPriceResolver } = require("./Helpers")

// let priceResolver
// let nftManager
// let wmaticToken
// let usdcToken
// let shareToken
// let syntheticNft

// let admin
// let alice
// let bob
// let charlie
// let dev

// describe("NFTManager contract with mocks", () => {

//     before(async () => {

//         [admin, alice, bob, charlie, dev] = await ethers.getSigners();

//         const PriceResolver = await ethers.getContractFactory("PriceResolver");
//         const NFTManager = await ethers.getContractFactory("NFTManager");
//         const MockLP = await ethers.getContractFactory("MockLP");
//         const MockPriceFeeder = await ethers.getContractFactory("MockPriceFeeder");

//         priceResolver = await deployPriceResolverMock({ PriceResolver, MockPriceFeeder, admin })

//         shareToken = await MockLP.deploy("Share Token", "SHARE")

//         nftManager = await NFTManager.deploy("Ang Bao USD",
//             "ERC-1155_URI",
//             priceResolver.address,
//             shareToken.address,
//             ethers.utils.formatBytes32String("WMATIC-USDC-SHARE"),
//             ethers.utils.formatBytes32String("USD"),
//             dev.address)

//         // setup NFT variants
//         await nftManager.addSyntheticVariant("Ang Bao 1 USD", 1, toEther(1))
//         await nftManager.addSyntheticVariant("Ang Bao 10 USD", 2, toEther(10))
//         await nftManager.addSyntheticVariant("Ang Bao 100 USD", 3, toEther(100))

//     });

//     it('verify initial params', async () => {

//         // intial params
//         expect(await nftManager.name()).to.equal("Ang Bao USD")
//         expect(await nftManager.priceResolver()).to.equal(priceResolver.address)
//         expect(await nftManager.collateralShare()).to.equal(shareToken.address)
//         expect(await nftManager.devAddress()).to.equal(dev.address)

//         // check prices
//         expect(await nftManager.getSyntheticPrice()).to.equal(toEther(1))
//         expect(await nftManager.getCollateralSharePrice()).to.equal(toEther(2000000))

//         // update base URI of ERC-1155
//         const syntheticNftAddress = await nftManager.syntheticNFT()
//         syntheticNft = await ethers.getContractAt('SyntheticNFT', syntheticNftAddress)

//         await nftManager.setNftUri("https://api.cryptokitties.co/kitties/{id}")
//         expect(await syntheticNft.uri(0)).to.equal("https://api.cryptokitties.co/kitties/{id}")

//         // check variants
//         const firstVariant = await nftManager.syntheticVariants(0);
//         expect(firstVariant[0]).to.equal("Ang Bao 1 USD")
//         expect(firstVariant[1]).to.equal(1)
//         expect(firstVariant[2]).to.equal(toEther(1))

//         const secondVariant = await nftManager.syntheticVariants(1);
//         expect(secondVariant[0]).to.equal("Ang Bao 10 USD")
//         expect(secondVariant[1]).to.equal(2)
//         expect(secondVariant[2]).to.equal(toEther(10))

//         const thirdVariant = await nftManager.syntheticVariants(2);
//         expect(thirdVariant[0]).to.equal("Ang Bao 100 USD")
//         expect(thirdVariant[1]).to.equal(3)
//         expect(thirdVariant[2]).to.equal(toEther(100))

//     })

//     it('force mint/redeem x3 Ang Bao 10 USD', async () => {

//         // check required LP share need to mint
//         const syntheticPrice = fromEther(await nftManager.getSyntheticPrice())
//         const sharePrice = fromEther(await nftManager.getCollateralSharePrice())

//         const nftValue = fromEther((await nftManager.syntheticVariants(1))[2])

//         const lpPerNft = Number(nftValue) * Number(syntheticPrice) / Number(sharePrice)

//         await shareToken.approve(nftManager.address, ethers.constants.MaxUint256)

//         for (let i = 0; i < 3; i++) {
//             await nftManager.forceMint(1, toEther(lpPerNft.toFixed(18)), 1)
//         }

//         expect((await syntheticNft.balanceOf(admin.address, 2))).to.equal(3)

//         let variantInfo = await nftManager.syntheticVariants(1)

//         expect(variantInfo.totalOutstanding).to.equal(toEther(30))
//         expect((variantInfo.totalIssued)).to.equal(3)
//         expect(fromEther(variantInfo.totalRawCollateral)).to.equal("0.000015")
//         expect(fromEther(await nftManager.totalRawCollateral())).to.equal("0.000015")
//         expect((await nftManager.totalOutstanding())).to.equal(toEther(30))

//         // check the collatelization ratio
//         expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("1.0")
//         expect(fromEther(await nftManager.variantCollatelizationRatio(1))).to.equal("1.0")

//         // redeem all NFTs back

//         await syntheticNft.setApprovalForAll(nftManager.address, true)

//         for (let i = 0; i < 3; i++) {
//             await nftManager.forceRedeem(1, toEther(lpPerNft.toFixed(18)), 1)
//         }

//         variantInfo = await nftManager.syntheticVariants(1)

//         expect(variantInfo.totalOutstanding).to.equal(0)
//         expect((variantInfo.totalBurnt)).to.equal(3)

//         expect((variantInfo.totalRawCollateral)).to.equal(0)
//         expect(await nftManager.totalRawCollateral()).to.equal(0)
//         expect(await nftManager.totalOutstanding()).to.equal(0)
//     })


//     it('verify CR offset/discount', async () => {

//         const syntheticPrice = fromEther(await nftManager.getSyntheticPrice())
//         const sharePrice = fromEther(await nftManager.getCollateralSharePrice())
//         const nftValue = fromEther((await nftManager.syntheticVariants(1))[2])
//         const lpPerNft = Number(nftValue) * Number(syntheticPrice) / Number(sharePrice)

//         // mint 1 NFT with 50% value backed
//         await nftManager.forceMint(1, toEther((lpPerNft * 0.5).toFixed(18)), 1)

//         expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("0.5") // 50%

//         // check target CR
//         expect(fromEther((await nftManager.targetCollatelizationRatio(1))[0])).to.equal("0.752048447819438528") // offset
//         expect(fromEther((await nftManager.targetCollatelizationRatio(1))[1])).to.equal("1.0") // discount


//         // mint another 1 NFT to shift the CR > 1
//         await nftManager.forceMint(1, toEther((lpPerNft * 3).toFixed(18)), 1)

//         // then check the params
//         expect(fromEther(await nftManager.globalCollatelizationRatio())).to.equal("1.75") // 175%
//         expect(fromEther((await nftManager.targetCollatelizationRatio(1))[0])).to.equal("1.0") // offset
//         expect(fromEther((await nftManager.targetCollatelizationRatio(1))[1])).to.equal("1.237418056046236017") // discount

//     })

//     it('able to pause the contract', async () => {

//         const syntheticPrice = fromEther(await nftManager.getSyntheticPrice())
//         const sharePrice = fromEther(await nftManager.getCollateralSharePrice())
//         const nftValue = fromEther((await nftManager.syntheticVariants(1))[2])
//         const lpPerNft = Number(nftValue) * Number(syntheticPrice) / Number(sharePrice)

//         await shareToken.approve(nftManager.address, ethers.constants.MaxUint256)
//         await nftManager.forceMint(1, toEther(lpPerNft.toFixed(18)), 1)

//         // pause the contract
//         await nftManager.setPaused()

//         try {
//             // should be failed when the contract is paused
//             await nftManager.forceMint(1, toEther(lpPerNft.toFixed(18)), 1)
//         } catch (e) {
//             expect(e.message.indexOf("Pausable: paused") !== -1).to.true
//         }

//         // pause the contract
//         await nftManager.setUnpaused()
//         // back to work
//         await nftManager.forceMint(1, toEther(lpPerNft.toFixed(18)), 1)

//     })

// })

// describe("NFTManager contract on forked Polygon chain", () => {

//     const WMATIC_ADDRESS = "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270"
//     const USDC_ADDRESS = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"
//     const WMATIC_USDC_LP_ADDRESS = "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827"
//     const ROUTER_ADDRESS = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff"
//     const DEADLINE = 2554013609

//     let router

//     before(async () => {

//         try {

//             [admin, alice, bob, charlie, dev] = await ethers.getSigners();

//             const PriceResolver = await ethers.getContractFactory("PriceResolver");
//             const NFTManager = await ethers.getContractFactory("NFTManager");

//             const MockPriceFeeder = await ethers.getContractFactory("MockPriceFeeder");
//             const ChainlinkPriceFeeder = await ethers.getContractFactory("ChainlinkPriceFeeder");
//             const QuickswapTokenFeeder = await ethers.getContractFactory("QuickswapTokenFeeder");
//             const QuickswapLPFeeder = await ethers.getContractFactory("QuickswapLPFeeder");

//             wmaticToken = await ethers.getContractAt('MockERC20', WMATIC_ADDRESS)
//             usdcToken = await ethers.getContractAt('MockERC20', USDC_ADDRESS)
//             shareToken = await ethers.getContractAt("IPancakePair", WMATIC_USDC_LP_ADDRESS)

//             priceResolver = await deployPriceResolver({
//                 PriceResolver,
//                 MockPriceFeeder,
//                 ChainlinkPriceFeeder,
//                 QuickswapTokenFeeder,
//                 QuickswapLPFeeder,
//                 // TamgToken: tamgToken,
//                 Admin: admin
//             })

//             nftManager = await NFTManager.deploy(
//                 "Ang Bao USD",
//                 "https://api.cryptokitties.co/kitties/{id}",
//                 priceResolver.address,
//                 shareToken.address,
//                 ethers.utils.formatBytes32String("WMATIC-USDC-SHARE"),
//                 ethers.utils.formatBytes32String("USD"),
//                 dev.address
//             )

//             // setup NFT variants
//             await nftManager.addSyntheticVariant("Ang Bao 1 USD", 1, toEther(1))
//             await nftManager.addSyntheticVariant("Ang Bao 10 USD", 2, toEther(10))
//             await nftManager.addSyntheticVariant("Ang Bao 100 USD", 3, toEther(100))

//             // Set Redeem Fee to 0%
//             await nftManager.setRedeemFee(0)

//             const syntheticNftAddress = await nftManager.syntheticNFT()
//             syntheticNft = await ethers.getContractAt('SyntheticNFT', syntheticNftAddress)

//             // trade TAMG
//             router = await ethers.getContractAt('IPancakeRouter02', ROUTER_ADDRESS)
//         } catch (e) {
//             // console.log(e)
//         }


//     });

//     it('Mint/Redeem x3 NFT from 1 Variant', async () => {

//         try {
//             // buy USDC /w 1000 Matic
//             const minOutput = await router.getAmountsOut(toEther(1000), [await router.WETH(), USDC_ADDRESS])
//             await router.swapExactETHForTokens(minOutput[1], [await router.WETH(), USDC_ADDRESS], admin.address, DEADLINE, { value: toEther(1000) })

//             const usdcBalance = await usdcToken.balanceOf(admin.address)
//             expect(Number(ethers.utils.formatUnits(usdcBalance, 6)) > 1000).to.true

//             // wrap WMATIC /w 1000 Matic
//             await wmaticToken.deposit(toEther(1000), { value: toEther(1000) })

//             const wmaticBalance = await wmaticToken.balanceOf(admin.address)
//             expect(Number(ethers.utils.formatUnits(wmaticBalance, 18)) === 1000).to.true

//             await wmaticToken.approve(nftManager.address, ethers.constants.MaxUint256)
//             await usdcToken.approve(nftManager.address, ethers.constants.MaxUint256)

//             const inputs = await nftManager.estimateMint(2, 3)

//             // mint x3 $100 NFT
//             await nftManager.mint(2, 3, inputs[0], inputs[1])

//             // verify
//             expect((await syntheticNft.balanceOf(admin.address, 3))).to.equal(3)

//             let variantInfo = await nftManager.syntheticVariants(2)

//             expect(variantInfo.totalOutstanding).to.equal(toEther(300))
//             expect((variantInfo.totalIssued)).to.equal(3)
//             expect(variantInfo.totalRawCollateral).to.not.equal(0)
//             expect(await nftManager.totalRawCollateral()).to.not.equal(0)

//             expect(Number(fromEther(await nftManager.globalCollatelizationRatio())) > 0.9).to.true
//             expect(Number(fromEther(await nftManager.variantCollatelizationRatio(1))) > 0.9).to.true

//             // mint x2 NFT without collaterals to bring down the CR
//             await nftManager.forceMint(2, 0, 1)

//             const output = await nftManager.estimateRedeem(2, 1)

//             // redeem fee should not be zero
//             expect(output[3]).to.not.equal(0)

//             await syntheticNft.setApprovalForAll(nftManager.address, true)

//             await nftManager.redeem(2, 1, 0, 0)

//             expect((await syntheticNft.balanceOf(admin.address, 3))).to.equal(3)

//         } catch (e) {
//             // console.log(e)
//         }

//     })

//     it('Mint x1 NFT when the CR > 1', async () => {

//         try {

//             // trade LP tokens
//             await wmaticToken.approve(router.address, ethers.constants.MaxUint256)
//             await usdcToken.approve(router.address, ethers.constants.MaxUint256)
//             await shareToken.approve(nftManager.address, ethers.constants.MaxUint256)

//             // estimate USDC, TAMG tokens needed to mint 5 NFTs
//             const inputs = await nftManager.estimateMint(1, 5)
//             const baseAmount = Number(ethers.utils.formatUnits(inputs[0], 18))
//             const pairAmount = Number(ethers.utils.formatUnits(inputs[1], 6))

//             await router.addLiquidity(wmaticToken.address, usdcToken.address, ethers.utils.parseUnits(`${baseAmount}`, 18), ethers.utils.parseUnits(`${pairAmount}`, 6), ethers.utils.parseUnits(`${(baseAmount * 0.97).toFixed(18)}`, 18), ethers.utils.parseUnits(`${(pairAmount * 0.97).toFixed(6)}`, 6), admin.address, 9999999999999)

//             // mint x1 NFT with 5x collaterals to bring up the CR
//             await nftManager.forceMint(1, await shareToken.balanceOf(admin.address), 1)

//             const beforeMintRatio = await nftManager.variantCollatelizationRatio(1)

//             expect(Number(fromEther(beforeMintRatio)) > 1.1).to.true

//             // mint x2 Ang Bao NFTs
//             await nftManager.mint(1, 2, inputs[0], inputs[1])

//             const afterMintRatio = await nftManager.variantCollatelizationRatio(1)

//             expect(Number(fromEther(beforeMintRatio)) > Number(fromEther(afterMintRatio))).to.true

//         } catch (e) {
//             // console.log(e)
//         }

//     })

//     it('Redeem x2 NFT when the redeem fee is set', async () => {

//         try {
//             // set the fee back to 3%
//             await nftManager.setRedeemFee(300) // 3%

//             const output = await nftManager.estimateRedeem(1, 2)

//             // redeem 2 NFTs
//             await nftManager.redeem(1, 2, output[0], output[1])

//             // dev should receives fees
//             expect(Number(ethers.utils.formatUnits((await usdcToken.balanceOf(dev.address)), 6)) !== 0)
//             expect(Number(ethers.utils.formatUnits((await wmaticToken.balanceOf(dev.address)), 18)) !== 0)

//         } catch (e) {
//             // console.log(e)
//         }

//     })

//     // TODO: More test cases


// })