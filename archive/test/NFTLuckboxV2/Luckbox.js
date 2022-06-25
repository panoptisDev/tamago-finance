const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
const {
  fromEther,
  toEther,
  fromUsdc,
  toUsdc,
  deployPriceResolverMock,
  deployPriceResolver,
  deployPriceResolverV2,
} = require("../Helpers")

let nftProject
let whitelistNFT

let admin
let alice
let bob
let charlie
let dev

describe("NFTLuckbox V2", () => {
  beforeEach(async () => {
    ;[admin, alice, bob, charlie, dev] = await ethers.getSigners()

    const MockERC1155 = await ethers.getContractFactory("MockERC1155")
    const MockNFTProject = await ethers.getContractFactory("MockNFTProject")

    whitelistNFT = await MockERC1155.deploy(
      "https://api.cryptokitties.co/kitties/{id}"
    )
    nftProject = await MockNFTProject.deploy(
      "NFTProejct",
      "NFTProejct",
      whitelistNFT.address,
      1
    )

    // Mint 1 NFT
    await whitelistNFT.mint(admin.address, 1, 1, "0x00")
    await whitelistNFT.mint(alice.address, 1, 1, "0x00")

		await whitelistNFT.setApprovalForAll(nftProject.address, true)
		await whitelistNFT.connect(alice).setApprovalForAll(nftProject.address, true)
  })

	it("Should mint successfully", async () => {
		await nftProject.mint(admin.address, 1)
		await nftProject.connect(alice).mint(alice.address, 2)
  })

	it("Should revert with not nft", async () => {
		await expect(nftProject.connect(bob).mint(bob.address, 1)).to.revertedWith(
      "ERC1155: caller is not owner nor approved"
    )
  })
})
