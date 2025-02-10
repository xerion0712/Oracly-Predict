import { type ClientSchema, a, defineData } from "@aws-amplify/backend";

const schema = a.schema({
  // User: a.model({
  //   username: a.string().required(),
  //   image: a.string(),
  //   wallets: a.hasMany("Wallet", "userId"),
  //   markets: a.hasMany('Market', "creatorId"),
  //   predictions: a.hasMany('Prediction', "userId"),
  //   reviews: a.hasMany('Review', "userId"),
  //   credits: a.integer(),
  //   leaderboardEntry: a.hasOne('LeaderboardEntry', "userId"),
  //   role: a.enum(["USER", "CREATOR", "ADMIN"])
  // }).authorization((allow) => [allow.publicApiKey()]),
  // Wallet: a.model({
  //   userId: a.id().required(),
  //   user: a.belongsTo('User', "userId"),
  //   walletAddress: a.string().required(),
  //   chainId: a.string()
  // }).authorization((allow) => [allow.publicApiKey()]),
  // Market: a.model({
  //   creatorId: a.id().required(),
  //   title: a.string(),
  //   image: a.string(),
  //   description: a.string(),
  //   outcomes: a.string().array(),
  //   status: a.enum(['ACTIVE', 'CLOSED', 'RESOLVED']),
  //   resolvedOutcome: a.integer(),
  //   closingDate: a.datetime(),
  //   resolutionDate: a.datetime(),
  //   createdDate: a.datetime(),
  //   category: a.string(),
  //   tags: a.string().array(),
  //   chainId: a.string(),
  //   round: a.integer(),
  //   marketType: a.integer(),
  //   creator: a.belongsTo('User', "creatorId"),
  //   predictions: a.hasMany('Prediction', "marketId"),
  //   reviews: a.hasMany('Review', "marketId")
  // }).authorization((allow) => [allow.publicApiKey()]),
  // Prediction: a.model({
  //   marketId: a.id().required(),
  //   userId: a.id().required(),
  //   user: a.belongsTo('User', "userId"),
  //   market: a.belongsTo('Market', "marketId"),
  //   outcome: a.integer(),
  //   stake: a.integer(),
  //   currency: a.string(),
  //   status: a.enum(['OPEN', 'CLOSED', 'RESOLVED', 'CANCELLED']),
  //   createdDate: a.datetime()
  // }).authorization((allow) => [allow.publicApiKey()]),
  // LeaderboardEntry: a.model({
  //   userId: a.id().required(),
  //   user: a.belongsTo('User', "userId"),
  //   totalPredictions: a.integer(),
  //   successfulPredictions: a.integer(),
  //   totalPnL: a.float(),
  //   rank: a.integer()
  // }).authorization((allow) => [allow.publicApiKey()]),
  // Review: a.model({
  //   marketId: a.id().required(),
  //   userId: a.id().required(),
  //   user: a.belongsTo('User', "userId"),
  //   market: a.belongsTo('Market', "marketId"),
  //   rating: a.integer(),
  //   content: a.string(),
  //   createdDate: a.datetime()
  // }).authorization((allow) => [allow.publicApiKey()]),
  // TokenPrice: a.model({
  //   symbol: a.string().required(),
  //   image: a.string(),
  //   price: a.float(),
  //   timestamp: a.datetime(),
  //   source: a.string(),
  // }).authorization((allow) => [allow.publicApiKey()]),
  // Resource: a.model({
  //   name: a.string().required(),
  //   description: a.string(),
  //   url: a.string(),
  //   context: a.string(),
  //   category: a.string(),
  //   crawled_data: a.string(),
  //   last_crawled_at: a.timestamp()
  // }).authorization((allow) => [allow.publicApiKey()]),
  // OutcomeSegmentationAI: a.generation({
  //   aiModel: a.ai.model('Claude 3.5 Sonnet'),
  //   systemPrompt: 'You are an intelligent assistant that analyzes website content and assists in DeFi market prediction creation by suggesting possible outcomes.',
  //   inferenceConfiguration: {
  //     temperature: 1,
  //     topP: 0.999,
  //     maxTokens: 4096
  //   }
  // })
  //   .arguments({
  //     description: a.string()
  //   })
  //   .returns(
  //     a.customType({
  //       outcomes: a.string().array(), // Suggested outcomes (e.g., A, B, C, D)
  //     })
  //   )
  //   .authorization((allow) => allow.publicApiKey()),
  // MarketCreationAI: a.generation({
  //   aiModel: a.ai.model('Claude 3.5 Sonnet'),
  //   systemPrompt: 'You are an AI assistant that analyzes website content to generate market predictions.',
  //   inferenceConfiguration: {
  //     temperature: 1,
  //     topP: 0.999,
  //     maxTokens: 4096
  //   }
  // })
  //   .arguments({
  //     description: a.string()
  //   })
  //   .returns(
  //     a.customType({
  //       result: a.string()
  //     })
  //   )
  //   .authorization((allow) => allow.publicApiKey()),
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

/*== STEP 2 ===============================================================
Go to your frontend source code. From your client-side code, generate a
Data client to make CRUDL requests to your table. (THIS SNIPPET WILL ONLY
WORK IN THE FRONTEND CODE FILE.)

Using JavaScript or Next.js React Server Components, Middleware, Server
Actions or Pages Router? Review how to generate Data clients for those use
cases: https://docs.amplify.aws/gen2/build-a-backend/data/connect-to-API/
=========================================================================*/

/*
"use client"
import { generateClient } from "aws-amplify/data";
import type { Schema } from "@/amplify/data/resource";

const client = generateClient<Schema>() // use this Data client for CRUDL requests
*/

/*== STEP 3 ===============================================================
Fetch records from the database and use them in your frontend component.
(THIS SNIPPET WILL ONLY WORK IN THE FRONTEND CODE FILE.)
=========================================================================*/

/* For example, in a React component, you can use this snippet in your
  function's RETURN statement */
// const { data: todos } = await client.models.Todo.list()

// return <ul>{todos.map(todo => <li key={todo.id}>{todo.content}</li>)}</ul>
