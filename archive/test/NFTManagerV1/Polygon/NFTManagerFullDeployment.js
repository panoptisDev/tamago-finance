// const { expect } = require("chai");
// const { ethers, network } = require("hardhat")
// const { fromEther, toEther, deployPriceResolverMock, deployPriceResolver, deployPriceResolver2 } = require("../Helpers")

// let priceResolver
// let nftManager
// let wmaticToken
// let usdcToken
// let shareToken
// let router
// let factory
// let syntheticNft

// let admin
// let alice
// let bob
// let charlie
// let dev


// describe("Full Deployment Ang Pow USD - Polygon", () => {

//     const WMATIC_ADDRESS = "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270"
//     const USDC_ADDRESS = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"
//     const WMATIC_USDC_LP_ADDRESS = "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827"
//     const ROUTER_ADDRESS = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff"
//     const FACTORY_ADDRESS = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32"
//     const DEADLINE = 2554013609

//     let router

//     beforeEach(async () => {

//         try {

//             [admin, alice, bob, charlie, dev] = await ethers.getSigners();

//             const MockERC20 = await ethers.getContractFactory("MockERC20");

//             // Setup LP on Quickswap
//             wmaticToken = await MockERC20.deploy("Mock Wrapped Matic", "WMATIC")
//             usdcToken = await MockERC20.deploy('Mock USDC', "USDC")

//             factory = await ethers.getContractAt('IPancakeFactory', FACTORY_ADDRESS)
//             router = await ethers.getContractAt('IPancakeRouter02', ROUTER_ADDRESS)

//             const tx = await factory.createPair(wmaticToken.address, usdcToken.address)
//             await tx.wait()

//             const pairAddress = await factory.getPair(wmaticToken.address, usdcToken.address)
//             shareToken = await ethers.getContractAt("IPancakePair", pairAddress)

//             // First Mint
//             await wmaticToken.transfer(shareToken.address, toEther(10000))
//             await usdcToken.transfer(shareToken.address, toEther(20000))
//             await shareToken.mint(admin.address)

//             const PriceResolver = await ethers.getContractFactory("PriceResolver");
//             const NFTManager = await ethers.getContractFactory("NFTManager");

//             const MockPriceFeeder = await ethers.getContractFactory("MockPriceFeeder");
//             const ChainlinkPriceFeeder = await ethers.getContractFactory("ChainlinkPriceFeeder");
//             const QuickswapTokenFeeder = await ethers.getContractFactory("QuickswapTokenFeeder");
//             const QuickswapLPFeeder = await ethers.getContractFactory("QuickswapLPFeeder");

//             priceResolver = await deployPriceResolver2({
//                 PriceResolver,
//                 MockPriceFeeder,
//                 ChainlinkPriceFeeder,
//                 QuickswapTokenFeeder,
//                 QuickswapLPFeeder,
//                 Admin: admin,
//                 LpWmaticUsdcAddress: shareToken.address
//             })

//             nftManager = await NFTManager.deploy(
//                 "Lucky Red Envelope on Polygon",
//                 "https://api.tamago.finance/lucky-red-envelope/polygon/{id}",
//                 priceResolver.address,
//                 shareToken.address,
//                 ethers.utils.formatBytes32String("WMATIC-USDC-SHARE"),
//                 ethers.utils.formatBytes32String("USD"),
//                 dev.address
//             )

//             // setup NFT variants
//             await nftManager.addSyntheticVariant("Ang Bao 100 USD", 1, toEther(100))
//             await nftManager.addSyntheticVariant("Ang Bao 10 USD", 2, toEther(10))
//             await nftManager.addSyntheticVariant("Ang Bao 1 USD", 3, toEther(1))

//             const syntheticNftAddress = await nftManager.syntheticNFT()
//             syntheticNft = await ethers.getContractAt('SyntheticNFT', syntheticNftAddress)

//         } catch (e) {
//             // console.log(e)
//         }


//     });

//     it('Mint 100x NFTs on all variant when LP is ~$30k', async () => {

//         try {

//             const totalSupply = await shareToken.totalSupply()
//             const lpPrice = await nftManager.getCollateralSharePrice()

//             // $40k
//             expect(Number(fromEther(lpPrice)) * Number(fromEther(totalSupply)) >= 30000).to.true

//             await wmaticToken.connect(admin).transfer(alice.address, toEther(10000))
//             await usdcToken.connect(admin).transfer(alice.address, toEther(10000))

//             expect(await wmaticToken.balanceOf(alice.address)).to.equal(toEther(10000))
//             expect(await usdcToken.balanceOf(alice.address)).to.equal(toEther(10000))

//             await wmaticToken.connect(alice).approve(nftManager.address, ethers.constants.MaxUint256)
//             await usdcToken.connect(alice).approve(nftManager.address, ethers.constants.MaxUint256)

//             // Mint x100 $1 NFT
//             let inputs = await nftManager.estimateMint(0, 100)
//             await nftManager.connect(alice).mint(0, 100, inputs[0], inputs[1])
//             expect((await syntheticNft.balanceOf(alice.address, 1))).to.equal(100)

//             // Mint x100 $10 NFT
//             inputs = await nftManager.estimateMint(1, 100)
//             await nftManager.connect(alice).mint(1, 100, inputs[0], inputs[1])
//             expect((await syntheticNft.balanceOf(alice.address, 2))).to.equal(100)

//             // Mint x100 $100 NFT
//             inputs = await nftManager.estimateMint(2, 100)
//             await nftManager.connect(alice).mint(2, 100, inputs[0], inputs[1])
//             expect((await syntheticNft.balanceOf(alice.address, 3))).to.equal(100)

//             // Redeem ALL
//             await syntheticNft.connect(alice).setApprovalForAll(nftManager.address, true)

//             await nftManager.connect(alice).redeem(0, 100, 0, 0)
//             await nftManager.connect(alice).redeem(1, 100, 0, 0)
//             // await nftManager.connect(alice).redeem(2, 100, 0, 0)

//         } catch (e) {
//             // console.log(e)
//         }

//     })

//     it('Mint 1000x NFTs when LP > $1 mil.', async () => {

//         try {
//             // pumping liquidity
//             await wmaticToken.connect(admin).approve(router.address, ethers.constants.MaxUint256)
//             await usdcToken.connect(admin).approve(router.address, ethers.constants.MaxUint256)

//             await router.addLiquidity(
//                 wmaticToken.address,
//                 usdcToken.address,
//                 toEther(1000000),
//                 toEther(2000000),
//                 0,
//                 0,
//                 admin.address,
//                 999999999999999
//             )

//             let totalSupply = await shareToken.totalSupply()
//             let lpPrice = await nftManager.getCollateralSharePrice()

//             const beforeLpSize = Number(fromEther(lpPrice)) * Number(fromEther(totalSupply))

//             expect(beforeLpSize > 1000000).to.true

//             // mass minting
//             for (let round of [1, 2, 3, 4, 5]) {
//                 for (let user of [alice, bob, charlie]) {

//                     await wmaticToken.connect(admin).transfer(user.address, toEther(10000))
//                     await usdcToken.connect(admin).transfer(user.address, toEther(10000))

//                     await wmaticToken.connect(user).approve(nftManager.address, ethers.constants.MaxUint256)
//                     await usdcToken.connect(user).approve(nftManager.address, ethers.constants.MaxUint256)
//                     // Mint 100x $1 NFT
//                     let inputs = await nftManager.estimateMint(0, 100)
//                     await nftManager.connect(user).mint(0, 100, inputs[0], inputs[1])

//                     expect((await syntheticNft.balanceOf(user.address, 1))).to.equal(100 * round)

//                     // Mint 100x $10 NFT
//                     inputs = await nftManager.estimateMint(1, 100)
//                     await nftManager.connect(user).mint(1, 100, inputs[0], inputs[1])
//                     expect((await syntheticNft.balanceOf(user.address, 2))).to.equal(100 * round)

//                     // Mint 100x $100 NFT
//                     inputs = await nftManager.estimateMint(2, 100)
//                     await nftManager.connect(user).mint(2, 100, inputs[0], inputs[1])
//                     expect((await syntheticNft.balanceOf(user.address, 3))).to.equal(100 * round)

//                 }
//             }

//             totalSupply = await shareToken.totalSupply()
//             lpPrice = await nftManager.getCollateralSharePrice()

//             const afterLpSize = Number(fromEther(lpPrice)) * Number(fromEther(totalSupply))
//             // the LP size should be increased
//             expect( afterLpSize - beforeLpSize > 100000 ).to.true

//             expect( Number((await nftManager.syntheticVariants(0))[6]) ).to.equal(1500)
//             expect( Number((await nftManager.syntheticVariants(1))[6]) ).to.equal(1500)
//             expect( Number((await nftManager.syntheticVariants(2))[6]) ).to.equal(1500)

//             // reduce the ratio before redeeming
//             await nftManager.forceMint(0, 0, 100)
//             await nftManager.forceMint(1, 0, 100)
//             await nftManager.forceMint(2, 0, 100)

//             // total NFT issued
//             expect( 1 >  Number(fromEther( await nftManager.variantCollatelizationRatio(0)))).to.true
//             expect( 1 > Number(fromEther( await nftManager.variantCollatelizationRatio(1)))).to.true
//             expect( 1 > Number(fromEther( await nftManager.variantCollatelizationRatio(2)))).to.true

//             // TODO : Verify collaterals

//             // redeem 1/3 NFT from each account
//             for (let round of [1, 2 ]) {
//                 for (let user of [alice, bob, charlie]) {
//                     await syntheticNft.connect(user).setApprovalForAll(nftManager.address, true)
//                     // Redeem 100x $1 NFT
//                     await nftManager.connect(user).redeem(0, 100, 0, 0)

//                     // Redeem 100x $10 NFT
//                     await nftManager.connect(user).redeem(1, 100, 0, 0)

//                     // Redeem 100x $100 NFT
//                     await nftManager.connect(user).redeem(2, 100, 0, 0)
                    
//                 }
//             }

//             // total NFT burnt
//             expect( Number((await nftManager.syntheticVariants(0))[7]) ).to.equal(600)
//             expect( Number((await nftManager.syntheticVariants(1))[7]) ).to.equal(600)
//             expect( Number((await nftManager.syntheticVariants(2))[7]) ).to.equal(600)

//         } catch (e) {
//             // console.log(e)
//         }

//     })

// })