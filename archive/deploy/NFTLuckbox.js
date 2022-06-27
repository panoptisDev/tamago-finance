module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const nftLuckboxDeployment = "LuckBox"
  const nftLuckboxResult = await deploy(nftLuckboxDeployment, {
    contract: "LuckBoxUpgradeable",
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [],
      },
    },
    log: true,
    deterministicDeployment: false,
  })

  console.log(`${nftLuckboxDeployment} was deployed`)

  await hre.run("verify:verify", {
    address: nftLuckboxResult.implementation,
    constructorArguments: [],
  })
}

module.exports.tags = ["NFTLuckbox"]
