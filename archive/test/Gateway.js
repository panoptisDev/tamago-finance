const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
const { MerkleTree } = require('merkletreejs')
const keccak256 = require("keccak256")
const { toUsdc } = require("./Helpers")

let gatewayChainOne
let gatewayChainTwo

let admin
let alice
let bob
let validator
let relayer

let erc1155
let erc721
let mockUsdc

describe("Cross-chain NFT swaps via Gateway contract", () => {

    beforeEach(async () => {
        [admin, alice, bob, validator, relayer] = await ethers.getSigners()

        const Gateway = await ethers.getContractFactory("Gateway")
        const MockERC1155 = await ethers.getContractFactory("MockERC1155")
        const MockERC721 = await ethers.getContractFactory("MockERC721")
        const MockERC20 = await ethers.getContractFactory("MockERC20")

        erc1155 = await MockERC1155.deploy(
            "https://api.cryptokitties.co/kitties/{id}"
        )
        erc721 = await MockERC721.deploy("Mock NFT", "MOCK")
        mockUsdc = await MockERC20.deploy("Mock USDC", "USDC", 6)

        gatewayChainOne = await Gateway.deploy(admin.address)
        gatewayChainTwo = await Gateway.deploy(admin.address)

        await gatewayChainOne.setChainId(1)
        await gatewayChainTwo.setChainId(2)

        await gatewayChainOne.grant(validator.address, 3)
        await gatewayChainTwo.grant(validator.address, 3)
        await gatewayChainTwo.grant(relayer.address, 2)

    })

    it("create crosschain's order and cancel it", async () => {

        // mint ERC-721 to Alice
        await erc721.connect(alice).mint(alice.address, 1)
        await erc721.connect(alice).setApprovalForAll(gatewayChainOne.address, true)

        await gatewayChainOne.connect(alice).createOrder(1, erc721.address, 1, false, ethers.utils.formatBytes32String(""), true)

        expect(await erc721.balanceOf(alice.address)).to.equal(0)
        expect(await erc721.balanceOf(gatewayChainOne.address)).to.equal(1)

        // non-admin can't cancel the order
        try {
            await gatewayChainOne.connect(alice).cancelOrder(1)
        } catch (e) {
            expect(e.message.indexOf("Only admin is allows to cancel a crosschain's order") !== -1).to.true
        }

        // non-admin can't call cancelCrosschainOrder()
        try {
            await gatewayChainOne.connect(alice).cancelCrosschainOrder(1, alice.address)
        } catch (e) {
            expect(e.message.indexOf("Caller is not the admin") !== -1).to.true
        }

        await gatewayChainOne.connect(admin).cancelCrosschainOrder(1, alice.address)

    })

    it("able to swaps NFT from chain#1 to chain#2", async () => {
        // mint ERC-721
        await erc721.mint(alice.address, 1)
        await erc721.mint(bob.address, 2)

        await erc721.connect(alice).setApprovalForAll(gatewayChainOne.address, true)
        await erc721.connect(bob).setApprovalForAll(gatewayChainTwo.address, true)

        expect(await gatewayChainOne.chainId()).to.equal(1)
        expect(await gatewayChainTwo.chainId()).to.equal(2)

        // Alice accepts NFT ID 2 from another chain
        let leaves = [erc721].map(item => ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [item.address, 2])))
        let tree = new MerkleTree(leaves, keccak256, { sortPairs: true })

        let hexRoot = tree.getHexRoot()

        await gatewayChainOne.connect(alice).createOrder(1, erc721.address, 1, false, hexRoot, true)

        const fakeProof = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [erc721.address, 2])))

        // can't swaps on the same chain
        try {
            await gatewayChainOne.connect(bob).eligibleToSwap(
                1,
                erc721.address,
                2,
                fakeProof
            )
        } catch (e) {
            expect(e.message.indexOf("Your order can be fulfilled by gateway contract only") !== -1).to.true
        }

        // relayer post a message to chain#2
        leaves = [erc721].map(item => ethers.utils.keccak256(ethers.utils.solidityPack([ "uint256", "uint256", "address" , "uint256"], [ 1, 2, item.address , 2])))
        tree = new MerkleTree(leaves, keccak256, { sortPairs: true })
        hexRoot = tree.getHexRoot()

        await gatewayChainTwo.connect(relayer).attachRelayMessage(hexRoot)
        // generate a proof for the message
        const proof = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack([ "uint256" , "uint256", "address" , "uint256"], [1 , 2,  erc721.address, 2])))
       
        expect( await gatewayChainTwo.connect(bob).eligibleToPartialSwap(1, erc721.address, 2, proof) ).to.true

        // deposit NFt on the destination chain
        await gatewayChainTwo.connect(bob).partialSwap( 1, erc721.address, 2, 1, proof )

        // validate the result
        const partialOrderData = await gatewayChainTwo.outstandings(1)
        expect( partialOrderData['active']).to.true
        expect( partialOrderData['ended']).to.false
        expect( partialOrderData['buyer']).to.equal(bob.address)
        expect( partialOrderData['assetAddress']).to.equal(erc721.address)
        expect( partialOrderData['tokenIdOrAmount']).to.equal(2)
        expect( partialOrderData['tokenType']).to.equal(1)

        // validator prepare the claimable data
        leaves = [1, 2].map(item => ethers.utils.keccak256(ethers.utils.solidityPack([ "uint256", "uint256", "address" , "bool"], [ 1, item, item === 1 ? bob.address : alice.address , item === 1 ? true : false])))
        tree = new MerkleTree(leaves, keccak256, { sortPairs: true })
        hexRoot = tree.getHexRoot()

        await gatewayChainOne.connect(validator).attachClearanceMessage(hexRoot)
        await gatewayChainTwo.connect(validator).attachClearanceMessage(hexRoot)

        // Bob claims NFT from Chain#1 and close the order
        const proofBob = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack([ "uint256", "uint256", "address" , "bool" ], [1 , 1,  bob.address, true])))
        expect( await gatewayChainOne.connect(bob).eligibleToClaim(1, bob.address, true, proofBob) ).to.true
        await gatewayChainOne.connect(bob).claim(1, true, proofBob)

        // Then Alice claims NFT from Chain#2 and close the order
        const proofAlice = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack([ "uint256", "uint256", "address" , "bool" ], [1 , 2,  alice.address, false])))
        expect( await gatewayChainTwo.connect(alice).eligibleToClaim(1, alice.address, false, proofAlice) ).to.true
        await gatewayChainTwo.connect(alice).claim(1, false, proofAlice)

        // Verify the result
        expect(await erc721.ownerOf(1)).to.equal(bob.address)
        expect(await erc721.ownerOf(2)).to.equal(alice.address)

        const finalDataChainOne = await gatewayChainOne.orders(1)
        const finalDataChainTwo = await gatewayChainTwo.outstandings(1)

        expect( finalDataChainOne['ended']).to.true
        expect( finalDataChainTwo['ended']).to.true

    })

})
