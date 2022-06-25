// const { expect } = require("chai")
// const { ethers } = require("hardhat")
// const { fromEther, toEther } = require("../Helpers")

// describe("Gas compair dex vs swap", function () {
//   let nftDex
//   let erc721

//   let admin
//   let alice

//   let tokenIds

//   beforeEach(async () => {
//     ;[admin, alice, bob, dev, treasury] = await ethers.getSigners()

//     const feeBps = 100 // 1%

//     const NFTDex = await ethers.getContractFactory("MockNFTDex")
//     const MockERC721 = await ethers.getContractFactory("MockERC721")

//     nftDex = await NFTDex.deploy(feeBps)

//     erc721 = await MockERC721.deploy("Mock NFT", "MOCK")

//     tokenIds = [0, 1, 2, 3, 4, 5, 6, 7, 8]

//     // minting ERC-721
//     for (let id of tokenIds) {
//       await erc721.mint(admin.address, id)
//     }

//     await erc721.setApprovalForAll(nftDex.address, true)
//   })

//   describe("Return from luckbox with erc721", () => {
//     beforeEach(async () => {
//       for (let id of tokenIds) {
//         await nftDex.list(erc721.address, id, toEther("1"))
//       }
//     })

//     context("when buy nft when listing", () => {
//       it("Should return nft that user buy", async function () {
//         for (let id of tokenIds) {
//           await nftDex
//             .connect(alice)
//             .buy(erc721.address, id, { value: toEther("1") })

//           const owner = await erc721.ownerOf(id)

//           expect(owner).to.eq(await alice.getAddress())
//         }
//       })
//     })

//     context("when unlist nft ", () => {
//       it("Should return nft that user unlist", async function () {
//         for (let id of tokenIds) {
//           await nftDex.unlist(erc721.address, id)

//           const owner = await erc721.ownerOf(id)

//           expect(owner).to.eq(await admin.getAddress())
//         }
//       })
//     })
//   })
// })
