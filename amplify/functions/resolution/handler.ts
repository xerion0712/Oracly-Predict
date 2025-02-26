import type { Handler } from 'aws-lambda';
import type { EventBridgeHandler } from "aws-lambda";
import type { Schema } from '../../data/resource';
import { Amplify } from 'aws-amplify';
import { generateClient } from 'aws-amplify/data';
import { getAmplifyDataClientConfig } from '@aws-amplify/backend/function/runtime';
import { env } from '$amplify/env/resolution';
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
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import OpenAI from "openai";

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

    // Reveal results
    await reveal(currentRound, market, rounds)

    // Update smart contract



}

const reveal = async (currentRound: number, market: any, rounds: any) => {

    console.log("Reveal Outcome Results...")

    for (let round of rounds.data) {
        if (currentRound > round.onchainId) {
            if (round.finalizedTimestamp && !round.resolvedTimestamp) {

                const { data } = await round.outcomes()
                const outcomes = data.filter((item: any) => item.resolutionDate)

                let checkingOutcomes = []

                for (let outcome of outcomes) {

                    let need_check = false

                    if ((new Date().valueOf() / 1000) > outcome.resolutionDate) {
                        need_check = true
                    }

                    if (need_check) {
                        console.log("need check for outcome : ", outcome)
                        checkingOutcomes.push(outcome)
                    }

                }

                if (checkingOutcomes.length > 0) {

                    const resource = await market.resource()

                    if (resource && resource.data) {
                        const source = resource.data.name
                        const context = await crawl(resource.data)

                        const agent = new Agent()
                        const systemPrompt = agent.getRevealPrompt(source, context)
                        const outcomePrompt = agent.getOutcomePrompt(checkingOutcomes)

                        const messages = [systemPrompt, outcomePrompt, {
                            role: 'user',
                            content: "help reveal the result for each outcome"
                        }]

                        const output = await parse(messages)

                        console.log("output: ", output)

                    }

                }

            }
        }
    }

    console.log("Reveal Outcome Results. Done.")
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


const OutcomeResult = z.object({
    outcomeId: z.number(),
    isWon: z.boolean(),
    isDisputed: z.boolean(),
    explanation: z.string()
});

const OutcomeResults = z.object({
    outcomes: z.array(OutcomeResult)
});

const parse = async (messages: any) => {

    const openai = new OpenAI({ apiKey: env.OPENAI_API_KEY });

    const completion = await openai.beta.chat.completions.parse({
        model: "gpt-4o",
        messages: messages,
        response_format: zodResponseFormat(OutcomeResults, "outcome_results"),
    });

    const output = completion.choices[0].message.parsed;

    return (output && output?.outcomes) ? output.outcomes : []
}