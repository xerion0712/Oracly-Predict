# Legato Next

Here is the completely new version of the **Legato** prediction market allows anyone to create prediction markets. Each market is connected to a trusted source like **CoinMarketCap.com** and actively monitored by an AI-agent, allowing users to chat about it or discover new possible outcomes for the prediction market round, whether it's BTC's price next week or the ranking of their favorite token.

Payouts are distributed based on the weight assigned to each outcome by the AI-agent. Once the round concludes, winners can claim their payout proportionally, according to the weight assigned to each outcome. Unclaimed amounts are carried over to the next round, ensuring a dynamic and growing prize pool.

## Highlighted Improvements
- **Endlessly Possibilities:** Anyone can propose outcomes with AI automatically tracking and revealing the results, such as "Will BTC hit $100,000 by Friday?" or "Will SOL's market cap surpass XRP's by next week?
- **Support USDC:** Now supports USDC for receiving bets, providing more flexibility for users to participate in the prediction market.
- **Supports Authentication:**  With AWS Amplify, allowing login with email or Google for better tracking of all bet positions.
- **OpenAI GPT-4:** Assists in outcome generation, periodically reviews proposed outcomes, and assigns weights based on market data.

## Overview

The system uses the AWS Amplify Stack to efficiently run AI-agents and eliminate the need for dedicated API services for the client. Market-related data is stored in a database, while bets are processed on-chain via smart contracts. This allows for easy cleanup of duplicate or unrelated entries that may have been mistakenly input by users.

![vapor drawio (6)](https://github.com/user-attachments/assets/00ed2d46-b05a-41a0-8fbb-f6d559570ba5)

Outcomes can only be added before the prediction period (round) begins. For example, if the period is from February 1-7, all outcomes and bets must be placed before February 1. Weights are updated daily in the database but will be permanently stored on the smart contract at the start of the period (February 1). Once finalized, no more bets are allowed.
 
And during the period, the AI-agent monitors the real-world data and marks the result for each outcome and will provide all winning outcomes to the smart contract at the end of the round. Outcomes that can't be clearly determined will be marked as disputed, and users who placed bets on these outcomes will receive a full refund.

When the round concludes, all winning outcomes will receive a proportional share based on the weight assigned. The payout is calculated as follows:

```
Payout Share = (Total Pool Prize - Total Disputed Amount) × (Outcome Weight / Sum of Winning Outcomes)
```
Users can then claim their payout based on their contribution to the outcome they bet on. If no more users participate, the payout will be distributed according to the payout share. 

The total disputed amount remains locked for one round. After the round ends, it will be dissolved and added to the prize pool.

## AI-Agent
The AI-agent plays a major role in the system. We have two types of AI-agents as follows:

- **Interactive AI-agent:** Assists users in proposing outcomes, placing bets and get insights with real-time data. It helps users discover potential outcomes based on the market data source.
- **Automated AI-agent:** Runs on the backend to monitor the market, analyze real-time data, assign weights to outcomes, mark results, and update smart contracts. It ensures the system operates autonomously based on the latest data.

All are integrated with OpenAI GPT-4, each having its own guided (system/developer) prompt and a different set of context. It understands real-world data by crawling website data before execution and converting it into markdown format for injection into the prompt.

## How to Use

Simply navigate to https://legato.finance, select a market to bet on, and follow these steps:

**1. Login & Connect**

* Click 'Login' and choose an authentication method (currently supports Google or email).
* Check your wallet. Ensure it's funded.

**2. Choose an Outcome**

* On the market page, review the prize pool and browse all available outcomes.
* If no interesting outcome is found, you can use the AI agent to assist in creating a new outcome.
* Place bets on one (or more) outcomes that you believe will succeed.

**3. Claim Payouts**

* Once the round ends, if your chosen outcome wins, you can claim your payout.
* Correct bets will receive payouts based on contributions, while unclaimed amounts roll over to the next round’s prize pool.

## How to Test

The project is built using the AWS Amplify Stack with Next.js for the frontend. All backend configurations are managed inside the `/amplify` folder. When the GitHub repo is updated, AWS automatically deploys services like real-time databases and APIs. 

However, outside of this stack, we also have a Move smart contract that handles all betting processes. To run the system locally after downloading:

```
npm install
```

You must retrieve `amplify_outputs.json` from the AWS Dashboard after linking your GitHub repo to AWS and place it in the root folder. 

Also, make sure to obtain API keys from the AI services we use and add them to the secret management in the AWS Amplify console.

We can run the frontend with:

```
npm run dev
```

For the smart contract, navigate to `/contracts/aptos-market` and run test cases with:

```
aptos move test
```

Refer to the documentation for deploying a new contract on the live network and updating the JSON file in the project accordingly.

For detailed instructions on deploying to AWS cloud, refer to the [deployment section](https://docs.amplify.aws/nextjs/start/quickstart/nextjs-app-router-client-components/#deploy-a-fullstack-app-to-aws).

## Deployment

### Aptos Testnet

Component Name | ID/Address
--- | --- 
Package ID |  0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775
Mock USDC | 0xc77afa5c74640e7d0f34a7cca073ea4e26d126c60c261b5c2b16c97ac6484f01

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
