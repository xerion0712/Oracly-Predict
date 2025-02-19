import { type ClientSchema, a, defineData } from "@aws-amplify/backend";
import { faucet } from "../functions/faucet/resource";

const schema = a.schema({
  ChatAI: a.conversation({
    aiModel: a.ai.model('Claude 3.5 Sonnet'),
    systemPrompt: [
      `You are an AI assistant responsible for managing a prediction market system. Your job is to analyze data, propose outcomes, assign weights, and assist users.\n`,
      `Core Tasks:\n`,
      `1. Monitor Market Trends – Analyze real-time data from the source.\n`,
      `2. Propose Outcomes – Suggest potential outcomes for the given round.\n`,
      `3. Assign Weights – Calculate probabilities for each outcome.\n`,
      `4. Resolve Markets – Identify winning outcomes, push unclear ones to dispute.\n`,
      `5. Guide Users – Answer questions, assist with betting, and clarify rules.\n`,
      `Rules:\n`,
      `- Users can only place bets before the round starts.\n`,
      `- Before the round begins, your job is to propose outcomes and assign weights.\n`,
      `- Once the round starts, all outcome weights must be finalized, and no further bets can be placed.\n`,
      `- When interacting with users, if they want to bet, provide all available outcomes and their details, and tell them to find the panel on the client side.`
    ].join(""),
  })
    .authorization((allow) => allow.owner()),
  Faucet: a
    .query()
    .arguments({
      name: a.string(),
    })
    .returns(a.string())
    .handler(a.handler.function(faucet))
    .authorization((allow) => [allow.publicApiKey()])
  ,
  User: a
    .model({
      username: a.string().required(),
      image: a.url(),
      markets: a.hasMany('Market', "managerId"),
      comments: a.hasMany('Comment', "userId"),
      positions: a.hasMany('Position', "userId"),
      role: a.enum(["USER", "MANAGER", "ADMIN"])
    })
    .authorization((allow) => [allow.publicApiKey()]),
  Market: a
    .model({
      managerId: a.id().required(),
      manager: a.belongsTo('User', "managerId"),
      onchainId: a.integer(),
      title: a.string().required(),
      description: a.string(),
      chains: a.string().array(),
      images: a.string().array(),
      resource: a.hasOne('Resource', "marketId"),
      category: a.string(),
      tags: a.string().array(),
      currency: a.string(),
      maxBet: a.float(),
      minBet: a.float(),
      onchainCreatedTime: a.timestamp(),
      onchainRoundInterval: a.integer(),
      betPoolAmount: a.float(),
      comments: a.hasMany('Comment', "marketId"),
      positions: a.hasMany('Position', "marketId"),
      rounds: a.hasMany('Round', "marketId"),
      totalOutcomes: a.integer()
    })
    .authorization((allow) => [allow.publicApiKey()]),
  Comment: a.model({
    marketId: a.id().required(),
    userId: a.id().required(),
    user: a.belongsTo('User', "userId"),
    market: a.belongsTo('Market', "marketId"),
    rating: a.integer(),
    content: a.string()
  }).authorization((allow) => [allow.publicApiKey()]),
  Position: a.model({
    marketId: a.id().required(),
    market: a.belongsTo('Market', "marketId"),
    userId: a.id().required(),
    user: a.belongsTo('User', "userId"),
    roundId: a.integer(),
    onchainId: a.integer(),
    chain: a.string(),
    predictedOutcome: a.integer(),
    betAmount: a.integer(),
    hidden: a.boolean(),
    status: a.enum(["PENDING", "WIN", "LOSE", "CANCELLED"]),
    walletAddress: a.string()
  }).authorization((allow) => [allow.publicApiKey()]),
  Round: a.model({
    marketId: a.id().required(),
    market: a.belongsTo('Market', "marketId"),
    onchainId: a.integer(),
    totalBetAmount: a.float(),
    totalPaidAmount: a.float(),
    totalDisputedAmount: a.float(),
    weight: a.float(),
    outcomes: a.hasMany('Outcome', "roundId"),
    winningOutcomes: a.integer().array(),
    disputedOutcomes: a.integer().array(),
    status: a.enum(["PENDING", "FINALIZED", "RESOLVED"]),
    finalizedTimestamp: a.timestamp(),
    resolvedTimestamp: a.timestamp(),
    agentName: a.string(),
    agentMessages: a.json().array(),
    agentConfig: a.json(),
  }).authorization((allow) => [allow.publicApiKey()]),
  Outcome: a.model({
    roundId: a.id().required(),
    round: a.belongsTo('Round', "roundId"),
    onchainId: a.integer(),
    totalBetAmount: a.float(),
    weight: a.float(),
    title: a.string(),
    resolutionDate: a.timestamp(),
    status: a.enum(["PENDING", "WIN", "LOSE", "CANCELLED"]),
    crawledDataAtCreated: a.string(),
    result: a.string()
  }).authorization((allow) => [allow.publicApiKey()]),
  Resource: a.model({
    marketId: a.id().required(),
    market: a.belongsTo('Market', "marketId"),
    name: a.string(),
    url: a.string(),
    category: a.string(),
    crawledData: a.string(),
    lastCrawledAt: a.timestamp()
  }).authorization((allow) => [allow.publicApiKey()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: "apiKey",
    apiKeyAuthorizationMode: {
      expiresInDays: 30,
    },
  },
});