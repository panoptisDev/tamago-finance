// const { expect } = require("chai");
// const { fromEther, toEther } = require("./Helpers")

// let priceResolver
// let admin
// let alice
// let feederBtc
// let feederEth
// let feederUsdc

// describe("PriceResolver contract", () => {

//     before(async () => {

//         [admin, alice] = await ethers.getSigners();

//         const PriceResolver = await ethers.getContractFactory("PriceResolver");
//         priceResolver = await PriceResolver.deploy(admin.address);

//         const MockPriceFeeder = await ethers.getContractFactory("MockPriceFeeder");
//         feederBtc = await MockPriceFeeder.deploy("BTC/USD");
//         feederEth = await MockPriceFeeder.deploy("ETH/USD");
//         feederUsdc = await MockPriceFeeder.deploy("USDC/USD");

//         // set mock values
//         await feederBtc.updateValue(toEther(40000));
//         await feederEth.updateValue(toEther(4000));
//         await feederUsdc.updateValue(toEther(1));

//     });

//     it('register 3 mock feeders', async () => {

//         // register BTC/USD feed
//         await priceResolver.registerPriceFeeder(
//             ethers.utils.formatBytes32String("BTC/USD"),
//             feederBtc.address,
//             false,
//             toEther(39000)
//         )
//         // register ETH/USD feed
//         await priceResolver.registerPriceFeeder(
//             ethers.utils.formatBytes32String("ETH/USD"),
//             feederEth.address,
//             false,
//             toEther(3900)
//         )

//         // register USDC/USD feed
//         await priceResolver.registerPriceFeeder(
//             ethers.utils.formatBytes32String("USDC/USD"),
//             feederUsdc.address,
//             false,
//             toEther(0.9)
//         )

//         expect(await priceResolver.priceFeederCount()).to.equal(3)

//     });

//     it('should have correct values', async () => {

//         expect(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("BTC/USD"))).to.equal(toEther(40000))
//         expect(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("ETH/USD"))).to.equal(toEther(4000))
//         expect(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("USDC/USD"))).to.equal(toEther(1))

//     });

//     it('invert is functional', async () => {
        
//         await priceResolver.setPriceFeederInvertFlag(ethers.utils.formatBytes32String("BTC/USD"), true);
//         await priceResolver.setPriceFeederInvertFlag(ethers.utils.formatBytes32String("ETH/USD"), true);
//         await priceResolver.setPriceFeederInvertFlag(ethers.utils.formatBytes32String("USDC/USD"), true);

//         expect( fromEther(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("BTC/USD"))) ).to.equal("0.000025")
//         expect( fromEther(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("ETH/USD"))) ).to.equal("0.00025")
//         expect( fromEther(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("USDC/USD"))) ).to.equal("1.0")

//         await priceResolver.setPriceFeederInvertFlag(ethers.utils.formatBytes32String("BTC/USD"), false);
//         await priceResolver.setPriceFeederInvertFlag(ethers.utils.formatBytes32String("ETH/USD"), false);
//         await priceResolver.setPriceFeederInvertFlag(ethers.utils.formatBytes32String("USDC/USD"), false);
//     })

//     it('check fallback values', async () => {

//         await priceResolver.setPriceFeederDisable(ethers.utils.formatBytes32String("BTC/USD"), true);
//         await priceResolver.setPriceFeederDisable(ethers.utils.formatBytes32String("ETH/USD"), true);
//         await priceResolver.setPriceFeederDisable(ethers.utils.formatBytes32String("USDC/USD"), true);

//         expect(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("BTC/USD"))).to.equal(toEther(39000))
//         expect(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("ETH/USD"))).to.equal(toEther(3900))
//         expect(await priceResolver.getCurrentPrice(ethers.utils.formatBytes32String("USDC/USD"))).to.equal(toEther(0.9))

//     });

    

// })