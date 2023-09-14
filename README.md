# Legato Finance

Legato is a permissionless yield tokenization protocol for liquid staking assets on Sui blockchain that enables new strategies for staking and provides additional tools for users to capitalize on market volatility. Stakers can hedge their risk by selling their yield in advance and lock in today's APR rate. Non-stakers can perform arbitrage on the APYs by trading these future yield tokens through our exchange platform.

The system has two types of derivative tokens created by the timelock vault. The first type is for stakers who want to lock in their yield. They must deposit liquid staking assets and will receive principal tokens, which include future yield. They can then either wait until the vault matures to redeem their deposit or sell it on the marketplace, possibly at a discount to attract other buyers.

The second type is the yield token, which allows anyone to speculate on APR volatility. Holders of yield tokens will be able to claim yield from surplus collateral when the APR is on the rise.





- [Live URL](https://legato.finance)
- [YouTube](https://youtu.be/INN8mz4Qzws)
- [Akindo](https://app.akindo.io/communities/xKao6wZaqu6XPWv6/products/d8RoedOEZtVDx7N2)

## Repository structure

The project using a monorepo structure consists of 2 packages using [Lerna](https://lerna.js.org).

- `client`: the frontend application made with [React](https://react.dev/), TailwindCSS, Sui.js and Suiet's wallet-kit
- `move`: contains Move-based smart contracts

## Contract Overview

- `staked_sui.move` - A mock Staked SUI object for testing on the Testnet system.
- `vault.move` - The timelock vault, 1 mil. yield tokens will be minted and sent to the sender (and later to the AMM contract directly) for YT circulation at the time of generation. Principal tokens (PT) will be minted when a staker deposits the Staked SUI object into the vault plus additional PT estimated to be generated until the vault matures, as per the APR stated in the Oracle contract.
- `oracle.move` - The Oracle contract, only authorized wallets can update the APR value observed from an external source and update on every epoch.
- `marketplace.move` - An Orderbook-based marketplace for trading PT.
- `amm.move` (WIP) - An AMM-based marketplace for trading YT.

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

### Sui Testnet

Name | Address 
--- | --- 
Package | 0x89b77424c9514f64537f83ae5e260286ee08f03bbc723cf1cc15c601cea9fb8d
Mock StakedSui | 0x8ae56684e4541aa5d920f3e08ceedb5927797818e420474e1b7a3b6ef28730a0
Vault | 0xd39bf3fbf39249bb06e701099ae3647d9d17564de26f0a01c07b9b34559098fc
Marketplace | 0x0e572306b58cfdc1d70a88aa9eeaa28559b43083d87d8813f06999a100ebe66e

## Roadmap

- [x] One-way Deposit Timelock Vault
- [x] Support for PT Trading
- [x] Landing Page
- [x] Oracle Contract
- [ ] PT & YT Merging & Splitting
- [ ] Deposit and Withdraw on Timelock Vault
- [ ] AMM & Support for YT Trading
