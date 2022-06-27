const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
const { MerkleTree } = require('merkletreejs')
const keccak256 = require("keccak256")

let erc721
let erc1155

let luckbox

describe("NFTLuckbox V2", () => {

    beforeEach(async () => {
        [admin, alice, bob, charlie, dev] = await ethers.getSigners()

        const MockERC1155 = await ethers.getContractFactory("MockERC1155")
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        const NFTLuckboxV2 = await ethers.getContractFactory("NFTLuckboxV2");

        erc721 = await MockERC721.deploy("Mock NFT", "MOCK")
        erc1155 = await MockERC1155.deploy(
            "https://api.cryptokitties.co/kitties/{id}"
        )
        luckbox = await NFTLuckboxV2.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.HashZero)

    })

    it("Should deposit NFT successfully", async () => {

        // Mint 3 NFT, 2x each
        const tokenIds = [1, 2, 3]

        for (let id of tokenIds) {
            await erc1155.mint(admin.address, id, 2, "0x00")
            await erc721.mint(admin.address, id)
        }

        await erc1155.setApprovalForAll(luckbox.address, true)
        await erc721.setApprovalForAll(luckbox.address, true)

        for (let id of tokenIds) {
            await luckbox.depositERC1155(
                erc1155.address,
                id,
                2
            )
            expect(await erc1155.balanceOf(luckbox.address, id)).to.equal(2)
            await luckbox.depositERC721(
                erc721.address,
                id
            )
        }

        expect(await erc721.balanceOf(luckbox.address)).to.equal(3)
    })

    it("Should add rewards and withdraw NFTs successfully", async () => {

        let rewardCount = 1

        // Mint 3 NFT, 2x each
        const tokenIds = [1, 2, 3]

        for (let id of tokenIds) {
            await erc1155.mint(admin.address, id, 2, "0x00")
            await erc721.mint(admin.address, id)
        }

        await erc1155.setApprovalForAll(luckbox.address, true)
        await erc721.setApprovalForAll(luckbox.address, true)

        // add records for Alice
        for (let id of tokenIds) {
            await luckbox.connect(alice).addReward(rewardCount, erc1155.address, id, true)
            await luckbox.connect(alice).addReward(rewardCount + 1, erc721.address, id, false)

            const rewardErc1155 = await luckbox.rewards(rewardCount)
            expect(rewardErc1155["assetAddress"] === erc1155.address).to.true
            expect(Number(rewardErc1155["tokenId"]) === id).to.true
            expect(rewardErc1155["is1155"] === true).to.true

            const rewardErc721 = await luckbox.rewards(rewardCount + 1)
            expect(rewardErc721["assetAddress"] === erc721.address).to.true
            expect(Number(rewardErc721["tokenId"]) === id).to.true
            expect(rewardErc721["is1155"] === false).to.true

            rewardCount += 2
        }

        // then deposits
        for (let id of tokenIds) {
            await luckbox.depositERC1155(
                erc1155.address,
                id,
                1
            )
            await luckbox.depositERC721(
                erc721.address,
                id
            )
        }

        // withdraw ERC-1155
        try {
            await luckbox.withdrawERC1155(erc1155.address, 1, 1)
        } catch (e) {
            expect(e.message.indexOf("Only reward owner can withdraw") !== -1).to.true
        }

        await luckbox.connect(alice).withdrawERC1155(erc1155.address, 1, 1)

        // withdraw ERC-721
        try {
            await luckbox.withdrawERC721(erc721.address, 1)
        } catch (e) {
            expect(e.message.indexOf("Only reward owner can withdraw") !== -1).to.true
        }

        await luckbox.connect(alice).withdrawERC721(erc721.address, 1)

    })

    it("Able to launch a new campaign / claim", async () => {
        // mint 10x NFT
        await erc1155.mint(admin.address, 1, 10, "0x00")
        await erc1155.setApprovalForAll(luckbox.address, true)

        await luckbox.depositERC1155(erc1155.address, 1, 10)

        // verify
        expect(await erc1155.balanceOf(luckbox.address, 1)).to.equal(10)

        await luckbox.addReward(1, erc1155.address, 1, true)

        // create an campaign 
        await luckbox.createCampaign(1, false, ethers.constants.AddressZero, [1, 1, 1, 1, 1])

        // generate merkle tree defines everyone can claims Poap 1
        const leaves = [alice, bob, charlie].map(item => ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [item.address, 1])))
        const tree = new MerkleTree(leaves, keccak256, { sortPairs: true })

        const root = tree.getHexRoot()

        // attach the root
        await luckbox.attachClaim(1, root)

        for (let user of [alice, bob, charlie]) {
            const proof = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [user.address, 1])))
            const result = await luckbox.connect(user).checkClaim(1, 1, proof)

            expect(result).to.true

            await luckbox.connect(user).claim(1, 1, proof)

            // Alice receives 1 NFT
            expect(await erc1155.balanceOf(user.address, 1)).to.equal(1)
        }

    })

})
