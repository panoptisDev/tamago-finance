const { ethers } = require("ethers")

exports.fromEther = (value) => {
    return ethers.utils.formatEther(value)
}

exports.fromUsdc = (value) => {
    return ethers.utils.formatUnits(value, 6)
}

exports.toEther = (value) => {
    return ethers.utils.parseEther(`${value}`)
}

exports.toUsdc = (value) => {
    return ethers.utils.parseUnits(`${value}`, 6)
}

exports.deployPriceResolverMock = async ({ PriceResolver, MockPriceFeeder, admin }) => {

    const priceResolver = await PriceResolver.deploy(admin.address);

    const feederUsdc = await MockPriceFeeder.deploy("USDC/USD");
    const feederTamg = await MockPriceFeeder.deploy("TAMG/USD");
    const feederWmatic = await MockPriceFeeder.deploy("WMATIC/USD")
    const feederUsd = await MockPriceFeeder.deploy("USD");
    const feederUsdcTamgShare = await MockPriceFeeder.deploy("USDC-TAMG-SHARE/USD");
    const feederWmaticUsdcShare = await MockPriceFeeder.deploy("WMATIC-USDC-SHARE/USD");

    // update values
    await feederUsdc.updateValue(this.toEther(0.9998));
    await feederTamg.updateValue(this.toEther(0.4));
    await feederUsd.updateValue(this.toEther(1));
    await feederWmatic.updateValue(this.toEther(2.0))
    await feederUsdcTamgShare.updateValue(this.toEther(1380000))
    await feederWmaticUsdcShare.updateValue(this.toEther(2000000))

    // register them all
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDC/USD"),
        feederUsdc.address,
        false,
        this.toEther(0.9998)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("TAMG/USD"),
        feederTamg.address,
        false,
        this.toEther(0.4)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USD"),
        feederUsd.address,
        false,
        this.toEther(1)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDC-TAMG-SHARE"),
        feederUsdcTamgShare.address,
        false,
        this.toEther(1380000)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WMATIC/USD"),
        feederWmatic.address,
        false,
        this.toEther(2.0)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WMATIC-USDC-SHARE"),
        feederWmaticUsdcShare.address,
        false,
        this.toEther(2000000)
    )

    return priceResolver
}

exports.deployPriceResolver = async ({
    PriceResolver,
    MockPriceFeeder,
    ChainlinkPriceFeeder,
    QuickswapTokenFeeder,
    QuickswapLPFeeder,
    TamgToken,
    Admin
}) => {

    const priceResolver = await PriceResolver.deploy(Admin.address);

    const feederUsdc = await ChainlinkPriceFeeder.deploy(
        "USDC/USD",
        "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
        8
    );
    const feederTamg = await QuickswapTokenFeeder.deploy(
        "TAMG/USDC",
        "0x53BDA082677a4965C79086D3Fe69A6182d6Af1B8", // TAMG
        18, //TAMG decimals
        "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // USDC
        6 // USDC decimals
    );

    const feederWmatic = await ChainlinkPriceFeeder.deploy(
        "WMATIC/USD",
        "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
        8
    )

    const feederUsd = await MockPriceFeeder.deploy("USD");
    const feederUsdcTamgShare = await QuickswapLPFeeder.deploy(
        "USDC-TAMG-SHARE",
        "0x197B24748D801419d39021bd1B76b9A609D45e5d",
        feederUsdc.address,
        6,
        feederTamg.address,
        18
    );

    const feederWmaticUsdcShare = await QuickswapLPFeeder.deploy(
        "WMATIC-USDC-SHARE",
        "0x6e7a5fafcec6bb1e78bae2a1f0b612012bf14827",
        feederWmatic.address,
        18,
        feederUsdc.address,
        6
    );

    await feederUsd.updateValue(this.toEther(1));

    // register them all
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDC/USD"),
        feederUsdc.address,
        false,
        this.toEther(0.9998)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("TAMG/USDC"),
        feederTamg.address,
        false,
        this.toEther(0.4)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USD"),
        feederUsd.address,
        false,
        this.toEther(1)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDC-TAMG-SHARE"),
        feederUsdcTamgShare.address,
        false,
        this.toEther(1380000)
    )

    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WMATIC/USD"),
        feederWmatic.address,
        false,
        this.toEther(1.5)
    )

    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WMATIC-USDC-SHARE"),
        feederWmaticUsdcShare.address,
        false,
        this.toEther(4706278)
    )

    return priceResolver
}

exports.deployPriceResolver2 = async ({
    PriceResolver,
    MockPriceFeeder,
    ChainlinkPriceFeeder,
    QuickswapTokenFeeder,
    QuickswapLPFeeder,
    Admin,
    LpWmaticUsdcAddress
}) => {

    const priceResolver = await PriceResolver.deploy(Admin.address);

    const feederUsdc = await ChainlinkPriceFeeder.deploy(
        "USDC/USD",
        "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
        8
    );

    const feederWmatic = await ChainlinkPriceFeeder.deploy(
        "WMATIC/USD",
        "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
        8
    )

    const feederUsd = await MockPriceFeeder.deploy("USD");

    const feederWmaticUsdcShare = await QuickswapLPFeeder.deploy(
        "WMATIC-USDC-SHARE",
        LpWmaticUsdcAddress,
        feederWmatic.address,
        18,
        feederUsdc.address, // Mock
        18
    );

    await feederUsd.updateValue(this.toEther(1));

    // register them all
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDC/USD"),
        feederUsdc.address,
        false,
        this.toEther(0.9998)
    )

    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USD"),
        feederUsd.address,
        false,
        this.toEther(1)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WMATIC/USD"),
        feederWmatic.address,
        false,
        this.toEther(2)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WMATIC-USDC-SHARE"),
        feederWmaticUsdcShare.address,
        false,
        this.toEther(4706278)
    )

    return priceResolver
}

exports.deployPriceResolverMainnet = async ({
    PriceResolver,
    MockPriceFeeder,
    ChainlinkPriceFeeder,
    QuickswapTokenFeeder,
    QuickswapLPFeeder,
    Admin,
    lpWEthUsdcAddress
}) => {

    const priceResolver = await PriceResolver.deploy(Admin.address);

    const feederUsdc = await ChainlinkPriceFeeder.deploy(
        "USDC/USD",
        "0x8fffffd4afb6115b954bd326cbe7b4ba576818f6",
        8
    );

    const feederWEth = await ChainlinkPriceFeeder.deploy(
        "WETH/USD",
        "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419",
        8
    )

    const feederUsd = await MockPriceFeeder.deploy("USD");

    const feederWEthUsdcShare = await QuickswapLPFeeder.deploy(
        "WETH-USDC-SHARE",
        lpWEthUsdcAddress,
        feederWEth.address,
        18,
        feederUsdc.address, // Mock
        18
    );

    await feederUsd.updateValue(this.toEther(1));

    // register them all
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDC/USD"),
        feederUsdc.address,
        false,
        this.toEther(0.9998)
    )

    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USD"),
        feederUsd.address,
        false,
        this.toEther(1)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WETH/USD"),
        feederWEth.address,
        false,
        this.toEther(2)
    )
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("WETH-USDC-SHARE"),
        feederWEthUsdcShare.address,
        false,
        this.toEther(168814574)
    )

    return priceResolver
}

exports.deployPriceResolverV2 = async ({
    library,
    admin
}) => {

    const { chainId, name } = (await library.provider.getNetwork())
    const PriceResolver = await library.getContractFactory("PriceResolver");
    const ChainlinkPriceFeeder = await library.getContractFactory("ChainlinkPriceFeeder")
    const MockPriceFeeder = await library.getContractFactory("MockPriceFeeder")

    const priceResolver = await PriceResolver.deploy(admin);
    let feederUsdc
    let feederUsdt
    let feederDai

    switch (chainId) {
        case 1:
            feederUsdc = await ChainlinkPriceFeeder.deploy(
                "USDC/USD",
                "0x8fffffd4afb6115b954bd326cbe7b4ba576818f6",
                8
            );
            break
        case 137:
            feederUsdc = await ChainlinkPriceFeeder.deploy(
                "USDC/USD",
                "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
                8
            );
            break
        default:
            feederUsdc = await MockPriceFeeder.deploy("USDC/USD");
            await feederUsdc.updateValue(this.toEther(0.9998));
            
            feederUsdt = await MockPriceFeeder.deploy("USDT/USD");
            await feederUsdc.updateValue(this.toEther(0.9999));

            feederDai = await MockPriceFeeder.deploy("DAI/USD");
            await feederDai.updateValue(this.toEther(0.9995));
    }

    const feederUsd = await MockPriceFeeder.deploy("USD")
    await feederUsd.updateValue(this.toEther(1));

    // register 
    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDC/USD"),
        feederUsdc.address,
        false,
        this.toEther(0.9998) // fallback value
    )

    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USDT/USD"),
        feederUsdt.address,
        false,
        this.toEther(0.9999) // fallback value
    )

    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("DAI/USD"),
        feederDai.address,
        false,
        this.toEther(0.9995) // fallback value
    )

    await priceResolver.registerPriceFeeder(
        ethers.utils.formatBytes32String("USD"),
        feederUsd.address,
        false,
        this.toEther(1)  // fallback value
    )

    return priceResolver
}