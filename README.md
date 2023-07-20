# Legato Finance

Legato is a protocol for trading future yield of any liquid staking assets on the Sui blockchain, allowing users to lock up yield-bearing assets into the timelock vault. Prior to the maturity date, the user will receive vault tokens equivalent to the locked asset plus additional yield up to the maturity date in advance. These tokens can then be sold on Legato's decentralized exchange.

![Untitled Diagram drawio (14)](https://github.com/pisuthd/legato-finance/assets/18402217/a1c19022-8c2f-42d5-a5a2-33c6abcbdc92)

And when the vault is matured, the vault token holders can redeem the locked tokens back at a 1:1 ratio. The product was made during the WebX Sui Move Hackathon and is live on the Sui Testnet. You can access it through the following URL. However, it still has several limitations, including receiving vault tokens at a 1:1 ratio without including additional yield.

- [Live URL](https://legato-finance-client.vercel.app/)
- [YouTube](https://youtu.be/INN8mz4Qzws)
- [Akindo](https://app.akindo.io/communities/xKao6wZaqu6XPWv6/products/d8RoedOEZtVDx7N2)

## Repository structure

The project using a monorepo structure consists of 2 packages using [Lerna](https://lerna.js.org).

- `client`: the frontend application made with [React](https://react.dev/), TailwindCSS, Sui.js and Suiet's wallet-kit
- `legato`: contains Move-based smart contracts

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
Package | 0x049e0241831bd3ee71662fcfd1125f45fda84f8c892a36ae530fdc1c7f7d7884
Mock StakedSui | 0xdd5e3d67f7ffba50d4b2ac08784ca9adc797dda53c27ede73a521aab3a2ebab5
Vault | 0xe755f1908f1c0e5b1c6ade71ee50bc023d8eb60bcfb1d8eb4d27878d45a1dfd1
Marketplace | 0x517837b3d5f20675aec9bcc1c8f2789e523986bc5562b2e96fc177d055beb4ca
