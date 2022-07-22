const { expect } = require("chai")
const { ethers } = require("hardhat")
const { advanceBlockTo } = require("./Helpers")

let erc721

let admin
let alice
let bob

const SaleState = {
  NotStarted: 0,
  PrivateSaleBeforeWithoutBlock: 1,
  PrivateSaleBeforeWithBlock: 2,
  PrivateSaleDuring: 3,
  PrivateSaleEnd: 4,
  PrivateSaleEndSoldOut: 5,
  PublicSaleBeforeWithoutBlock: 6,
  PublicSaleBeforeWithBlock: 7,
  PublicSaleDuring: 8,
  PublicSaleEnd: 9,
  PublicSaleEndSoldOut: 10,
  PauseSale: 11,
  AllSalesEnd: 12,
}

const BASE_URI = "https://clonex-assets.rtfkt.com/"
const NFT_NAME = "TAMAGO NFT"
const NFT_SYMBOL = "TAMGNFT"
const MAX_SUPPLY = 1000
const RANDOM_HASH = 1000000
const PRIVATESALE_PRICE = 100
const PUBLICSALE_PRICE = 10
const PRIVATESALE_CONFIG = {
  beginBlock: 10,
  endBlock: 20,
}
const PUBLICSALE_CONFIG = {
  beginBlock: 30,
  endBlock: 40,
}

describe("TAMG721", () => {
  before(async () => {
    ;[admin, alice, bob] = await ethers.getSigners()

    const TAMG721 = await ethers.getContractFactory("TAMG721")

    erc721 = await TAMG721.deploy(
      PRIVATESALE_PRICE,
      PUBLICSALE_PRICE,
      BASE_URI,
      NFT_NAME,
      NFT_SYMBOL,
      MAX_SUPPLY,
      RANDOM_HASH,
      PRIVATESALE_CONFIG,
      PUBLICSALE_CONFIG
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
    const randomHash = await erc721.seed()
    expect(randomHash).to.equal(RANDOM_HASH)
  })

  it("Should return correct private sale price", async function () {
    const privateSalePrice = await erc721.privateSalePrice()
    expect(privateSalePrice).to.equal(PRIVATESALE_PRICE)
  })

  it("Should return correct public sale price", async function () {
    const publicSalePrice = await erc721.publicSalePrice()
    expect(publicSalePrice).to.equal(PUBLICSALE_PRICE)
  })

  it("Should return correct state", async function () {
    const saleState = await erc721.getState()
    expect(saleState).to.equal(SaleState.NotStarted)
  })

  // it("Should mint token successfully in private sale", async function () {
  //   await advanceBlockTo(PRIVATESALE_CONFIG.beginBlock)
  //   await erc721.enablePrivateSale()
  //   expect(await erc721.getState()).to.equal(SaleState.PrivateSaleDuring)
  //   await erc721.mint(alice.address, 1)

  //   const tokenAmount = await erc721.balanceOf(alice.address)

  //   expect(tokenAmount).to.equal(1)
  // })

  it("Should mint token successfully in public sale", async function () {
    await advanceBlockTo(PUBLICSALE_CONFIG.beginBlock)
    await erc721.enablePublicSale()
    expect(await erc721.getState()).to.equal(SaleState.PublicSaleDuring)
    await erc721.connect(alice).mint(1, ethers.utils.formatBytes32String(""), {
      value: PUBLICSALE_PRICE,
    })

    const tokenAmount = await erc721.balanceOf(alice.address)

    expect(tokenAmount).to.equal(1)
  })

  it("Should return correct tokenURI", async function () {
    await erc721.enablePublicSale()
    expect(await erc721.getState()).to.equal(SaleState.PublicSaleDuring)
    await erc721.connect(alice).mint(1, ethers.utils.formatBytes32String(""), {
      value: PUBLICSALE_PRICE,
    })

    const tokenURI = await erc721.tokenURI(1)

    expect(tokenURI).to.equal(`${BASE_URI}1.json`)
  })
})
