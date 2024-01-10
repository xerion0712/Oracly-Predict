# Legato

Legato is a permissionless yield tokenization protocol for liquid staking assets on Sui blockchain that enables new strategies for staking and provides additional tools for users to capitalize on market volatility. Stakers can hedge their risk by lock in today's APY rate and selling their yield in advance. Non-stakers can perform arbitrage on the APYs by trading these future yield tokens through our exchange platform.

![legato-lsd-hacks drawio](https://github.com/pisuthd/legato-finance/assets/18402217/557e9f25-4494-4dd3-ba1f-f4b07a3124a6)


The system has two types of derivative tokens created by the timelock vault. The first type is for stakers who want to lock in their yield. They must deposit liquid staking assets and will receive principal tokens, which include future yield. They can then either wait until the vault matures to redeem their deposit or sell it on the marketplace, possibly at a discount to attract other buyers.

The second type is the yield token, which allows anyone to speculate on APY volatility. Holders of yield tokens will be able to claim yield from the surplus when the APY is on the rise.

- [Live URL](https://app.legato.finance)
- [YouTube](https://youtu.be/r-t098SBnFo)

## Background

The first version aims to support Staked SUI objects, a new asset class introduced after the SIP-6 updates. When stakers stake SUI tokens with a validator, they receive Staked SUI objects as receipts. These objects can be traded and transferred to someone else but with certain restrictions. Staked SUI objects are considered semi-NFT, which means an object obtained from Pool A cannot be merged with one from Pool B.

![Untitled Diagram drawio (15)](https://github.com/pisuthd/legato-finance/assets/18402217/e5bbccb7-81ca-42ce-bd0a-726e2a5f9cbf)

As staking rewards differ among different staking pools, we cannot directly convert Staked SUI objects into fungible tokens. Therefore, we need a solution that can efficiently consolidate staking rewards from various pools into a reliable average APY across all staking pools and must have a mechanism to ensure the accuracy of APY over time.

## Principal Token

The Principal Token is the primary token serving token holders who seek to lock up their APY at today's rates. For example, if you are holding a Staked SUI object with a 4% APY, you will need to wait 1 year to receive a profit of 4%. 

Legato provides timelock vaults, each with a fixed maturity date. It can tokenize liquid staking assets along with future yield into fungible derivative tokens called PT that can be traded on any decentralized exchange and/or partially transferred to anyone.

![Untitled Diagram-Page-2 drawio (2)](https://github.com/pisuthd/legato-finance/assets/18402217/354e35fd-c784-4901-bcd7-38cc5bbefb7c)

Before the vault matures, it accumulates yield from the staking protocol or validator node to provide coverage for all distributed PT tokens. This ensures that when the vault matures, PT holders can redeem the locked assets back at a 1:1 ratio. 

In the details of the timelock vault for Staked SUI objects, there will be a shared function that anyone can call. When this function is executed, the vault will unstake all locked Staked SUI objects for SUI tokens and rewards. The rewards will be added to the reward pool and the remaining Staked SUI objects will be restaked on the validator node.

![Untitled Diagram-Page-3 drawio](https://github.com/pisuthd/legato-finance/assets/18402217/504e017b-8e00-415f-9824-a37ac4c71256)

If the APY remains fixed until the vault matures, all SUI tokens in the reward pool will cover all the future yield that has been minted as PT earlier. However, this scenario is unlikely. To sustain the reward supply with dynamic yield, we'll depend on the yield token, which will be explained in the next section.

### Marketplace

PT is a fungible token that can be traded on any exchange, including Legato's marketplace, which we have prepared with an orderbook-based system for users. Since PT represents the future value of Staked SUI, sellers may have the option to set a discount to attract potential buyers and the AMM may not be suitable for this purpose.

### Burning Process

The burning of PT tokens can be broken down into two scenarios, before and after the vault matures.

When the vault matures, PT token holders can redeem the original assets at a 1:1 ratio. However, if the vault has not matured, to exit the position, you must acquire YT tokens equivalent to the remaining future yield not yet acquired by the vault.

## Yield Token

The yield token is a support token that helps stabilize the reward pool and ensures it has sufficient assets to return to the staker. Each vault has its own set of YT tokens, and the entire supply will be minted at the time of vault generation and instantly topping up the AMM's liquidity pool.

![Untitled Diagram-Page-4 drawio (1)](https://github.com/pisuthd/legato-finance/assets/18402217/cf83dbbc-8326-4d8e-9ba6-79153f244044)

YT primarily targets individuals interested in speculating on APY. During an uptrend in APY, YT holders can claim excess yields at their convenience until the vault matures. During APY declines, LP tokens are converted into rewards to cover PT holder yields. In fact, liquidity providers profit during rising APY conditions but may face losses during downturns. 

### Marketplace

YT utilizes an AMM for instant trading of YT tokens without the need to wait for someone to create orders. The token price is determined by supply and demand.

### Burning Process

There is no burning process for YT.

## Repository structure

The project using a monorepo structure consists of 2 packages using [Lerna](https://lerna.js.org).

- `client`: the frontend application made with [React](https://react.dev/), TailwindCSS, Sui.js and Suiet's wallet-kit
- `move`: contains Move-based smart contracts

## Contract Overview

- `staked_sui.move` - A mock Staked SUI object for testing on the Testnet system.
- `vault.move` - The timelock vault, 1 mil. yield tokens (YT) will be minted and sent to the AMM object for YT circulation at the time of generation. Principal tokens (PT) will be minted when a staker deposits the Staked SUI object into the vault plus additional PT estimated to be generated until the vault matures, as per the APY stated in the Oracle contract.
- `oracle.move` - The Oracle contract, only authorized wallets can update the APY value observed from an external source and update on every epoch.
- `marketplace.move` - An Orderbook-based marketplace for trading PT.
- `amm.move` - An AMM-based marketplace for trading YT.

## Getting started

We can then run the unit tests for all Legato's smart contracts by:

```
npm run test
```

And to start the frontend application, we need to installing dependencies with:

```
npm run bootstrap
```
Then run
```
npm run package:client
```

## Deployment

### Sui Mainnet

Name | Address 
--- | --- 
Package | 0x5019da065d03c055aad8ad983d026f7e58ad33a2440d660cdbb14afdb689eeeb
Vault | 0x23e08548e58cad3a493307d283251c0094debf109d7753b5f69d73d9bc581d85

### Sui Testnet

Name | Address 
--- | --- 
Package | 0xec23537e93ef41e7f82edd49d3490d1df240b4d2aa5686b044c241e0b4b6a29b
Vault | 0xb7a8786558e1b8a305a07c8d8a0c4fc3fd28c158f953b1b7b7b03edc6294bba7

## Roadmap

- [x] Stake SUI to receive Staked SUI objects from validators
- [x] Browse Staked SUI objects and unstake
- [x] On-chain staking APY fetcher
- [x] Basic Timelock Vault
- [x] Marketplace for trading PT, YT
- [x] Claim yield from the surplus
