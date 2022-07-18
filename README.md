# Tamago Finance

> P2P Trading Protocol + Raffle-as-a-service

[![Netlify Status](https://api.netlify.com/api/v1/badges/e84d4c25-ebdb-4b18-9751-5ed453015029/deploy-status)](https://app.netlify.com/sites/helpful-meerkat-01f0e9/deploys)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub last commit](https://img.shields.io/github/last-commit/tamago-finance/tamago-finance)](https://github.com/tamago-finance/tamago-finance/commits/main)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/m/tamago-finance/tamago-finance)](https://github.com/tamago-finance/tamago-finance/commits/main)
[![GitHub contributors](https://img.shields.io/github/contributors-anon/tamago-finance/tamago-finance)](https://github.com/tamago-finance/tamago-finance/graphs/contributors)

[![Generic badge](https://img.shields.io/badge/homepage-view-red.svg)](https://tamago.finance/)
[![Generic badge](https://img.shields.io/badge/discord-join-green.svg)](https://discord.gg/78fax5dPqk)
[![Twitter Follow](https://img.shields.io/twitter/follow/tamagofinance?label=follow%20%40tamagofinance&style=social)](https://twitter.com/tamagofinance)

## Deployment

### Ethereum Mainnet

Contract Name | Contract Address 
--- | --- 
NFT Luckbox | 0x772195938d86fcf500dF18563876d7Cefcf47e4D
Marketplace | 0x260fC7251fAe677B6254773d347121862336fb9f

### BNB Chain

Contract Name | Contract Address 
--- | --- 
NFT Luckbox | 0x036e8DB382333BE877dBA1ec694fe2E5B361b607
Marketplace | 0x5Cd0BC81Fc176ea4f1e571D5279AFDee35dda618

### Polygon

Contract Name | Contract Address 
--- | --- 
NFT Luckbox | 0x978B2A0De8d1E0507032d5430CeE50E2CCA03D5b
Marketplace | 0xcf30E553633737258A0392D07A5062Ba2C79Ca9F

### Avalanche (Chain id : 43114) 

Contract Name | Contract Address 
--- | --- 
Marketplace | 0x42209A0A2a3D80Ad48B7D25fC6a61ad355901484

### Avalanche Fuji Testnet

Contract Name | Contract Address 
--- | --- 
NFT Luckbox | 0x3c4151361e9718b45409B803B6a9Ee623DBF59FE

### BNB Testnet

Contract Name | Contract Address 
--- | --- 
NFT Luckbox | 0xA657b300009802Be7c88617128545534aCA12dbe

## Marketplace Payload

A payload is basically the core element of the Tamago's P2P trading protocol defining the way to store asset information to be traded, the Merkle tree root's hash will be created upon its data and attach to the contract. 

```
{
    "category": Name of the category,
    "timestamp": Timestamp,
    "chainId": Chain ID of the base asset,
    "ownerAddress": Wallet address of the owner,
    "baseAssetAddress": Contract address of the NFT or ERC-20,
    "baseAssetTokenIdOrAmount": NFT's Token ID or ERC-20 amount,
    "baseAssetTokenType": Asset Type - 0 - ERC-20, 1 - ERC-721, 2- ERC-1155,
    "barterList": [
        {
            "assetAddress": Contract address of the NFT or ERC-20 to be traded,
            "assetTokenIdOrAmount": NFT's Token ID or ERC-20 amount to be traded,
            "tokenType": Asset Type to be traded,
            "chainId": Chain ID of the asset to be traded
        }
    ]
}
```

One of the example payload:
https://bafkreiayczhsojnlcm7ra6iok6wpwlxznwtfsfzhbrxftog4fxdgq4rkvq.ipfs.nftstorage.link/

After the entry is uploaded successfully on IPFS, the merkle tree will be contructed using the Keccak hash from 4 pieces of information `CID`, `chainId`, `assetAddress`, `assetTokenIdOrAmount`.

## License

MIT ©
