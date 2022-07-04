module.exports = async ({ getNamedAccounts, deployments, network }) => {
	const { deploy } = deployments

	const { deployer, dev } = await getNamedAccounts()

	const nftLuckboxDeployment = "NFTLuckBoxV2"
	const nftLuckboxResult = await deploy(nftLuckboxDeployment, {
		contract: "NFTLuckboxV2",
		from: deployer,
		args: ["0x271682DEB8C4E0901D1a1550aD2e64D568E69909", "0x514910771af9ca656af840dff83e8264ecf986ca", "0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef"],
		log: true,
		deterministicDeployment: false,
	})

	console.log(`${nftLuckboxDeployment} was deployed`)

	await hre.run("verify:verify", {
		address: nftLuckboxResult.address,
		constructorArguments: ["0x271682DEB8C4E0901D1a1550aD2e64D568E69909", "0x514910771af9ca656af840dff83e8264ecf986ca", "0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef"]
	})
}

module.exports.tags = ["NFTLuckbox"]