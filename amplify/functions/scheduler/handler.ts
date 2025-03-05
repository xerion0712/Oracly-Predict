import type { Handler } from 'aws-lambda';
import type { EventBridgeHandler } from "aws-lambda";
import type { Schema } from '../../data/resource';
import { Amplify } from 'aws-amplify';
import { generateClient } from 'aws-amplify/data';
import { getAmplifyDataClientConfig } from '@aws-amplify/backend/function/runtime';
import { env } from '$amplify/env/scheduler';
import {
  Account,
  Aptos,
  AptosConfig,
  Network,
  Ed25519PrivateKey,
  InputViewFunctionData
} from "@aptos-labs/ts-sdk";
import FirecrawlApp from '@mendable/firecrawl-js';
import Agent from "../../lib/agentTs"

const { resourceConfig, libraryOptions } = await getAmplifyDataClientConfig(env);

Amplify.configure(resourceConfig, libraryOptions);

const client = generateClient<Schema>();

const MARKET_ID = 1

const app = new FirecrawlApp({ apiKey: env.FIRECRAWL_API_KEY });

export const handler: EventBridgeHandler<"Scheduled Event", null, void> = async (event) => {
  console.log("event", JSON.stringify(event, null, 2))

  // Checking all rounds to be updated
  const config = new AptosConfig({ network: Network.TESTNET });
  const aptos = new Aptos(config);

  const privateKey = new Ed25519PrivateKey(
    `${env.APTOS_MANAGED_KEY}`
  );

  const currentRound: number = await getOnchainCurrentRound(aptos)
  const market: any = await getMarket(MARKET_ID)
  const rounds: any = await market.rounds()

  // Update outcome weights
  await updateWeights(currentRound, market, rounds)

  // Finalize
  await finalize(currentRound, rounds, aptos, privateKey)



}


const getMarket = async (marketId = 1) => {
  const markets = await client.models.Market.list({
    filter: {
      onchainId: {
        eq: marketId
      }
    }
  })
  return markets && markets.data[0] ? markets.data[0] : undefined
}

const getOnchainCurrentRound = async (aptos: any) => {

  const payload: InputViewFunctionData = {
    function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::generalized::get_market_data`,
    functionArguments: [
      MARKET_ID
    ],
  };

  const result = await aptos.view({ payload });

  const entry = {
    createdTime: result[2],
    interval: result[3]
  }

  const diff = (new Date().valueOf()) - (Number(entry.createdTime) * 1000)
  const interval = Number(entry.interval) * 1000
  const round = Math.floor(diff / interval) + 1

  console.log("Current Round: ", round)
  return round
}

const updateWeights = async (currentRound: number, market: any, rounds: any) => {

  console.log("Update Outcome Weights...")

  for (let round of rounds.data) {
    if (currentRound == round.onchainId) {

      let need_update = false
      if (round.lastWeightUpdatedAt === undefined) {
        need_update = true
      } else if ((new Date().valueOf() / 1000) - round.lastWeightUpdatedAt > 86400) {
        need_update = true
      }

      if (need_update) {

        const resource = await market.resource()

        if (resource && resource.data) {

          const source = resource.data.name
          const context = await crawl(resource.data)

          const startPeriod = (Number(market.createdTime) * 1000) + (market.round * (Number(market.interval) * 1000))
          const endPeriod = startPeriod + (Number(market.interval) * 1000)
          const period = `${new Date(startPeriod).toDateString()} - ${new Date(endPeriod).toDateString()}`

          const agent = new Agent()
          const systemPrompt = agent.getWeightPrompt(currentRound, source, parseTables(context), period)

          const outcomes = await round.outcomes()
          const outcomePrompt = agent.getOutcomePrompt(outcomes.data)

          const messages = [systemPrompt, outcomePrompt]

          const output = await parse([...messages, {
            role: 'user',
            content: "help assign weight for each outcome"
          }])

          console.log(output)

          if (output.length > 0) {

            for (let outcome of outcomes.data) {

              const currentOutcome = output.find((item: any) => item.outcomeId === outcome.onchainId)
              const weight = currentOutcome.outcomeWeight

              console.log("updating..", outcome.id, weight)

              await client.models.Outcome.update({
                id: outcome.id,
                weight: weight > 1 ? weight : (weight * 100)
              })

            }

            const lastWeightUpdatedAt = Math.floor((new Date().valueOf()) / 1000)

            await client.models.Round.update({
              id: round.id,
              lastWeightUpdatedAt
            })

          }
        }
      }

    }
  }

  console.log("Update Outcome Weights. Done.")

}

const finalize = async (currentRound: number, rounds: any, aptos: any, privateKey: any) => {

  console.log("Finalize Market...")

  for (let round of rounds.data) {

    if (currentRound > round.onchainId) {
      if (!round.finalizedTimestamp) {

        const { data } = await round.outcomes()
        const outcomes = data.sort((a: any, b: any) => {
          return a.onchainId - b.onchainId
        })

        let outcomeIds = []
        let outcomeWeights = []

        for (let outcome of outcomes) {

          if (outcome.onchainId && outcome.weight) {
            const outcomeId = outcome.onchainId
            const outcomeWeight = outcome.weight

            outcomeIds.push(outcomeId)
            outcomeWeights.push(outcomeWeight * 100)
          }

        }

        // Update smart contract

        console.log("Updating smart contract...")

        const account = Account.fromPrivateKey({
          privateKey
        })

        const transaction = await aptos.transaction.build.simple({
          sender: account.accountAddress,
          data: {
            function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::generalized::finalize_market`,
            functionArguments: [
              MARKET_ID,
              round.onchainId,
              outcomeIds,
              outcomeWeights
            ],
          },
        });

        const senderAuthenticator = aptos.transaction.sign({
          signer: account,
          transaction,
        });

        const submittedTransaction = await aptos.transaction.submit.simple({
          transaction,
          senderAuthenticator,
        });

        console.log(`Submitted Tx: ${submittedTransaction.hash}`)

        // Add timestamp
        await client.models.Round.update({
          id: round.id,
          finalizedTimestamp: Math.floor((new Date().valueOf()) / 1000)
        })

      }
    }

  }

  console.log("Finalize Market. Done.")

}

const parseTables = (input: any) => {
  const tableRegex = /\|.*\|\n(\|[-| ]+\|\n)?([\s\S]*?)\|.*\|/g;
  const tables = input.match(tableRegex);
  return tables ? cleanUrls(tables.join("\n")) : undefined
}

const cleanUrls = (input: any) => {
  const cleanTable = (input.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1')).replace(/!\[.*?<br><br>(.*?)<br><br>.*?\]\(.*?\)/g, '$1');
  return cleanTable
}

const crawl = async (resource: any) => {

  let need_update = false

  if (resource.lastCrawledAt === undefined) {
    need_update = true
  } else if ((new Date().valueOf() / 1000) - resource.lastCrawledAt > 86400) {
    need_update = true
  }

  if (need_update) {

    const result: any = (await app.scrapeUrl(resource.url, { formats: ['markdown', 'html'] }))

    await client.models.Resource.update({
      id: resource.id,
      lastCrawledAt: Math.floor((new Date().valueOf()) / 1000),
      crawledData: result.markdown
    })

    return result.markdown

  } else {
    return resource.crawledData
  }
}

const parse = async (messages: any) => {
  const result: any = await client.queries.WeightAssignment({
    messages: JSON.stringify(messages)
  })

  return JSON.parse(result.data)
}