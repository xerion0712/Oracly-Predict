import { type ClientSchema, a, defineData } from "@aws-amplify/backend";
import { faucet } from "../functions/faucet/resource";
import { chat } from "../functions/chat/resource";
import { chat2 } from "../functions/chat2/resource";
import { weight } from "../functions/weight/resource"
import { scheduler } from "../functions/scheduler/resource"
import { resolution } from "../functions/resolution/resource"

const schema = a.schema({
  Faucet: a
    .query()
    .arguments({
      name: a.string(),
    })
    .returns(a.string())
    .handler(a.handler.function(faucet))
    .authorization((allow) => [allow.publicApiKey()])
  ,
  Chat: a
    .query()
    .arguments({
      messages: a.json(),
      tools: a.json(),
    })
    .returns(a.json())
    .handler(a.handler.function(chat))
    .authorization((allow) => [allow.publicApiKey()])
  ,
  Chat2: a
    .query()
    .arguments({
      messages: a.json(),
      roundNumber: a.string(),
      period: a.string()
    })
    .returns(a.json())
    .handler(a.handler.function(chat2))
    .authorization((allow) => [allow.publicApiKey()])
  ,
  WeightAssignment: a
    .query()
    .arguments({
      messages: a.json(),
    })
    .returns(a.json())
    .handler(a.handler.function(weight))
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
      rounds: a.hasMany('Round', "marketId")
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
    walletAddress: a.string(),
    isClaimed: a.boolean()
  }).authorization((allow) => [allow.publicApiKey()]),
  Round: a.model({
    marketId: a.id().required(),
    market: a.belongsTo('Market', "marketId"),
    onchainId: a.integer(),
    totalBetAmount: a.float(),
    totalPaidAmount: a.float(),
    totalDisputedAmount: a.float(),
    weight: a.float(),
    lastWeightUpdatedAt: a.timestamp(),
    outcomes: a.hasMany('Outcome', "roundId"),
    winningOutcomes: a.integer().array(),
    disputedOutcomes: a.integer().array(),
    status: a.enum(["PENDING", "FINALIZED", "RESOLVED"]),
    finalizedTimestamp: a.timestamp(),
    resolvedTimestamp: a.timestamp()
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
    result: a.string(),
    revealedTimestamp: a.timestamp(),
    isWon: a.boolean(),
    isDisputed: a.boolean()
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
}).authorization((allow) => [
  allow.resource(scheduler),
  allow.resource(resolution)
]);

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