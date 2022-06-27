// const { expect } = require("chai")
// const { ethers, network } = require("hardhat")
// const { fromEther, toEther, deployPriceResolverMainnet } = require("../Helpers")

// let priceResolver
// let nftManager
// let wEthToken
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

// describe("Full Deployment Ang Pow USD - Mainnet", () => {
//   const WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
//   const USDC_ADDRESS = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
//   const ROUTER_ADDRESS = "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F"
//   const FACTORY_ADDRESS = "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac"
//   const WETH_WHALE = "0xe78388b4ce79068e89bf8aa7f218ef6b9ab0e9d0"
//   const USDC_WHALE = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503"

//   const whales = [WETH_WHALE, USDC_WHALE]

//   let router

//   beforeEach(async () => {
//     try {
//       ;[admin, alice, bob, charlie, dev] = await ethers.getSigners()

//       // Setup LP on Quickswap
//       wEthToken = await ethers.getContractAt("MockERC20", WETH_ADDRESS)
//       usdcToken = await ethers.getContractAt("MockERC20", USDC_ADDRESS)

//       factory = await ethers.getContractAt("IPancakeFactory", FACTORY_ADDRESS)
//       router = await ethers.getContractAt("IPancakeRouter02", ROUTER_ADDRESS)

//       const pairAddress = await factory.getPair(
//         wEthToken.address,
//         usdcToken.address
//       )
//       shareToken = await ethers.getContractAt("IPancakePair", pairAddress)

//       whales.forEach(async (account) => {
//         await network.provider.request({
//           method: "hardhat_impersonateAccount",
//           params: [account],
//         })
//       })
//       const wEthWhale = ethers.provider.getSigner(WETH_WHALE)
//       const usdcWhale = ethers.provider.getSigner(USDC_WHALE)

//       // Transfer to token deployer

//       await admin.sendTransaction({ to: USDC_WHALE, value: toEther("10") })

//       await wEthToken
//         .connect(wEthWhale)
//         .transfer(await admin.getAddress(), await wEthToken.balanceOf(WETH_WHALE))
//       await usdcToken
//         .connect(usdcWhale)
//         .transfer(await admin.getAddress(), await usdcToken.balanceOf(USDC_WHALE))

//       const PriceResolver = await ethers.getContractFactory("PriceResolver")
//       const NFTManager = await ethers.getContractFactory("NFTManager")

//       const MockPriceFeeder = await ethers.getContractFactory("MockPriceFeeder")
//       const ChainlinkPriceFeeder = await ethers.getContractFactory(
//         "ChainlinkPriceFeeder"
//       )
//       const QuickswapTokenFeeder = await ethers.getContractFactory(
//         "QuickswapTokenFeeder"
//       )
//       const QuickswapLPFeeder = await ethers.getContractFactory(
//         "QuickswapLPFeeder"
//       )

//       priceResolver = await deployPriceResolverMainnet({
//         PriceResolver,
//         MockPriceFeeder,
//         ChainlinkPriceFeeder,
//         QuickswapTokenFeeder,
//         QuickswapLPFeeder,
//         Admin: admin,
//         lpWEthUsdcAddress: shareToken.address,
//       })

//       nftManager = await NFTManager.deploy(
//         "Ang Bao USD",
//         "https://api.tamago.finance/angpow/{id}",
//         priceResolver.address,
//         shareToken.address,
//         ethers.utils.formatBytes32String("WETH-USDC-SHARE"),
//         ethers.utils.formatBytes32String("USD"),
//         dev.address
//       )

//       // setup NFT variants
//       await nftManager.addSyntheticVariant("Ang Bao 1 USD", 1, toEther(1))
//       await nftManager.addSyntheticVariant("Ang Bao 10 USD", 2, toEther(10))
//       await nftManager.addSyntheticVariant("Ang Bao 100 USD", 3, toEther(100))

//       const syntheticNftAddress = await nftManager.syntheticNFT()
//       syntheticNft = await ethers.getContractAt(
//         "SyntheticNFT",
//         syntheticNftAddress
//       )
//     } catch (e) {
//       // console.log(e)
//     }
//   })

//   it("Mint 100x NFTs on all variant when LP is ~$30k", async () => {
//     try {
//       const totalSupply = await shareToken.totalSupply()
//       const lpPrice = await nftManager.getCollateralSharePrice()

//       // $40k
//       expect(
//         Number(fromEther(lpPrice)) * Number(fromEther(totalSupply)) >= 30000
//       ).to.true

//       await wEthToken
//         .connect(admin)
//         .transfer(
//           alice.address,
//           await wEthToken.balanceOf(await admin.getAddress())
//         )
//       await usdcToken
//         .connect(admin)
//         .transfer(
//           alice.address,
//           await usdcToken.balanceOf(await admin.getAddress())
//         )

//       await wEthToken
//         .connect(alice)
//         .approve(nftManager.address, ethers.constants.MaxUint256)
//       await usdcToken
//         .connect(alice)
//         .approve(nftManager.address, ethers.constants.MaxUint256)

//       // Mint x100 $1 NFT
//       let inputs = await nftManager.estimateMint(0, 10)
//       await nftManager.connect(alice).mint(0, 10, inputs[0], inputs[1])
//       expect(await syntheticNft.balanceOf(alice.address, 1)).to.equal(10)

//       // Mint x100 $10 NFT
//       inputs = await nftManager.estimateMint(1, 10)
//       await nftManager.connect(alice).mint(1, 10, inputs[0], inputs[1])
//       expect(await syntheticNft.balanceOf(alice.address, 2)).to.equal(10)

//       // Mint x100 $100 NFT
//       inputs = await nftManager.estimateMint(2, 10)
//       await nftManager.connect(alice).mint(2, 10, inputs[0], inputs[1])
//       expect(await syntheticNft.balanceOf(alice.address, 3)).to.equal(10)

//       // Redeem ALL
//       await syntheticNft
//         .connect(alice)
//         .setApprovalForAll(nftManager.address, true)

//       await nftManager.connect(alice).redeem(0, 10, 0, 0)
//       await nftManager.connect(alice).redeem(1, 10, 0, 0)
//       // await nftManager.connect(alice).redeem(2, 10, 0, 0)
//     } catch (e) {
//       // console.log(e)
//     }
//   })

  // it("Mint 1000x NFTs when LP > $1 mil.", async () => {
  //   try {
  //     // pumping liquidity
  //     await wEthToken
  //       .connect(admin)
  //       .approve(router.address, ethers.constants.MaxUint256)
  //     await usdcToken
  //       .connect(admin)
  //       .approve(router.address, ethers.constants.MaxUint256)

  //     await router.addLiquidity(
  //       wEthToken.address,
  //       usdcToken.address,
  //       toEther(1000000),
  //       toEther(2000000),
  //       0,
  //       0,
  //       admin.address,
  //       999999999999999
  //     )

  //     let totalSupply = await shareToken.totalSupply()
  //     let lpPrice = await nftManager.getCollateralSharePrice()

  //     const beforeLpSize =
  //       Number(fromEther(lpPrice)) * Number(fromEther(totalSupply))

  //     expect(beforeLpSize > 1000000).to.true

  //     // mass minting
  //     for (let round of [1, 2, 3, 4, 5]) {
  //       for (let user of [alice, bob, charlie]) {
  //         await wEthToken.connect(admin).transfer(user.address, toEther(10000))
  //         await usdcToken
  //           .connect(admin)
  //           .transfer(user.address, ethers.utils.parseUnits("1000", "6"))

  //         await wEthToken
  //           .connect(user)
  //           .approve(nftManager.address, ethers.constants.MaxUint256)
  //         await usdcToken
  //           .connect(user)
  //           .approve(nftManager.address, ethers.constants.MaxUint256)
  //         // Mint 100x $1 NFT
  //         let inputs = await nftManager.estimateMint(0, 10)
  //         await nftManager.connect(user).mint(0, 10, inputs[0], inputs[1])

  //         expect(await syntheticNft.balanceOf(user.address, 1)).to.equal(
  //           10 * round
  //         )

  //         // Mint 100x $10 NFT
  //         inputs = await nftManager.estimateMint(1, 10)
  //         await nftManager.connect(user).mint(1, 10, inputs[0], inputs[1])
  //         expect(await syntheticNft.balanceOf(user.address, 2)).to.equal(
  //           10 * round
  //         )

  //         // Mint 100x $100 NFT
  //         inputs = await nftManager.estimateMint(2, 10)
  //         await nftManager.connect(user).mint(2, 10, inputs[0], inputs[1])
  //         expect(await syntheticNft.balanceOf(user.address, 3)).to.equal(
  //           10 * round
  //         )
  //       }
  //     }

  //     totalSupply = await shareToken.totalSupply()
  //     lpPrice = await nftManager.getCollateralSharePrice()

  //     const afterLpSize =
  //       Number(fromEther(lpPrice)) * Number(fromEther(totalSupply))
  //     // the LP size should be increased
  //     expect(afterLpSize - beforeLpSize > 100000).to.true

  //     expect(Number((await nftManager.syntheticVariants(0))[6])).to.equal(150)
  //     expect(Number((await nftManager.syntheticVariants(1))[6])).to.equal(150)
  //     expect(Number((await nftManager.syntheticVariants(2))[6])).to.equal(150)

  //     // reduce the ratio before redeeming
  //     await nftManager.forceMint(0, 0, 100)
  //     await nftManager.forceMint(1, 0, 100)
  //     await nftManager.forceMint(2, 0, 100)

  //     // total NFT issued
  //     expect(
  //       1 > Number(fromEther(await nftManager.variantCollatelizationRatio(0)))
  //     ).to.true
  //     expect(
  //       1 > Number(fromEther(await nftManager.variantCollatelizationRatio(1)))
  //     ).to.true
  //     expect(
  //       1 > Number(fromEther(await nftManager.variantCollatelizationRatio(2)))
  //     ).to.true

  //     // TODO : Verify collaterals

  //     // redeem 1/3 NFT from each account
  //     for (let round of [1, 2]) {
  //       for (let user of [alice, bob, charlie]) {
  //         await syntheticNft
  //           .connect(user)
  //           .setApprovalForAll(nftManager.address, true)
  //         // Redeem 100x $1 NFT
  //         await nftManager.connect(user).redeem(0, 100, 0, 0)

  //         // Redeem 100x $10 NFT
  //         await nftManager.connect(user).redeem(1, 100, 0, 0)

  //         // Redeem 100x $100 NFT
  //         await nftManager.connect(user).redeem(2, 100, 0, 0)
  //       }
  //     }

  //     // total NFT burnt
  //     expect(Number((await nftManager.syntheticVariants(0))[7])).to.equal(600)
  //     expect(Number((await nftManager.syntheticVariants(1))[7])).to.equal(600)
  //     expect(Number((await nftManager.syntheticVariants(2))[7])).to.equal(600)
  //   } catch (e) {
  //     console.log(e)
  //   }
  // })
// })
