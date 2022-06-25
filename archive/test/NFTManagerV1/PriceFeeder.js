// const { expect } = require("chai");
// const { fromEther, toEther } = require("./Helpers")

// let mockPriceFeeder
// let chainlinkPriceFeeder
// let quickswapTokenPriceFeeder
// let quickswapLPFeeder
// let admin
// let alice

// describe("MockPriceFeeder contract", () => {

//     before(async () => {

//         [admin, alice] = await ethers.getSigners();

//         const MockPriceFeeder = await ethers.getContractFactory("MockPriceFeeder");
//         mockPriceFeeder = await MockPriceFeeder.deploy("TEST/USD");

//     });

//     it('can update & get values', async () => {
//         // update value
//         await mockPriceFeeder.connect(admin).updateValue(toEther(0.5));

//         const value = await mockPriceFeeder.getValue();
//         expect(fromEther(value)).to.equal("0.5")

//     });

//     it('can get the timestamp', async () => {
//         expect(await mockPriceFeeder.getTimestamp()).to.not.equal("0")
//     });

// })

// describe("ChainlinkPriceFeeder contract", () => {

//     before(async () => {

//         [admin, alice] = await ethers.getSigners();

//         const ChainlinkPriceFeeder = await ethers.getContractFactory("ChainlinkPriceFeeder");
//         chainlinkPriceFeeder = await ChainlinkPriceFeeder.deploy(
//             "Bitcoin",
//             "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
//             8
//         )

//     });

//     it('retrieve current price and timestamp', async () => {
//         try {
//             const value = await chainlinkPriceFeeder.getValue()
//             expect(Number(fromEther(value)) > 100).to.true

//             const timestamp = await chainlinkPriceFeeder.getTimestamp()
//             expect(timestamp !== 0).to.true
//         }
//         catch (e) {

//         }
//     })

// })

// describe("QuickswapTokenFeeder contract", () => {

//     before(async () => {

//         [admin, alice] = await ethers.getSigners();

//         const QuickswapTokenFeeder = await ethers.getContractFactory("QuickswapTokenFeeder");
//         quickswapTokenPriceFeeder = await QuickswapTokenFeeder.deploy(
//             "TAMG/USDC",
//             "0x53BDA082677a4965C79086D3Fe69A6182d6Af1B8", // TAMG
//             18, //TAMG decimals
//             "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // USDC
//             6 // USDC decimals
//         )

//     });

//     it('retrieve current price and timestamp', async () => {
//         try {
//             const value = await quickswapTokenPriceFeeder.getValue()

//             expect(Number(fromEther(value)) > 0.1).to.true

//             const timestamp = await chainlinkPriceFeeder.getTimestamp()
//             expect(timestamp !== 0).to.true
//         }
//         catch (e) {

//         }
//     })
    
// })

// describe("QuickswapLPFeeder contract", () => {

//     before(async () => {

//         [admin, alice] = await ethers.getSigners();

//         // setup TAMG price feeder
//         const QuickswapTokenFeeder = await ethers.getContractFactory("QuickswapTokenFeeder");
//         tamgPriceFeeder = await QuickswapTokenFeeder.deploy(
//             "TAMG/USDC",
//             "0x53BDA082677a4965C79086D3Fe69A6182d6Af1B8", // TAMG
//             18, //TAMG decimals
//             "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // USDC
//             6 // USDC decimals
//         )

//         // setup USDC price feeder
//         const ChainlinkPriceFeeder = await ethers.getContractFactory("ChainlinkPriceFeeder");
//         const usdcPriceFeeder = await ChainlinkPriceFeeder.deploy(
//             "Usdc",
//             "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
//             8
//         )

//         // deploy LP feeder
//         const QuickswapLPFeeder = await ethers.getContractFactory("QuickswapLPFeeder");
//         quickswapLPFeeder = await QuickswapLPFeeder.deploy(
//             "USDC-TAMG-SHARE",
//             "0x197B24748D801419d39021bd1B76b9A609D45e5d",
//             usdcPriceFeeder.address,
//             6,
//             tamgPriceFeeder.address,
//             18
//         )

//     });

//     it('retrieve current price and timestamp', async () => {
//         try {
//             const value = await quickswapLPFeeder.getValue()
//             expect(Number(fromEther(value)) > 1000000).to.true

//             const timestamp = await chainlinkPriceFeeder.getTimestamp()
//             expect(timestamp !== 0).to.true
//         }
//         catch (e) {
            
//         }
//     })
    
// })