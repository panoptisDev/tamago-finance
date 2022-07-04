require("dotenv").config()

require("@openzeppelin/hardhat-upgrades")
require("hardhat-deploy")
require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("solidity-coverage")

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  mocha: {
    timeout: 1200000,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true
    },
    mainnet: {
      allowUnlimitedContractSize: true,
      url: process.env.MAINNET_URL,
      accounts: [process.env.PRIVATEKEY_DEPLOYER, process.env.PRIVATEKEY_DEV],
    },
    polygon: {
      allowUnlimitedContractSize: true,
      url: process.env.POLYGON_URL,
      accounts: [process.env.PRIVATEKEY_DEPLOYER, process.env.PRIVATEKEY_DEV],
    },
    harmony: {
      allowUnlimitedContractSize: true,
      url: "https://rpc.s1.t.hmny.io",
      accounts: [process.env.PRIVATEKEY_DEPLOYER, process.env.PRIVATEKEY_DEV],
    },
    bsc: {
      allowUnlimitedContractSize: true,
      url: "https://rpc.ankr.com/bsc",
      accounts: [process.env.PRIVATEKEY_DEPLOYER, process.env.PRIVATEKEY_DEV],
    },
    bscTestnet: {
      allowUnlimitedContractSize: true,
      url: "https://data-seed-prebsc-2-s2.binance.org:8545/",
      accounts: [process.env.PRIVATEKEY_DEPLOYER, process.env.PRIVATEKEY_DEV],
    },
    mainnetfork: {
      url: "http://127.0.0.1:8545",
      accounts: [process.env.PRIVATEKEY_DEPLOYER, process.env.PRIVATEKEY_DEV],
      timeout: 500000,
    },
    kovan: {
      allowUnlimitedContractSize: true,
      url: "https://speedy-nodes-nyc.moralis.io/2041771c8a1a3004b1608ea7/eth/kovan",
      accounts: [process.env.PRIVATEKEY_DEPLOYER, process.env.PRIVATEKEY_DEV],
      timeout: 500000,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    dev: {
      default: 1,
    },
  },
  etherscan: {
    apiKey: process.env.MAINNET_API_KEY,
  },
}
