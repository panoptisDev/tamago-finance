module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const mockERC721Deployment = "MockERC721"
  const mockERC721Result = await deploy(mockERC721Deployment, {
    contract: "MockERC721",
    from: deployer,
    log: true,
    args: [
      "Mock NFT", "MOCK"
    ],
    deterministicDeployment: false,
  })

  console.log(`${mockERC721Deployment} was deployed`)

  // await hre.run("verify:verify", {
  //   address: mockERC721Result.address,
  //   constructorArguments: ["Mock NFT", "MOCK"],
  // })

  const mockERC1155Deployment = "MockERC1155"
  const mockERC1155Result = await deploy(mockERC1155Deployment, {
    contract: "MockERC1155",
    from: deployer,
    log: true,
    args: [
      "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/"
    ],
    deterministicDeployment: false,
  })

  console.log(`${mockERC1155Deployment} was deployed`)

  // await hre.run("verify:verify", {
  //   address: mockERC1155Result.address,
  //   constructorArguments: ["ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/"],
  // })
}

module.exports.tags = ["MockNFT"]
