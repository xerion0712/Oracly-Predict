# Legato

Legato is a DeFi liquidity bootstrap protocol utilizing native staking available on Sui and currently experimenting on Aptos. It allows stakers to sacrifice staking rewards for the next 6 or 12 months in exchange for early project tokens launched on Legato LBP. Early projects will benefit from a stable price curve and mitigated selling pressure. Stakers receive new tokens while all principal assets remains the same. Existing projects can also list tokens with significantly less initial capital, around 3x to 5x less compared to other DEX platforms.

The Legato system is made up of core modules outlined as follows:

- Fixed APY Vaults - Allows locking in a fixed staking rate for a fixed period by converting staked assets into derivative tokens representing the future value at the vault's maturity date.
- Dynamic Weight AMM - An AMM that allows customization of pool weights, ranging from 50/50, 80/20 to 90/10, benefiting projects that want to set up a new pool with much less initial capital paired with their tokens.
- LBP (Liquidity Bootstrap Pool) - An AMM pool where the weight can automatically shift when more liquidity comes in, ideally for projects to launch tokens with a stable price curve.

## Fixed APY Vaults

The fixed yield vault is generally a timelock vault with a specific maturity date controlled by VaultManager or `vault.move`. The system employs a quarterly expiration scheme. At any given time, there will be 4 vaults available to stake, allowing conversion of staked assets into their future value at the end of each quarter Q1, Q2, Q3 and Q4.

The fixed-yield vault supports different input tokens:

- SUI - When using SUI tokens to stake for derivative PT on a vault with a maturity date 1 year from now and 3% fixed staking rate, when you stake 1 SUI, it will be staked on validators first for the Staked SUI object. Then, the Staked SUI object will be transferred and locked in the vault and 1.03 PT tokens will be minted back to the user.
- Staked SUI - You can also use Staked SUI objects to lock in staking APY. We support only Staked SUI from our whitelist validators, not all of them. When staked, the object will be locked in the vault and PT tokens will be minted to the user.

PT token holders can hold until the vault matures and can redeem principal assets back at a 1:1 ratio. Alternatively, they can exit at any time using the following exit formula.

```
SUI = PT / e^(rt) - exit fee%
```
Where r is the vault's fixed APY rate and t is the time remaining until the vault matures.

## Legato DEX & LBP
Legato DEX implements custom weights. It originated based on the OmniBTC AMM and upgraded the weights function using the Balancer V2 Lite formula from Ethereum. These custom weights enable us to deploy new pools with significantly less initial capital compared to traditional methods. 

Additionally, this flexibility in weight allocation allows us to facilitate Liquidity Bootstrap Pool (LBP), allowing for dynamic adjustments in liquidity to maintain stable token prices during token launches for early projects.

In Legato LBP, projects have the option to pair their tokens with two types of settlement assets:

- Common coins such as USDC or SUI - These are stablecoins or native tokens that provide liquidity and stability to the trading pairs. They are commonly used as settlement assets in decentralized exchanges due to their predictable value.

- SUI staking rewards via Legato Vault - This option allows project tokens to be paired with the staking rewards earned through the Legato Vault. By using staking rewards as settlement assets, it makes the weight shift cliff on the sell transactions, thereby keeping slippage high until accrued rewards are deposited into the pool.

We recommend that projects run in two phases, starting with staking rewards and then transitioning to coins for a smoother token launch.

## Legato Math

During development, dynamic weight pools and vault assets requires dealing with fractional exponents and nth roots. We created a small math library to handle these and separated it into another repository that anyone can use.

https://github.com/tamago-labs/legato-math

## Fee Structure

The following fee structure applies to various operations within the system:

```
Vault Exit Fee - 3%
AMM Stable Pool Trading Fee - 0.1%
AMM LBP Pool Trading Fee - 0.25%
AMM General Pool Trading Fee - 0.5%
```

## Getting Started

The project uses a monorepo managed by Lerna. You can install all dependencies by:

```
npm install
```
All smart contracts are based on the Move language and can test all scenarios that occur in the system by simply running:
```
npm run test
```

## Deployment


### SUI Mainnet

Component Name | ID
--- | --- 
Package |  0xd3fc3ab5f195dc72597a469f7ba2ab2aa754d28c6a70b785a6bd65a6b005151d
VaultManager | 0x4720e0ea8cb12c57ec5e82d866de619fb437706e587e048404dd31049635fea2
AMM | 0x5626a93e354638a742e180c28c2293dca3fa0e26bb81f40a21304ef81ae51672

### SUI Testnet

Component Name | ID
--- | --- 
Package | 0x547cf6fede9391de49d71fe134a1c19824467f5826f0cc1843669f26264af5e9 
VaultManager | 0xf44b1aa505120d29d9f23f30e304d89f08284725d07fda643af21b12e0568d12
AMM | 0x9a69ffb2ef8270ecbad2a74b742926aed3965581deeffbd36432a84761f1c753
Mock Legato | 0x53fa3828cd37c435ff7e9e21a78c934b960afe51070427eef866fadb44131e9b





