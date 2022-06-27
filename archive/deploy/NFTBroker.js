module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;

  const { deployer, dev } = await getNamedAccounts();

  const nftBrokerDeployment = "Broker";
  const nftBrokerResult = await deploy(nftBrokerDeployment, {
    contract: "NFTBrokerUpgradeable",
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
  });

  console.log(`${nftBrokerDeployment} was deployed`);

  await hre.run("verify:verify", {
    address: nftBrokerResult.implementation,
    constructorArguments: [],
  });
};

module.exports.tags = ["NFTBroker"];
