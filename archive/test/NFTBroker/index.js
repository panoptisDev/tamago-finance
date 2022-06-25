const { expect } = require("chai")
const { ethers } = require("hardhat")

let nftBroker
let erc1155

let admin
let alice
let bob
let charlie

const DEV_ADDRESS = "0x91C65f404714Ac389b38335CccA4A876a8669d32"
const ADDRESS_ZERO = ethers.constants.AddressZero

describe("NFTBroker", () => {
  beforeEach(async () => {
    ;[admin, alice, bob, charlie] = await ethers.getSigners()

    const NFTBroker = await ethers.getContractFactory("NFTBroker")
    const MockERC1155 = await ethers.getContractFactory("MockERC1155")

    nftBroker = await NFTBroker.deploy()

    erc1155 = await MockERC1155.deploy(
      "https://api.cryptokitties.co/kitties/{id}"
    )
    const tokenIds = [0, 1, 2, 3, 4, 5, 6, 7, 8]
    //minting ERC-1155
    for (let id of tokenIds) {
      await erc1155.mint(admin.address, id, 10, "0x00")
    }
    await erc1155.setApprovalForAll(nftBroker.address, true)
  })

  /**
   * @Test
   */
  //Deposit test 1
  it("Should deposit successfully", async () => {
    await nftBroker.deposit(erc1155.address, 1, 0)

    expect(await erc1155.balanceOf(admin.address, 0)).to.equal(9)
    expect(await erc1155.balanceOf(nftBroker.address, 0)).to.equal(1)
  })

  //Deposit test 2
  it("Should error when there's 0 amount of NFTs (Deposit func)", async () => {
    await expect(nftBroker.deposit(erc1155.address, 0, 0)).to.revertedWith(
      "Amount cannot be zero"
    )
  })

  //Deposit test 3 + _addNft
  it("Should add new nft successfully", async () => {
    await nftBroker.deposit(erc1155.address, 1, 0)

    let nft = await nftBroker.getNft(0)

    expect(nft.assetAddress).to.equal(erc1155.address)
    expect(nft.tokenIds.map((x) => parseInt(x, 16))).deep.to.equal([0])

    await nftBroker.deposit(erc1155.address, 1, 1)

    nft = await nftBroker.getNft(0)

    expect(nft.tokenIds.map((x) => parseInt(x, 16))).deep.to.equal([0, 1])
  })

  //Withdraw test 1
  it("Should withdraw successfully", async () => {
    //deposit before withdraw
    await nftBroker.deposit(erc1155.address, 1, 0)

    await nftBroker.withdraw(erc1155.address, 1, 0)

    expect(await erc1155.balanceOf(admin.address, 0)).to.equal(10)
    expect(await erc1155.balanceOf(nftBroker.address, 0)).to.equal(0)
  })

  //Withdraw test 2
  it("Should error when there's 0 amount of NFTs (Withdraw func)", async () => {
    await expect(nftBroker.withdraw(erc1155.address, 0, 0)).to.revertedWith(
      "Amount cannot be zero"
    )
  })

  //SetRate test 1
  it("Should error when address 0 (SetRate)", async () => {
    await expect(nftBroker.setRate(ADDRESS_ZERO, 0, 0, 1)).to.revertedWith(
      "Cannot be address 0"
    )
  })

  //SetRate test 2
  it("Should error when rate less than 0", async () => {
    await expect(nftBroker.setRate(erc1155.address, 0, 0, 0)).to.revertedWith(
      "Rate cannot be less than 0"
    )
  })

  //SetRate test 3
  it("Should set rate to mapping", async () => {
    await nftBroker.setRate(erc1155.address, 0, 1, 2)

    let rate = await nftBroker.getRate(erc1155.address, 0, 1)

    expect(rate).to.equal(2)
  })

  //RemoveRate test 1
  it("Should error when address 0 (RemoveRate)", async () => {
    await expect(nftBroker.removeRate(ADDRESS_ZERO, 0, 1)).to.revertedWith(
      "Cannot be address 0"
    )
  })

  //RemoveRate test 2
  it("Should remove rate in mapping", async () => {
    await nftBroker.setRate(erc1155.address, 0, 1, 2)
    await nftBroker.removeRate(erc1155.address, 0, 1)

    let rate = await nftBroker.getRate(erc1155.address, 0, 1)

    expect(rate).to.equal(0)
  })

  //GetRate test1
  it("Should get rate in mapping", async () => {
    await nftBroker.setRate(erc1155.address, 0, 1, 2)

    let rate = await nftBroker.getRate(erc1155.address, 0, 1)
    let initialRate = await nftBroker.getRate(erc1155.address, 2, 3)

    expect(rate).to.equal(2)
    expect(initialRate).to.equal(0)
  })

  //Swap test 1
  it("Should swap successfully", async () => {
    await nftBroker.setRate(erc1155.address, 0, 1, 5)
    await nftBroker.deposit(erc1155.address, 10, 1)

    await nftBroker.swap(erc1155.address, 0, 1, 1)

    expect(await erc1155.balanceOf(admin.address, 0)).to.equal(9)
    expect(await erc1155.balanceOf(admin.address, 1)).to.equal(5)
  })

  //Swap test 2
  it("Should error when swapRate is 0", async () => {
    await nftBroker.setRate(erc1155.address, 0, 1, 5)
    await nftBroker.deposit(erc1155.address, 10, 1)
    await nftBroker.removeRate(erc1155.address, 0, 1)

    await expect(nftBroker.swap(erc1155.address, 0, 1, 1)).to.revertedWith(
      "Cannot swap because swap rate is 0"
    )
  })
})
