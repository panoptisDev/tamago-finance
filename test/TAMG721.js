const { expect } = require("chai")
const { ethers } = require("hardhat")
const { advanceBlockTo } = require("./Helpers")
const keccak256 = require("keccak256")
const { MerkleTree } = require("merkletreejs")

let erc721

let admin
let alice
let bob

let tree
let tokenTree

let token1
let token2
let token3

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
const PRIVATESALE_CONFIG = {
  beginBlock: 10,
  endBlock: 20,
  nativePrice: 100,
  stablePrice: 100,
}
const PUBLICSALE_CONFIG = {
  beginBlock: 30,
  endBlock: 40,
  nativePrice: 100,
  stablePrice: 100,
}

describe("TAMG721", () => {
  before(async () => {
    ;[admin, alice, bob] = await ethers.getSigners()

    const TAMG721 = await ethers.getContractFactory("TAMG721")
    const ERC20 = await ethers.getContractFactory("MockERC20")

    token1 = await ERC20.deploy("TOKEN1", "TOKEN1", 18)
    token2 = await ERC20.deploy("TOKEN2", "TOKEN2", 18)
    token3 = await ERC20.deploy("TOKEN3", "TOKEN3", 18)

    await token1.connect(alice).faucet()
    await token1.connect(bob).faucet()

    const whitelistAddr = [alice.address, bob.address]
    const leaves = whitelistAddr.map((addr) => keccak256(addr))
    tree = new MerkleTree(leaves, keccak256, { sortPairs: true })

    const whitelsitToken = [token1.address, token2.address, token3.address]
    const tokenLeaves = whitelsitToken.map((token) => keccak256(token))
    tokenTree = new MerkleTree(tokenLeaves, keccak256, { sortPairs: true })

    const root = tree.getHexRoot()
    const tokenRoot = tokenTree.getHexRoot()

    erc721 = await TAMG721.deploy(
      BASE_URI,
      NFT_NAME,
      NFT_SYMBOL,
      MAX_SUPPLY,
      RANDOM_HASH,
      PRIVATESALE_CONFIG,
      PUBLICSALE_CONFIG,
      root,
      tokenRoot
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
    const privateSalePrice = await erc721.privateSale()
    expect(privateSalePrice.nativePrice).to.equal(
      PRIVATESALE_CONFIG.nativePrice
    )
  })

  it("Should return correct public sale price", async function () {
    const publicSalePrice = await erc721.publicSale()
    expect(publicSalePrice.nativePrice).to.equal(PUBLICSALE_CONFIG.nativePrice)
  })

  it("Should return correct state", async function () {
    const saleState = await erc721.getState()
    expect(saleState).to.equal(SaleState.NotStarted)
  })

  it("Should mint token successfully in private sale", async function () {
    await advanceBlockTo(PRIVATESALE_CONFIG.beginBlock)
    await erc721.enablePrivateSale()
    expect(await erc721.getState()).to.equal(SaleState.PrivateSaleDuring)
    const proof = tree.getHexProof(ethers.utils.keccak256(alice.address))
    await erc721.connect(alice).mint(1, proof, {
      value: PRIVATESALE_CONFIG.nativePrice,
    })

    const tokenAmount = await erc721.balanceOf(alice.address)

    expect(tokenAmount).to.equal(1)
  })

  it("Should mint token successfully with token in private sale", async function () {
    expect(await erc721.getState()).to.equal(SaleState.PrivateSaleDuring)
    const proofToken = tokenTree.getHexProof(
      ethers.utils.keccak256(token1.address)
    )
    const proof = tree.getHexProof(ethers.utils.keccak256(bob.address))
    await token1
      .connect(bob)
      .approve(erc721.address, ethers.constants.MaxUint256)
    await erc721
      .connect(bob)
      .mintWithToken(
        1,
        proof,
        proofToken,
        token1.address,
        PRIVATESALE_CONFIG.stablePrice
      )

    const tokenAmount = await erc721.balanceOf(bob.address)

    expect(tokenAmount).to.equal(1)
  })

  it("Should mint token successfully in public sale", async function () {
    await advanceBlockTo(PUBLICSALE_CONFIG.beginBlock)
    await erc721.enablePublicSale()
    expect(await erc721.getState()).to.equal(SaleState.PublicSaleDuring)
    await erc721
      .connect(alice)
      .mint(1, [ethers.utils.formatBytes32String("")], {
        value: PUBLICSALE_CONFIG.nativePrice,
      })

    const tokenAmount = await erc721.balanceOf(alice.address)

    expect(tokenAmount).to.equal(2)
  })

  it("Should mint token successfully with token in public sale", async function () {
    expect(await erc721.getState()).to.equal(SaleState.PublicSaleDuring)
    const proofToken = tokenTree.getHexProof(
      ethers.utils.keccak256(token1.address)
    )
    await token1
      .connect(bob)
      .approve(erc721.address, ethers.constants.MaxUint256)
    await erc721
      .connect(bob)
      .mintWithToken(
        1,
        [ethers.utils.formatBytes32String("")],
        proofToken,
        token1.address,
        PUBLICSALE_CONFIG.stablePrice
      )

    const tokenAmount = await erc721.balanceOf(alice.address)

    expect(tokenAmount).to.equal(2)
  })

  it("Should return correct tokenURI", async function () {
    await erc721.enablePublicSale()
    expect(await erc721.getState()).to.equal(SaleState.PublicSaleDuring)
    await erc721
      .connect(alice)
      .mint(1, [ethers.utils.formatBytes32String("")], {
        value: PUBLICSALE_CONFIG.nativePrice,
      })

    const tokenURI = await erc721.tokenURI(1)
    const tokenAmount = await erc721.balanceOf(alice.address)

    expect(tokenAmount).to.equal(3)
    expect(tokenURI).to.equal(`${BASE_URI}1.json`)
  })
})
