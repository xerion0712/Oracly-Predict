# Legato Finance

Legato is a permissionless yield tokenization protocol for liquid staking assets on Sui blockchain that enables new strategies for staking and provides additional tools for users to capitalize on market volatility. Stakers can hedge their risk by selling their yield in advance and lock in today's APR rate. Non-stakers can perform arbitrage on the APYs by trading these future yield tokens through our exchange platform.

![legato-lsd-hacks drawio](https://github.com/pisuthd/legato-finance/assets/18402217/557e9f25-4494-4dd3-ba1f-f4b07a3124a6)


The system has two types of derivative tokens created by the timelock vault. The first type is for stakers who want to lock in their yield. They must deposit liquid staking assets and will receive principal tokens, which include future yield. They can then either wait until the vault matures to redeem their deposit or sell it on the marketplace, possibly at a discount to attract other buyers.

The second type is the yield token, which allows anyone to speculate on APR volatility. Holders of yield tokens will be able to claim yield from surplus collateral when the APR is on the rise.





- [Live URL](https://app.legato.finance)
- [YouTube](https://youtu.be/r-t098SBnFo)

## Repository structure

The project using a monorepo structure consists of 2 packages using [Lerna](https://lerna.js.org).

- `client`: the frontend application made with [React](https://react.dev/), TailwindCSS, Sui.js and Suiet's wallet-kit
- `move`: contains Move-based smart contracts

## Contract Overview

- `staked_sui.move` - A mock Staked SUI object for testing on the Testnet system.
- `vault.move` - The timelock vault, 1 mil. yield tokens (YT) will be minted and sent to the AMM object for YT circulation at the time of generation. Principal tokens (PT) will be minted when a staker deposits the Staked SUI object into the vault plus additional PT estimated to be generated until the vault matures, as per the APR stated in the Oracle contract.
- `oracle.move` - The Oracle contract, only authorized wallets can update the APR value observed from an external source and update on every epoch.
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

### Sui Testnet

Name | Address 
--- | --- 
Package | 0x9c22e4ec6439f67b4bd1c84c9fe7154969e4c88fe1b414602c1a4d56a54209f6
Vault | 0x50c6f8cf9745a96a7f066afa00633fc06b6f6c33ba7aba4c49de521f07eacf4c

## Roadmap

- [x] Stake Staked SUI object into Timelock Vault
- [x] Unstake when Timelock Vault Matures with only PT
- [x] Orderbook-based Marketplace for trading PT
- [x] New Landing Page
- [x] Oracle Contract
- [x] Merging & Splitting Coin Objects
- [x] AMM-based Marketplace for trading YT
- [ ] Exit the position when the vault is not matures with PT,YT
- [ ] Accuse yield of locked assets
- [ ] Fair distribution of exceeded reward to YT holders
- [ ] Use staking rates on-chain
- [ ] PT,YT to use Coin Currency instead of Coin Balance
