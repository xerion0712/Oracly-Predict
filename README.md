# Oracly Predict

**Oracly Predict** is a decentralized prediction market platform where anyone can create and participate in prediction markets. Each market is linked to trusted data sources (like CoinMarketCap) and monitored by AI agents, enabling informed betting and real-time insights.

---

## 🔹 Key Features

* **User-Generated Prediction Markets**
  Users can propose outcomes such as “Will BTC reach \$100,000 by Friday?” or “Will SOL’s market cap surpass XRP next week?” AI tracks results automatically.

* **AI-Weighted Payouts**
  Each outcome is assigned a weight by the AI agent. Winners receive payouts proportional to their contribution and the AI-assigned weight.

* **USDC Support**
  Bets can be placed using USDC for seamless stablecoin transactions.

* **Authentication**
  Login via email or Google through AWS Amplify, allowing secure tracking of user positions.

* **AI Assistance**
  OpenAI GPT-4 powers AI agents that propose outcomes, update weights daily, and mark results based on real-world market data.

---

## 🔹 How It Works

1. **Market Creation**

   * Outcomes can only be submitted before a round starts.
   * AI updates weights daily and finalizes them at the beginning of the prediction round.

2. **Bet Placement**

   * Users place bets on outcomes they predict will succeed.
   * Bets are recorded on-chain via Move smart contracts.

3. **AI Monitoring & Resolution**

   * AI monitors market data in real-time.
   * Results are updated to the smart contract at the end of the round.
   * Disputed or unclear outcomes are refunded.

4. **Payout Calculation**

   ```text
   Payout Share = (Total Pool Prize - Total Disputed Amount) × (Outcome Weight / Sum of Winning Outcomes)
   ```

   * Users claim payouts according to their contribution.
   * Unclaimed amounts roll over to the next round, growing the prize pool dynamically.

---

## 🔹 AI-Agent Roles

* **Interactive AI-Agent**: Assists users in outcome discovery, placing bets, and generating insights.
* **Automated AI-Agent**: Continuously monitors markets, evaluates outcomes, updates weights, and writes results to smart contracts.

---

## 🔹 Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/xerion0712/oracly-predict.git
   cd oracly-predict
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Configure AWS Amplify**

   * Download `amplify_outputs.json` from AWS after linking the repo.
   * Add API keys for AI services in the Amplify secret manager.

4. **Run Frontend**

   ```bash
   npm run dev
   ```

5. **Run Smart Contract Tests**

   ```bash
   cd contracts/aptos-market
   aptos move test
   ```

---

## 🔹 Deployment

* **Testnet Addresses** (Aptos)

  | Component  | ID/Address                                                           |
  | ---------- | -------------------------------------------------------------------- |
  | Package ID | `0xab9c322cb1794928abed8f57775a5dac72fed24f88077e46593bed47dcdbe8d9` |
  | Mock USDC  | `0xc477c7640e7d0f4f0134a7cca073ea4e26d126c60c261b5c2b16c97ac648afa5` |

* **Frontend & Backend** deploy automatically via AWS Amplify on GitHub updates.

---

## 🔹 License

This project is licensed under **MIT-0 License**. See the [LICENSE](LICENSE) file.


