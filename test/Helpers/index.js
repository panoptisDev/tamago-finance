const { ethers } = require("hardhat")

exports.fromEther = (value) => {
  return ethers.utils.formatEther(value)
}

exports.fromUsdc = (value) => {
  return ethers.utils.formatUnits(value, 6)
}

exports.toEther = (value) => {
  return ethers.utils.parseEther(`${value}`)
}

exports.toUsdc = (value) => {
  return ethers.utils.parseUnits(`${value}`, 6)
}

const latestBlockNumber = async () => {
  const block = await ethers.provider.getBlock("latest")
  return ethers.BigNumber.from(block.number)
}

exports.advanceBlockTo = async (block) => {
  let latestBlock = (await latestBlockNumber()).toNumber()

  if (block <= latestBlock) {
    throw new Error("input block exceeds current block")
  }

  while (block > latestBlock) {
    await advanceBlock()
    latestBlock++
  }
}

const advanceBlock = async () => {
  await ethers.provider.send("evm_mine", [])
}
