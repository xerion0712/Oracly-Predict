# Legato v.2

The V2 launch starts with a DeFi prediction market, with additional services potentially merging later. This version leverages **Atoma Network**'s decentralized AI and the **DeepSeek R1** model to make the prediction market more fun and interactive. It's still heavily development with zero-shot learning to improve accuracy is on the way.

## Highlighted Improvements
- **Endlessly Flexible:** Anyone can propose outcomes with AI automatically tracking and revealing the results, such as "Will BTC hit $100,000 by Friday?" or "Will SOL's market cap surpass XRP's by next week?
- **Ever-Increasing Payouts:** Outcomes are aggregated into a round based on a trusted source. Correct bets will receive payouts based on contribution while unclaimed amounts roll over to the next round’s prize pool.
- **Support USDC:** Now supports USDC for receiving bets, providing more flexibility for users to participate in the prediction market.
- **DeepSeek R1:** Used to assist in outcome generation by providing the topic and asset name. Later, users can place bets and others can join. 

## AI-Agent
The AI-agent plays a major role in the system, leveraging Atoma Network's decentralized AI to ensure the privacy of each user's data. DeepSeek R1 serves as the primary LLM for handling following actions:

### Outcome Suggestions
When users don't find any interesting outcomes to bet on, they can open a modal to propose new outcomes. The modal requires the following inputs:

- **Market Topic:** Choose a market topic, such as token prices, market cap, or any other category depending on the market type.
- **Keyword (Optional):** If users want to specify a more focused prediction, they can provide a keyword (e.g., "BTC Price") to narrow down the outcome, though this is optional.

As an AI-based application that works with prompts, we need to provide specific prompts to guide the system, one to suggest the outcome based on the given topic and keywords.

```
(1) Guide the system
You are an AI assistant that helps users propose new prediction outcomes for DeFi prediction market project based on real-time data likes Will BTC hits 100,000$ by Friday?

(2) Suggest the outcome
Suggest a possible prediction outcome on the topic ${topic} 
With the resolution date set within the week if today is ${(new Date()).toDateString()}
Provided content:
${content} (website data in markdown)
```

### Future Works

The project is under heavy development and aims to deliver more features around AI to helping us achieve our mission of making betting fun on any possible scenario in daily life.

- **Weight Adjustment:** Each outcome is assigned a different weight. For example, a broad prediction like "Will BTC hit $100,000 by Friday?" and a more precise prediction like "Will BTC range between $90,000 and $91,000 on Friday?" will both have different weights to reflect the level of precision.

- **Market Resolution:** Currently, the process is manual, but we aim to develop an automated system that checks results on the website at the given resolution date. It will then stamp the data on the smart contract, allowing the winner to claim their prize.

- **Market Suggestions:** The AI analyzes current trends and identifies new data sources. For example, it can detect new influencers or emerging topics, allowing users to place bets on these new events as they unfold.


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

Also, ensure you obtain API keys from the AI services we use and add them to the .env file:

```
# 3rd parties AI services
FIRECRAWL_API_KEY=your-api-key
ATOMA_API_KEY=your-api-key
```

We can run the frontend with:

```
npm run dev
```

Refer to the documentation for deploying a new contract on the live network and updating the JSON file in the project accordingly.

For detailed instructions on deploying to AWS cloud, refer to the [deployment section](https://docs.amplify.aws/nextjs/start/quickstart/nextjs-app-router-client-components/#deploy-a-fullstack-app-to-aws).

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
