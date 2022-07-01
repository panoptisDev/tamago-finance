const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
const { MerkleTree } = require('merkletreejs')
const keccak256 = require("keccak256")

let erc721
let erc1155

let luckbox
let admin
let alice
let bob
let charlie
let dave
let eli
let frank
let henry
let isaac
let james
let kevin

describe("NFTLuckbox V2", () => {

    beforeEach(async () => {
        [admin, alice, bob, charlie, dave, eli, frank, henry, isaac, james, kevin] = await ethers.getSigners()

        const MockERC1155 = await ethers.getContractFactory("MockERC1155")
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        const NFTLuckboxV2 = await ethers.getContractFactory("NFTLuckboxV2");

        erc721 = await MockERC721.deploy("Mock NFT", "MOCK")
        erc1155 = await MockERC1155.deploy(
            "https://api.cryptokitties.co/kitties/{id}"
        )
        luckbox = await NFTLuckboxV2.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.HashZero)

    })

    it("campaign with a single user", async () => {
        // mint 10x NFT
        await erc1155.mint(admin.address, 1, 10, "0x00")
        await erc1155.setApprovalForAll(luckbox.address, true)

        // register the asset
        await luckbox.registerReward(1, erc1155.address, 1, true)

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

    it("campaign with 10 users", async () => {
        // mint 5x very rare NFT
        await erc1155.mint(admin.address, 1, 10, "0x00")
        // mint 5x rare NFT
        await erc1155.mint(admin.address, 2, 10, "0x00")
        await erc1155.setApprovalForAll(luckbox.address, true)

        // register the asset
        await luckbox.registerReward(1, erc1155.address, 1, true)
        await luckbox.registerReward(2, erc1155.address, 2, true)

        // create an campaign 
        await luckbox.createCampaign(1, false, ethers.constants.AddressZero, [1, 1, 1, 1, 1, 2, 2, 2, 2, 2])

        const users = [alice, bob, charlie, dave, eli, frank, henry, isaac, james, kevin]

        // generate merkle tree defines everyone can claims Poap 1
        const leaves = users.map((item , index) => ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [item.address, index < 5 ? 1 : 2])))
        const tree = new MerkleTree(leaves, keccak256, { sortPairs: true })

        const root = tree.getHexRoot()

        // attach the root
        await luckbox.attachClaim(1, root)

        for (let user of users) {

            const tokenIdToBeReceived = [alice, bob, charlie, dave, eli].includes(user) ? 1 :2

            const proof = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [user.address, tokenIdToBeReceived])))
            const result = await luckbox.connect(user).checkClaim(1, tokenIdToBeReceived, proof)

            expect(result).to.true

            await luckbox.connect(user).claim(1, tokenIdToBeReceived, proof)

            // Alice receives 1 NFT
            expect(await erc1155.balanceOf(user.address, tokenIdToBeReceived)).to.equal(1)
        }

    })

})
