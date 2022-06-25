const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
const { MerkleTree } = require('merkletreejs')
const keccak256 = require("keccak256")

let luckBox
let erc1155

let admin
let alice
let bob
let charlie
let dave

describe("LuckBox V2", () => {

  beforeEach(async () => {
    [admin, alice, bob, charlie, dave] = await ethers.getSigners()

    const LuckBox = await ethers.getContractFactory("LuckBox")
    const MockERC1155 = await ethers.getContractFactory("MockERC1155")

    luckBox = await LuckBox.deploy()
    erc1155 = await MockERC1155.deploy(
      "https://api.cryptokitties.co/kitties/{id}"
    )
  })

  it("Check whitelist users for project (1)", async () => {

    // generate merkle tree of whitelist users (without Dave)
    const leaves = [admin, alice, bob, charlie].map(item => keccak256(item.address))
    const treeWL = new MerkleTree(leaves, keccak256, { sortPairs: true })
    // create a project
    await luckBox.createProject(1, "TEST")
    // attach WL's root
    const rootWL = treeWL.getHexRoot()
    root = treeWL.getRoot().toString('hex');
    await luckBox.attachWhitelist(1, rootWL)

    for (let user of [admin, alice, bob, charlie, dave]) {

      const proof = treeWL.getHexProof(keccak256(user.address))
      const valid = await luckBox.eligible(1, user.address, proof)

      if (user !== dave) {
        expect(valid).to.true
      } else {
        expect(valid).to.false
      }

    }

  })

  it("Setup a new event and let's Alice claims a POAP", async () => {

    // Mint 3 NFT, 2x each
    const tokenIds = [1, 2, 3]

    for (let id of tokenIds) {
      await erc1155.mint(admin.address, id, 2, "0x00")
      // also create a record
      await luckBox.createPoap(id, erc1155.address, id, true)
    }

    await erc1155.setApprovalForAll(luckBox.address, true)

    // deposit them to Luckbox
    for (let id of tokenIds) {
      await luckBox.depositERC1155(erc1155.address, id, 2)

      expect(await erc1155.balanceOf(luckBox.address, id)).to.equal(2)
    }

    // create an event with POAP ID 1,2,3
    await luckBox.createEvent(1, "EVENT", [1, 2, 3])

    // generate merkle tree defines everyone can claims Poap 2
    const leaves = [admin, alice, bob, charlie].map(item => ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [item.address, 2])))
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true })

    const hexRoot = tree.getHexRoot()

    // attach the root 
    await luckBox.attachClaim(1, hexRoot)

    const proof = tree.getHexProof(ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [alice.address, 2])))
    const result = await luckBox.connect(alice).checkClaim(1, 2, proof)

    expect(result).to.true

    await luckBox.connect(alice).claim(1, 2, proof)

    // Alice receives 1 NFT
    expect(await erc1155.balanceOf(alice.address, 2)).to.equal(1)

  })

})

