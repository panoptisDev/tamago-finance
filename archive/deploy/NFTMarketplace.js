module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const nftMarketplaceDeployment = "NFTMarketplace"
  const nftMarketplaceResult = await deploy(nftMarketplaceDeployment, {
    contract: "NFTMarketplaceUpgradeable",
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

  console.log(`${nftMarketplaceDeployment} was deployed`)

  await hre.run("verify:verify", {
    address: nftMarketplaceResult.implementation,
    constructorArguments: [],
  })
}

module.exports.tags = ["NFTMarketplace"]
