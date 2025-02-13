import { type ClientSchema, a, defineData } from "@aws-amplify/backend";

const schema = a.schema({
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
      image: a.url(),
      resource: a.hasOne('Resource', "marketId"),
      category: a.string(),
      tags: a.string().array(),
      currency: a.string(),
      comments: a.hasMany('Comment', "marketId"),
      positions: a.hasMany('Position', "marketId"),
      outcomes: a.hasMany('Outcome', "marketId")
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
  Outcome: a.model({
    marketId: a.id().required(),
    market: a.belongsTo('Market', "marketId"),
    onchainId: a.integer(),
    roundId: a.integer(),
    totalBetAmount: a.integer(),
    title: a.string(),
    resolutionDate: a.datetime(),
    status: a.enum(["PENDING", "WIN", "LOSE", "CANCELLED"]),
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
