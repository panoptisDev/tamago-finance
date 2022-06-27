// const { expect } = require("chai")
// const { ethers } = require("hardhat")
// const { fromEther, toEther } = require("../Helpers")

// describe("Gas compair dex vs swap", function () {
//   let nftP2P
//   let erc721

//   let admin
//   let alice

//   let tokenIds

//   beforeEach(async () => {
//     ;[admin, alice, bob, dev, treasury] = await ethers.getSigners()

//     const NFTP2P = await ethers.getContractFactory("MockP2P")
//     const ERC721 = await ethers.getContractFactory("MockERC721")

//     const price = toEther("1")
//     const name = "Ang Bao"
//     const symbol = "ABO"
//     nftP2P = await NFTP2P.deploy(price, name, symbol)
//     const nftAddress = await nftP2P.nft()

//     erc721 = await ERC721.attach(nftAddress)
//   })

//   describe("Swap P2P NFT", () => {
//     context("when buy nft", () => {
//       it("Should return nft that user buy", async function () {
//         for (let i = 0; i < 10; i++) {
//           await nftP2P.buy({ value: toEther("1") })

//           const owner = await erc721.ownerOf(i)

//           expect(owner).to.eq(await admin.getAddress())
//         }
//       })
//     })
//   })
// })
