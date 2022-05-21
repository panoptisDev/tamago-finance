const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
const { MerkleTree } = require('merkletreejs')
const keccak256 = require("keccak256")
const { toUsdc, fromUsdc } = require("./Helpers")

let marketplace
let erc1155
let erc721
let mockUsdc

let admin
let alice
let bob
let charlie
let dev

describe("NFT Marketplace", () => {

    beforeEach(async () => {
        [admin, alice, bob, charlie, dev] = await ethers.getSigners()

        const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace")
        const Registry = await ethers.getContractFactory("Registry");
        const MockERC1155 = await ethers.getContractFactory("MockERC1155")
        const MockERC721 = await ethers.getContractFactory("MockERC721")
        const MockERC20 = await ethers.getContractFactory("MockERC20")

        registry = await Registry.deploy()

        erc1155 = await MockERC1155.deploy(
            "https://api.cryptokitties.co/kitties/{id}"
        )
        erc721 = await MockERC721.deploy("Mock NFT", "MOCK")
        mockUsdc = await MockERC20.deploy("Mock USDC", "USDC", 6)

        marketplace = await NFTMarketplace.deploy(dev.address)

    })

    it("basic create an order and cancel it", async () => {
        
        // mint ERC-1155
        await erc1155.mint(admin.address, 1, 1, "0x00")
        // mint ERC-721
        await erc721.mint(admin.address, 1)

        await erc1155.setApprovalForAll(marketplace.address, true)
        await erc721.setApprovalForAll(marketplace.address, true)

        // create orders
        await marketplace.createOrder(1, erc1155.address, 1, true, ethers.utils.formatBytes32String("") , false)
        await marketplace.createOrder(2, erc721.address, 1, false, ethers.utils.formatBytes32String("") , false)

        expect( await erc1155.balanceOf(admin.address , 1)).to.equal(0)
        expect( await erc721.balanceOf(admin.address)).to.equal(0)

        try {
            await marketplace.connect(alice).cancelOrder(1)
        } catch (e) {
            expect(e.message.indexOf("You are not the owner") !== -1).to.true
        }

        // cancel orders
        await marketplace.connect(admin).cancelOrder(1)
        await marketplace.connect(admin).cancelOrder(2)

        expect( await erc1155.balanceOf(admin.address , 1)).to.equal(1)
        expect( await erc721.balanceOf(admin.address)).to.equal(1)
    })

    it("able to create an order and fulfill it", async () => {
        
        // mint ERC-1155
        await erc1155.mint(alice.address, 1, 1, "0x00")
        await erc1155.mint(bob.address, 2, 1, "0x00")
        // mint ERC-721
        await erc721.mint(alice.address, 1)
        await erc721.mint(bob.address, 2)

        // make approvals
        await erc1155.connect(alice).setApprovalForAll(marketplace.address, true)
        await erc721.connect(alice).setApprovalForAll(marketplace.address, true)
        await erc1155.connect(bob).setApprovalForAll(marketplace.address, true)
        await erc721.connect(bob).setApprovalForAll(marketplace.address, true)

        // Alice accepts NFT ID 2 from both ERC721 & ERC1155 contracts
        const leaves = [erc1155, erc721].map(item => ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [item.address, 2])))
        const tree = new MerkleTree(leaves, keccak256, { sortPairs: true })

        const hexRoot = tree.getHexRoot()

        await marketplace.connect(alice).createOrder(1, erc1155.address, 1, true, hexRoot , false )
        await marketplace.connect(alice).createOrder(2, erc721.address, 1, false, hexRoot , false ) 
        
        // verify
        const firstOrder = await marketplace.orders(1)
        expect( firstOrder['assetAddress'] ).to.equal(erc1155.address)
        expect( firstOrder['tokenId'].toString() ).to.equal("1")
        expect( firstOrder['is1155'] ).to.equal(true)
        expect( firstOrder['owner'] ).to.equal(alice.address)

        const secondOrder = await marketplace.orders(2)
        expect( secondOrder['assetAddress'] ).to.equal(erc721.address)
        expect( secondOrder['tokenId'].toString() ).to.equal("1")
        expect( secondOrder['is1155'] ).to.equal(false)
        expect( secondOrder['owner'] ).to.equal(alice.address)

        // check whether Bob can swaps
        const proof1 = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [erc1155.address, 2])))

        expect( await marketplace.connect(bob).eligibleToSwap(
            1,
            erc1155.address,
            2,
            proof1
        ) ).to.true

        const proof2 = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [erc721.address, 2])))

        expect( await marketplace.connect(bob).eligibleToSwap(
            2,
            erc721.address,
            2,
            proof2
        ) ).to.true

        // swap
        // Token 2 -> Token 1
        await marketplace.connect(bob).swap( 1, erc1155.address, 2, 2, proof1)
        await marketplace.connect(bob).swap( 2, erc721.address, 2, 1, proof2)

        // Alice should receives Token 2
        expect( await erc1155.balanceOf(alice.address , 2)).to.equal(1)
        expect( await erc721.ownerOf(2)).to.equal(alice.address)
        // Bob should receives Token 1
        expect( await erc1155.balanceOf(bob.address , 1)).to.equal(1)
        expect( await erc721.ownerOf(1)).to.equal(bob.address)
        
    })

    it("able to sell the NFT and accept with ERC-20", async () => {
        // mint ERC-721 for Alice
        await erc721.mint(alice.address, 1)
        // Prepare ERC-20 for Bob
        await mockUsdc.connect(bob).faucet()
        // Set Swap fees to 0%
        await marketplace.setSwapFee(0)

        // make approvals
        await erc721.connect(alice).setApprovalForAll(marketplace.address, true)
        await mockUsdc.connect(bob).approve(marketplace.address , ethers.constants.MaxUint256)

        const leaves = [ ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [mockUsdc.address, toUsdc( 200 )])) ]
        const tree = new MerkleTree(leaves, keccak256, { sortPairs: true })

        const root = tree.getHexRoot()

        // create an order and deposit ERC721 NFT
        await marketplace.connect(alice).createOrder(1, erc721.address, 1, false, root , false )

        const proof = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [mockUsdc.address, toUsdc( 200 )])))

        expect( await marketplace.connect(bob).eligibleToSwap(
            1,
            mockUsdc.address,
            toUsdc( 200 ),
            proof
        ) ).to.true

        const before = await mockUsdc.balanceOf(bob.address)

        // swap 200 USDC with 1 NFT
        await marketplace.connect(bob).swap( 1, mockUsdc.address, toUsdc( 200 ), 0, proof)

        const after = await mockUsdc.balanceOf(bob.address)
        
        expect( Number(fromUsdc(before)) - Number(fromUsdc(after))).to.equal(200)

        // validate the result
        expect( await erc721.ownerOf(1)).to.equal(bob.address)
        expect( await mockUsdc.balanceOf(alice.address)).to.equal( toUsdc(200 ))
    })

    // TODO : Batch Orders

})