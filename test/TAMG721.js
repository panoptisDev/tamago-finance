const { expect } = require("chai")
const { ethers } = require("hardhat")

let erc721

let admin
let alice
let bob

const BAE_URI = "https://clonex-assets.rtfkt.com/"
const NFT_NAME = "TAMAGO NFT"
const NFT_SYMBOL = "TAMGNFT"
const MAX_SUPPLY = 1000
const RANDOM_HASH = 1000000

describe("TAMG721", () => {
  before(async () => {
    ;[admin, alice, bob] = await ethers.getSigners()

    const TAMG721 = await ethers.getContractFactory("TAMG721")

    erc721 = await TAMG721.deploy(
      BAE_URI,
      NFT_NAME,
      NFT_SYMBOL,
      MAX_SUPPLY,
      RANDOM_HASH
    )
  })

  it("Should return correct name", async function () {
    const name = await erc721.name()
    expect(name).to.equal(NFT_NAME)
  })

  it("Should return correct symbol", async function () {
    const symbol = await erc721.symbol()
    expect(symbol).to.equal(NFT_SYMBOL)
  })

  it("Should return correct max supply", async function () {
    const maxSupply = await erc721.maxSupply()
    expect(maxSupply).to.equal(MAX_SUPPLY)
  })

  it("Should return correct random hash", async function () {
    const randomHash = await erc721.randomHash()
    expect(randomHash).to.equal(RANDOM_HASH)
  })

	it("Should mint token successfully", async function () {
		await erc721.mint(alice.address, 1)

		const tokenAmount = await erc721.balanceOf(alice.address)

		expect(tokenAmount).to.equal(1)
	})

	it("Should return correct tokenURI", async function () {
		await erc721.mint(alice.address, 1)

		const tokenURI = await erc721.tokenURI(1)

		expect(tokenURI).to.equal(`${BAE_URI}1.json`)
	})

})
