import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"
import { env } from '$amplify/env/chat2';
import { ChatAnthropic } from "@langchain/anthropic"
import { Aptos, AptosConfig, Ed25519PrivateKey, Secp256k1PrivateKey, Network, PrivateKey, PrivateKeyVariants } from "@aptos-labs/ts-sdk"
import { AIMessage, BaseMessage, ChatMessage, HumanMessage } from "@langchain/core/messages"
import { createReactAgent } from "@langchain/langgraph/prebuilt"
import { AgentRuntime, LocalSigner, createAptosTools } from "move-agent-kit"


const llm = new ChatAnthropic({
  temperature: 0.7,
  model: "claude-3-5-sonnet-latest",
  apiKey: process.env.ANTHROPIC_API_KEY,
})

export const handler: Schema["Chat2"]["functionHandler"] = async (event) => {

  const messages: any = event.arguments.messages
  const roundNumber: any = event.arguments.roundNumber
  const period: any = event.arguments.period

  const agent: any = await setup({ roundNumber, period })

  const output = await agent.invoke(
    {
      messages
    }
  )

  const finalized = parseLangchain(output.messages).map((msg: any) => {
    const message = messages.find((i: any) => i.id === msg.id)
    if (message) {
      msg = message
    }
    return msg
  })

  console.log("final messages :", finalized)

  return finalized
}


const setup = async ({ roundNumber, period }: any) => {
  // Initialize Aptos configuration
  const aptosConfig = new AptosConfig({
    network: Network.MAINNET,
  })

  const aptos = new Aptos(aptosConfig)
  const privateKeyStr = process.env.APTOS_TEST_KEY || ""

  // Setup account and signer
  const account = await aptos.deriveAccountFromPrivateKey({
    privateKey: new Secp256k1PrivateKey(PrivateKey.formatPrivateKey(privateKeyStr, PrivateKeyVariants.Secp256k1)),
  })

  const signer = new LocalSigner(account, Network.MAINNET)
  const aptosAgent = new AgentRuntime(signer, aptos)
  const moreTools = createAptosTools(aptosAgent)

  // Create React agent
  const agent = createReactAgent({
    llm,
    tools: moreTools,
    messageModifier: [
      `You are an AI assistant for the Legato DeFi prediction market. You use the Aptos Agent Kit to access parameters across supported DeFi protocols.\n`,
      `Your role is to help users place bets, propose new outcomes, and provide guidance throughout the prediction round.\n`,
      `Round Details:\n`,
      `Round Number: ${roundNumber}\n`,
      `Source: On-Chain via Move Agent Kit\n`,
      `Outcomes Available:\n`,
      `None\n`,
      `Predicting Period: ${period} \n`,
      `Core Tasks:\n`,
      `1. **Monitor Market Trends** – Analyze real-time data from the source.\n`,
      `2. **Propose Outcomes** – Suggest potential outcomes for this round based on market trends.\n`,
      `3. **Assign Weights** – Calculate probabilities for each proposed outcome\n. `,
      `4. **Guide Users** – Answer questions, assist with betting, and clarify rules.\n`,
      `Rules:\n`,
      `- When the user greets with "hello" or asks "what can you do?", provide round information and convince them to place a bet.\n`,
      `- If no outcomes are available, suggest that they propose a new one and offer assistance.\n`,
      `- When adding a new outcome, ask for confirmation before proceeding and inform the user that a modal will open for input.\n`,
      `- Be diverse about new outcomes, it can be such as token price, ranking, or trading volume.\n`,
      `- Outcomes must be within the current round’s predicting period.\n`,
      `- Users can only place bets before the round starts. Once started, outcomes and weights are finalized.\n`,
      `- When users want to bet, show them the available outcomes or the available outcomes tab above.\n`,
      `- All bets contribute to the prize pool. Prizes are distributed among winning outcomes based on assigned weights, with unclaimed amounts rolling over to the next round.\n`
    ].join("")
  })

  return agent 
}


const parseLangchain = (messages: any) => {
  let finalized: any = []

  messages.map((msg: any) => {
    const role = msg?.additional_kwargs && Object.keys(msg?.additional_kwargs).length === 0 ? "user" : "assistant"

    if (msg?.tool_call_id) {
      finalized.push({
        content: [
          {
            type: "tool_result",
            tool_use_id: msg.tool_call_id,
            content: msg.kwargs?.content || msg.content,
          }
        ],
        role: "user",
        id: msg.kwargs?.id || msg.id
      })
    } else {
      finalized.push({
        role,
        content: msg.kwargs?.content || msg.content,
        id: msg.kwargs?.id || msg.id
      })
    }
  })
  return finalized
}