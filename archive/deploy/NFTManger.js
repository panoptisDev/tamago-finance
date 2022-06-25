const { config: getConfig } = require("../constants")

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()
  const config = getConfig[network.name]

  const priceResolverDeployment = "PriceResolver"
  const priceResolverResult = await deploy(priceResolverDeployment, {
    contract: "PriceResolver",
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [dev],
      },
    },
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${priceResolverDeployment} was deployed`)

  const PriceResolver = await hre.ethers.getContractFactory("PriceResolver")
  const shareToken = await hre.ethers.getContractAt(
    "IPancakePair",
    config.token.lp.address
  )

  const priceResolver = PriceResolver.attach(priceResolverResult.address)

  const nftManagerDeployment = "NFTManager"
  const nftManagerResult = await deploy(nftManagerDeployment, {
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          config.nft.name,
          config.nft.tokenURI,
          priceResolver.address,
          shareToken.address,
          hre.ethers.utils.formatBytes32String(config.nft.lpSymbol),
          hre.ethers.utils.formatBytes32String(config.nft.syntheticSymbol),
          config.router,
          dev,
        ],
      },
    },
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${nftManagerDeployment} was deployed`)

  const syntheticNFTDeployment = "SyntheticNFT"
  const syntheticNFTResult = await deploy(syntheticNFTDeployment, {
    contract: "SyntheticNFT",
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          config.nft.name,
          config.nft.tokenURI,
          nftManagerResult.address,
        ],
      },
    },
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${syntheticNFTDeployment} was deployed`)

  const basePriceFeederDeployment = `${config.priceFeed.base.name}-ChainlinkPriceFeeder`
  const basePriceFeederResult = await deploy("ChainlinkPriceFeeder", {
    from: deployer,
    args: [
      config.priceFeed.base.name,
      config.priceFeed.base.address,
      config.priceFeed.base.decimals,
    ],
    log: true,
    deterministicDeployment: false,
  })
  console.log(`${basePriceFeederDeployment} was deployed`)

  const quotePriceFeederDeployment = `${config.priceFeed.quote.name}-ChainlinkPriceFeeder`
  const quotePriceFeederResult = await deploy("ChainlinkPriceFeeder", {
    from: deployer,
    args: [
      config.priceFeed.quote.name,
      config.priceFeed.quote.address,
      config.priceFeed.quote.decimals,
    ],
    log: true,
    deterministicDeployment: false,
  })
  console.log(`${quotePriceFeederDeployment} was deployed`)

  const usdPriceFeederDeployment = "USDPriceFeeder"
  const usdPriceFeederResult = await deploy(usdPriceFeederDeployment, {
    contract: "MockPriceFeeder",
    from: deployer,
    args: ["USD"],
    log: true,
    deterministicDeployment: false,
  })
  console.log(`${usdPriceFeederDeployment} was deployed`)

  const lpFeederDeployment = `${config.token.lp.name}-QuickswapLPFeeder`
  const lpFeederResult = await deploy(lpFeederDeployment, {
    contract: "QuickswapLPFeeder",
    from: deployer,
    args: [
      config.token.lp.name,
      config.token.lp.address,
      basePriceFeederResult.address,
      config.token.base.decimals,
      quotePriceFeederResult.address,
      config.token.quote.decimals,
    ],
    log: true,
    deterministicDeployment: false,
  })
  console.log(`${lpFeederDeployment} was deployed`)

  const FeederUsd = await hre.ethers.getContractFactory("MockPriceFeeder")
  const feederUsd = FeederUsd.attach(usdPriceFeederResult.address)

  const SyntheticNFT = await hre.ethers.getContractFactory("SyntheticNFT")
  const syntheticNFT = SyntheticNFT.attach(syntheticNFTResult.address)

  let updateTx, estimateGas

  // Update usd price feeder
  console.log(">> Update updateValue")
  estimateGas = await feederUsd.estimateGas.updateValue(
    hre.ethers.utils.parseEther("1")
  )
  updateTx = await feederUsd.updateValue(hre.ethers.utils.parseEther("1"), {
    gasLimit: estimateGas.add(100000),
  })
  console.log("✅ Done on => ", updateTx.hash)

  // Register base price feeder
  console.log(`>> Update ${config.token.base.name}/USD`)
  estimateGas = await priceResolver.estimateGas.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String(config.priceFeed.base.name),
    basePriceFeederResult.address,
    false,
    config.priceFeed.base.fallback
  )
  updateTx = await priceResolver.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String(config.priceFeed.base.name),
    basePriceFeederResult.address,
    false,
    config.priceFeed.base.fallback,
    { gasLimit: estimateGas.add(100000) }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Register quote price feeder
  console.log(`>> Update ${config.token.quote.name}/USD`)
  estimateGas = await priceResolver.estimateGas.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String(config.priceFeed.quote.name),
    quotePriceFeederResult.address,
    false,
    config.priceFeed.quote.fallback
  )
  updateTx = await priceResolver.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("USDC/USD"),
    quotePriceFeederResult.address,
    false,
    config.priceFeed.quote.fallback,
    { gasLimit: estimateGas.add(100000) }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Register usd price feeder to 1 usd
  console.log(">> Update USD")
  estimateGas = await priceResolver.estimateGas.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("USD"),
    feederUsd.address,
    false,
    hre.ethers.utils.parseEther("1")
  )
  updateTx = await priceResolver.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("USD"),
    feederUsd.address,
    false,
    hre.ethers.utils.parseEther("1"),
    { gasLimit: estimateGas.add(100000) }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Register lp price feeder
  console.log(`>> Update ${config.token.lp.name}`)
  estimateGas = await priceResolver.estimateGas.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String(config.priceFeed.lp.name),
    lpFeederResult.address,
    false,
    config.priceFeed.lp.fallback
  )
  updateTx = await priceResolver.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String(config.priceFeed.lp.name),
    lpFeederResult.address,
    false,
    config.priceFeed.lp.fallback,
    { gasLimit: estimateGas.add(100000) }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // NFTManager
  const NFTManager = await hre.ethers.getContractFactory("NFTManager")
  const nftManager = NFTManager.attach(nftManagerResult.address)

  const nftList = config.nft.list

  for (const item of nftList) {
    console.log(`>> Add Ang Bao ${item.price} USD`)
    estimateGas = await nftManager.estimateGas.addSyntheticVariant(
      item.name,
      item.tokenId,
      item.price
    )
    updateTx = await nftManager.addSyntheticVariant(
      item.name,
      item.tokenId,
      item.price,
      { gasLimit: estimateGas.add(100000) }
    )
    console.log("✅ Done on => ", updateTx.hash)
  }

  console.log(">> Set ready state")
  updateTx = await nftManager.setContractState(1)
  console.log("✅ Done on => ", updateTx.hash)

  // Set synthetic nft to nft manager
  console.log(">> Set synthetic nft to nft manager")
  estimateGas = await nftManager.estimateGas.setSyntheticNFT(
    syntheticNFTResult.address
  )
  updateTx = await nftManager.setSyntheticNFT(
    syntheticNFTResult.address
  )
  console.log("✅ Done on => ", updateTx.hash)

  const syntheticNftAddress = await nftManager.syntheticNFT()

  console.log(">> Synthetic NFT address")
  console.log(syntheticNftAddress)

  console.log("✅ Done 🦄")
}

module.exports.tags = ["NFTManager"]
