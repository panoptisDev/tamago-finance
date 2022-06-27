const { config: getConfig } = require("../constants")
const { toEther } = require("../test/Helpers")

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()
  const [defaultDeployer] = await ethers.getSigners()

  const registryDeployment = "Registry"
  const registryResult = await deploy(registryDeployment, {
    contract: "Registry",
    from: deployer,
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${registryDeployment} was deployed`)

  const priceResolverDeployment = "PriceResolver"
  const priceResolverResult = await deploy(priceResolverDeployment, {
    contract: "PriceResolverUpgradeable",
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [deployer],
      },
    },
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${priceResolverDeployment} was deployed`)

  const feederUsdcDeployment = "FeederUsdc"
  const feederUsdcResult = await deploy(feederUsdcDeployment, {
    contract: "MockPriceFeeder",
    from: deployer,
    args: ["USDC/USD"],
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${feederUsdcResult} was deployed`)

  const feederUsdtDeployment = "FeederUsdt"
  const feederUsdtResult = await deploy(feederUsdtDeployment, {
    contract: "MockPriceFeeder",
    from: deployer,
    args: ["USDT/USD"],
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${feederUsdtResult} was deployed`)

  const feederDaiDeployment = "FeederDai"
  const feederDaiResult = await deploy(feederDaiDeployment, {
    contract: "MockPriceFeeder",
    from: deployer,
    args: ["DAI/USD"],
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${feederDaiResult} was deployed`)

  const feederUsdDeployment = "FeederDai"
  const feederUsdResult = await deploy(feederUsdDeployment, {
    contract: "MockPriceFeeder",
    from: deployer,
    args: ["USD"],
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${feederUsdResult} was deployed`)

  // Attach contract
  const PriceResolver = await hre.ethers.getContractFactory("PriceResolver")
  const Registry = await hre.ethers.getContractFactory("Registry")
  const MockPriceFeeder = await hre.ethers.getContractFactory("MockPriceFeeder")

  const priceResolver = PriceResolver.attach(priceResolverResult.address)
  const registry = Registry.attach(registryResult.address)
  const feederUsdc = MockPriceFeeder.attach(feederUsdcResult.address)
  const feederUsdt = MockPriceFeeder.attach(feederUsdtResult.address)
  const feederDai = MockPriceFeeder.attach(feederDaiResult.address)
  const feederUsd = MockPriceFeeder.attach(feederUsdResult.address)

  let nonce = await defaultDeployer.getTransactionCount()
  let updateTx, estimateGas

  // Update usd price feeder
  console.log(">> Update updateValue")
  estimateGas = await feederUsd.estimateGas.updateValue(
    hre.ethers.utils.parseEther("1")
  )
  updateTx = await feederUsd.updateValue(hre.ethers.utils.parseEther("1"), {
    gasLimit: estimateGas.add(150000),
    nonce: nonce++,
  })
  console.log("✅ Done on => ", updateTx.hash)

  // Update usdc price feeder
  console.log(">> Update updateValue")
  estimateGas = await feederUsdc.estimateGas.updateValue(
    hre.ethers.utils.parseEther("0.9998")
  )
  updateTx = await feederUsdc.updateValue(
    hre.ethers.utils.parseEther("0.9998"),
    {
      gasLimit: estimateGas.add(150000),
      nonce: nonce++,
    }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Update usdt price feeder
  console.log(">> Update updateValue")
  estimateGas = await feederUsdt.estimateGas.updateValue(
    hre.ethers.utils.parseEther("0.9999")
  )
  updateTx = await feederUsdt.updateValue(
    hre.ethers.utils.parseEther("0.9999"),
    {
      gasLimit: estimateGas.add(150000),
      nonce: nonce++,
    }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Update dai price feeder
  console.log(">> Update updateValue")
  estimateGas = await feederDai.estimateGas.updateValue(
    hre.ethers.utils.parseEther("0.9995")
  )
  updateTx = await feederDai.updateValue(
    hre.ethers.utils.parseEther("0.9995"),
    {
      gasLimit: estimateGas.add(150000),
      nonce: nonce++,
    }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Register USDC/USD price feeder
  console.log(`>> Update USDC/USD`)
  estimateGas = await priceResolver.estimateGas.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("USDC/USD"),
    feederUsdc.address,
    false,
    toEther(0.9998)
  )
  updateTx = await priceResolver.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("USDC/USD"),
    feederUsdc.address,
    false,
    toEther(0.9998),
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Register USDT/USD price feeder
  console.log(`>> Update USDT/USD`)
  estimateGas = await priceResolver.estimateGas.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("USDT/USD"),
    feederUsdt.address,
    false,
    toEther(0.9999)
  )
  updateTx = await priceResolver.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("USDT/USD"),
    feederUsdt.address,
    false,
    toEther(0.9999),
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Register DAI/USD price feeder
  console.log(`>> Update DAI/USD`)
  estimateGas = await priceResolver.estimateGas.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("DAI/USD"),
    feederDai.address,
    false,
    toEther(0.9995)
  )
  updateTx = await priceResolver.registerPriceFeeder(
    hre.ethers.utils.formatBytes32String("DAI/USD"),
    feederDai.address,
    false,
    toEther(0.9995),
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
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
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Registry
  // registry it to the registry
  console.log(">> Registry it to the registry")
  estimateGas = await registry.estimateGas.registerContract(
    ethers.utils.formatBytes32String("PRICE_RESOLVER"),
    priceResolver.address
  )
  updateTx = await registry.registerContract(
    ethers.utils.formatBytes32String("PRICE_RESOLVER"),
    priceResolver.address,
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // deploy an synthetic NFT contract
  console.log(">> Deploy an synthetic NFT contract")
  estimateGas = await registry.estimateGas.deploySyntheticNFT(
    ethers.utils.formatBytes32String("TAMAGO_NFT"),
    "TAMAGO NFT",
    "https://api.cryptokitties.co/kitties/{id}"
  )
  updateTx = await registry.deploySyntheticNFT(
    ethers.utils.formatBytes32String("TAMAGO_NFT"),
    "TAMAGO NFT",
    "https://api.cryptokitties.co/kitties/{id}",
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Deploy NFT Manager
  const nftManagerDeployment = "NFTManagerUpgradeable"
  const nftManagerResult = await deploy(nftManagerDeployment, {
    contract: "NFTManagerUpgradeable",
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          registry.address,
          ethers.utils.formatBytes32String("USD"),
          ethers.utils.formatBytes32String("PRICE_RESOLVER"),
          ethers.utils.formatBytes32String("TAMAGO_NFT"),
          deployer,
        ],
      },
    },
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${nftManagerDeployment} was deployed`)

  const NFTManager = await hre.ethers.getContractFactory(
    "NFTManagerUpgradeable"
  )
  const nftManager = NFTManager.attach(nftManagerResult.address)

  nonce = await defaultDeployer.getTransactionCount()

  // Register Contract
  console.log(">> Register Contract")
  estimateGas = await registry.estimateGas.registerContract(
    ethers.utils.formatBytes32String("USD_VOUCHER"),
    nftManager.address
  )
  updateTx = await registry.registerContract(
    ethers.utils.formatBytes32String("USD_VOUCHER"),
    nftManager.address,
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Allow nftManager contract to mint/burn NFT
  console.log(">> Allow nftManager contract to mint/burn NFT")
  estimateGas = await registry.estimateGas.permitToMint(
    ethers.utils.formatBytes32String("USD_VOUCHER"),
    ethers.utils.formatBytes32String("TAMAGO_NFT")
  )
  updateTx = await registry.permitToMint(
    ethers.utils.formatBytes32String("USD_VOUCHER"),
    ethers.utils.formatBytes32String("TAMAGO_NFT"),
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  const usdcDeployment = "MockUsdc"
  const usdcResult = await deploy(usdcDeployment, {
    contract: "MockERC20",
    from: deployer,
    args: ["Mock USDC", "USDC"],
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${usdcResult} was deployed`)

  const usdtDeployment = "MockUsdt"
  const usdtResult = await deploy(usdtDeployment, {
    contract: "MockERC20",
    from: deployer,
    args: ["Mock USDT", "USDT"],
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${usdtResult} was deployed`)

  const daiDeployment = "MockDai"
  const daiResult = await deploy(daiDeployment, {
    contract: "MockERC20",
    from: deployer,
    args: ["Mock DAI", "DAI"],
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${daiResult} was deployed`)

  // Attach token
  const MockERC20 = await hre.ethers.getContractFactory("MockERC20")

  const usdc = MockERC20.attach(usdcResult.address)
  const usdt = MockERC20.attach(usdtResult.address)
  const dai = MockERC20.attach(daiResult.address)

  nonce = await defaultDeployer.getTransactionCount()
  // Set USDC Decimals
  console.log(">> Set USDC Decimals")
  estimateGas = await usdc.estimateGas.setDecimals(6)
  updateTx = await usdc.setDecimals(6, {
    gasLimit: estimateGas.add(150000),
    nonce: nonce++,
  })
  console.log("✅ Done on => ", updateTx.hash)

  // Set USDT Decimals
  console.log(">> Set USDT Decimals")
  estimateGas = await usdt.estimateGas.setDecimals(6)
  updateTx = await usdt.setDecimals(6, {
    gasLimit: estimateGas.add(150000),
    nonce: nonce++,
  })
  console.log("✅ Done on => ", updateTx.hash)

  // Set USDC as collateral assets
  console.log(">> Set USDC as collateral assets")
  estimateGas = await nftManager.estimateGas.addCollateralAsset(
    "USDC",
    ethers.utils.formatBytes32String("USDC/USD"),
    usdc.address,
    6
  )
  updateTx = await nftManager.addCollateralAsset(
    "USDC",
    ethers.utils.formatBytes32String("USDC/USD"),
    usdc.address,
    6,
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Set USDT as collateral assets
  console.log(">> Set USDT as collateral assets")
  estimateGas = await nftManager.estimateGas.addCollateralAsset(
    "USDT",
    ethers.utils.formatBytes32String("USDT/USD"),
    usdt.address,
    6
  )
  updateTx = await nftManager.addCollateralAsset(
    "USDT",
    ethers.utils.formatBytes32String("USDT/USD"),
    usdt.address,
    6,
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // Set DAI as collateral assets
  console.log(">> Set DAI as collateral assets")
  estimateGas = await nftManager.estimateGas.addCollateralAsset(
    "DAI",
    ethers.utils.formatBytes32String("DAI/USD"),
    dai.address,
    6
  )
  updateTx = await nftManager.addCollateralAsset(
    "DAI",
    ethers.utils.formatBytes32String("DAI/USD"),
    dai.address,
    6,
    { gasLimit: estimateGas.add(150000), nonce: nonce++ }
  )
  console.log("✅ Done on => ", updateTx.hash)

  // setup variants
  console.log(">> Setup Voucher 1 USD")
  estimateGas = await nftManager.estimateGas.addSyntheticVariant(
    "Voucher 1 USD",
    1,
    toEther(1)
  )
  updateTx = await nftManager.addSyntheticVariant(
    "Voucher 1 USD",
    1,
    toEther(1),
    {
      gasLimit: estimateGas.add(150000),
      nonce: nonce++,
    }
  )
  console.log("✅ Done on => ", updateTx.hash)

  console.log(">> Setup Voucher 10 USD")
  estimateGas = await nftManager.estimateGas.addSyntheticVariant(
    "Voucher 10 USD",
    2,
    toEther(10)
  )
  updateTx = await nftManager.addSyntheticVariant(
    "Voucher 10 USD",
    2,
    toEther(10),
    {
      gasLimit: estimateGas.add(150000),
      nonce: nonce++,
    }
  )
  console.log("✅ Done on => ", updateTx.hash)

  console.log(">> Setup Voucher 100 USD")
  estimateGas = await nftManager.estimateGas.addSyntheticVariant(
    "Voucher 100 USD",
    3,
    toEther(100)
  )
  updateTx = await nftManager.addSyntheticVariant(
    "Voucher 100 USD",
    3,
    toEther(100),
    {
      gasLimit: estimateGas.add(150000),
      nonce: nonce++,
    }
  )
  console.log("✅ Done on => ", updateTx.hash)

  const syntheticNftAddress = await nftManager.syntheticNFT()
  console.log("syntheticNftAddress", syntheticNftAddress)

  console.log("✅ Done 🦄")
}

module.exports.tags = ["NFTManagerV2"]
