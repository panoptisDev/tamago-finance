const { expect } = require("chai");

let admin
let alice

let registry

describe("Registry contract", () => {

    const SAMPLE_NAME = "TEST"
    const SAMPLE_ADDRESS_1 = "0xa57bd00134b2850b2a1c55860c9e9ea100fdd6cf"
    const SAMPLE_ADDRESS_2 = "0xed178a629221760f90730447b465432199a62189"

    beforeEach(async () => {

        [admin, alice] = await ethers.getSigners();

        const Registry = await ethers.getContractFactory("Registry");
        registry = await Registry.deploy()

    });


    it('register contracts', async () => {

        await registry.connect(admin).registerContract(ethers.utils.formatBytes32String(SAMPLE_NAME), SAMPLE_ADDRESS_1)
        expect(await registry.connect(admin).getContractAddress(ethers.utils.formatBytes32String(SAMPLE_NAME)), SAMPLE_ADDRESS_1)

        // update with the new address
        await registry.connect(admin).updateContract(ethers.utils.formatBytes32String(SAMPLE_NAME), SAMPLE_ADDRESS_2)
        expect(await registry.connect(admin).getContractAddress(ethers.utils.formatBytes32String(SAMPLE_NAME)), SAMPLE_ADDRESS_2)

    })

    it('register contracts from non-admin', async () => {

        try {
            await registry.connect(alice).registerContract(ethers.utils.formatBytes32String(SAMPLE_NAME), SAMPLE_ADDRESS_1)
        } catch (e) {
            expect(e.message.indexOf("caller is not the owner") !== -1).to.true
        }

    })

    it('deploy a synthetic NFT', async () => {

        await registry.connect(admin).deploySyntheticNFT(ethers.utils.formatBytes32String("SYNTHETIC_NFT"), "TEST", "https://api.cryptokitties.co/kitties/{id}")

        const output = await registry.getContractAddress(ethers.utils.formatBytes32String("SYNTHETIC_NFT"))

        expect(output).to.not.equal(ethers.constants.AddressZero)
    })

})