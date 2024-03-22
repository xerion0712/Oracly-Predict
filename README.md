# Legato

Legato is a DeFi vault strategy protocol for liquid stakers on the Sui blockchain that enables new primitives for staking and provides additional tools to capitalize on market volatility. Each type of vault allows for achieving a specific target without any fees. The brief overview is as follows:

- Fixed-yield - For lock-in fixed rates for liquid staked assets and redeem back at the full amount regardless of APY fluctuations.
- Passive asset - Assets that are permanent and have no maturity date. Anyone can buy through the AMM and earn a stable yield.
- Leveraged (TBA) - A vault that allows earning staking rewards at 2x-4x by locking up the collateral.
- RWA (TBA) - Vault that bridges RWA assets mainly from Ethereum to be available on Sui blockchain.

## Fixed-Yield Vault

The fixed yield vault is generally a timelock vault with a specific maturity date controlled by VaultManager or `vault.move`. The system requires having 2 active vaults simultaneously to be active. Otherwise, no one can interact with any single vault. This ensures that the vault token can always migrate to the next vault that is not backward in time.

![legato-vault drawio (2)](https://github.com/tamago-labs/legato-finance/assets/18402217/bc23fdf7-3b28-47c6-8f36-715ffe72f402)

The fixed-yield vault supports two input tokens:
- SUI - When using SUI tokens to stake for derivative PT on a vault with a maturity date 1 year from now and 3% fixed staking rate, when you stake 1 SUI, it will be staked on validators first for the Staked SUI object. Then, the Staked SUI object will be transferred and locked in the vault and 1.03 PT tokens will be minted back to the user.
- Staked SUI - You can also use Staked SUI objects to lock in staking APY. We support only Staked SUI from our whitelist validators, not all of them. When staked, the object will be locked in the vault and PT tokens will be minted to the user.

![legato-vault-Page-2 drawio (3)](https://github.com/tamago-labs/legato-finance/assets/18402217/68e1e783-de47-4e89-9faa-339406e74960)


When you have vault PT tokens, you will have 3 options to go:

- Hold until the vault matures and redeem SUI at a 1:1 ratio. When you have 100 PT, you can redeem them for 100 SUI, regardless of any APY fluctuations between the time you staked and when the vault matures.
- PT holders can exit prior to the maturity date by selling on Legato's DEX. PT is considered as the future value on the maturity date, attracting various actors such as speculators and arbitragers who can all benefit from the potential profits and liquidity offered.
- As mentioned above, PT tokens always migrate to the next available vault. Through migration, a long-term staker can burn PT and mint them into another vault without needing to unstake the underlying Staked SUI objects locked in any vault.

## Passive Asset 

There will be a passive asset that delta-hedges against accrued rewards, given the fragility of APY. Speculators who anticipate an increase in APY above the fixed rate can acquire YT tokens from Legato's DEX. Whenever there is a surplus, it will be used to buy back YT on the AMM, gradually increasing its value over time. Thus, the passive asset may enable holders to earn a stable yield with low risk.

There is currently a single passive asset, which is YT tokens or yield tokens that hedge against all fixed-yield vaults in the system. A facilitator will perform rebalancing on a timely basis

![legato-vault-Page-3 drawio (2)](https://github.com/tamago-labs/legato-finance/assets/18402217/00ec99f1-f2c1-450a-bb33-6176bbd26179)

In case of a decrease in APY, it doesn't bring the value down, as the liquidity provider will suffer in this case.

## Fee Structure

We don't currently charge any fees and we don't plan to in the near future. Our business model relies on being liquidity providers in the system and taking margins from there.

## Getting Started

The system consists of several modules responsible for each role as follows:
- `vault.move` - VaultManager is responsible for setting up new vaults and configuring them by authorized admins, minting and redeeming PT tokens by users.
- `amm.move` - A primary marketplace module based on AMM, which we forked from OmniBTC that has a similar concept to Uniswap v2.
- `marketplace.move` - A secondary marketplace module based on an order book that doesn't require upfront liquidity.

You can try it out by clone this repository. Ensure you have all the necessary software for SUI dapp development. 
- https://docs.sui.io/guides/developer/first-app

The project uses a monorepo managed by Lerna. You can install all dependencies by:

```
npm install
```

All smart contracts are based on the Move language and can test all scenarios that occur in the system by simply running:

```
npm run test
```

Alternatively, just visit https://legato.finance. We also have the Testnet vaults available for evaluation.

## Deployment

### SUI Mainnet

Component Name | ID
--- | --- 
Package |  0x5cf159eededc6f5094ff5f0efe01a4cfa5b6b56a814927f87f2f825f5c3b16df
VaultManager | 0x627ad151f549854c6ed4c051e36062b8d6a1827bd7823c142ec3e5a116fdb496
AMM | 0x0ee9bac5522ed149d2b1af16efdd1174cd8c3b5c46b6397587424145e3956a2f
Marketplace | 0xa9ff982b71870ea46ab3eafefb0853467cb4ed4e2c5a42b6f271c846bd4f3c7f

### SUI Testnet

Component Name | ID
--- | --- 
Package | 0x61bc3f475d97acf87194fbef1241737af5e8d34e73e5a75fe040fb5dcdc78421 
VaultManager | 0x8f7c29f55aec81374920a470ec8544f38134a4917ac4d01c66f02bc801c5f75f
AMM | 0x75b41ba12f51e1b568d0ee536a1f31beb608687424fe2daf497ebb3fc176b0b5
Marketplace | 0x4cae5f2743d3e1c8cf5e109ba58886ef4e674261522908ffef0e3cf67bb6d5ad
Mock USDC | 0x3fdd779686c301105a39e735275919325b79e546f8a49972008f8667487b3a15

