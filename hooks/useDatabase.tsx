
import { generateClient } from "aws-amplify/data";
import FirecrawlApp from '@mendable/firecrawl-js';
import type { Schema } from "../amplify/data/resource"

const FIRECRAWL_API_KEY = process.env.FIRECRAWL_API_KEY || ""

const client = generateClient<Schema>();

const app = new FirecrawlApp({ apiKey: FIRECRAWL_API_KEY });

const useDatabase = () => {

    const getProfile = async (userId: string) => {
        const user = await client.models.User.list({
            filter: {
                username: {
                    eq: userId
                }
            }
        })

        if (user.data.length === 0) {
            const newUser = {
                username: userId
            }
            await client.models.User.create({
                ...newUser
            })
            return newUser
        } else {
            return user.data[0]
        }
    }

    const getMarketData = async (marketId: number) => {
        const markets = await client.models.Market.list({
            filter: {
                onchainId: {
                    eq: marketId
                }
            }
        })
        return markets && markets.data[0] ? markets.data[0] : undefined
    }

    const getMarkets = async (chainId: string) => {
        // const markets = await client.models.Market.list({
        //     filter: {
        //         chainId: {
        //             eq: chainId
        //         }
        //     }
        // })
        // return markets.data
        return []
    }

    const getMarketsByCreator = async (creatorId: string) => {
        // const markets = await client.models.Market.list({
        //     filter: {
        //         creatorId: {
        //             eq: creatorId
        //         }
        //     }
        // })
        // return markets.data
        return []
    }

    const getResources = async () => {
        const resources = await client.models.Resource.list()
        return resources.data
    }

    const getOutcomes = async (marketId: string, roundId: number) => {
        
        const market = await client.models.Market.get({
            id: marketId
        })

        if (!market.data) {
            throw new Error("Market not found")
        }

        let rounds = await market.data.rounds()
        let thisRound: any = rounds.data.find((item:any) => item.onchainId === Number(roundId) )

        if (!thisRound) { 
            return []
        } else {
            const outcomes = await thisRound.outcomes()
            return outcomes.data
        }
            
    }

    const addOutcome = async ({ marketId, roundId, title, resolutionDate }: any) => {

        // create new round if not exist
        const market = await client.models.Market.get({
            id: marketId
        })

        if (!market.data) {
            throw new Error("Market not found")
        }

        let rounds = await market.data.rounds()
        let thisRound: any = rounds.data.find((item:any) => item.onchainId === Number(roundId) )

        if (!thisRound) { 
            await client.models.Round.create({
                marketId,
                onchainId: Number(roundId)
            })
            rounds = await market.data.rounds()
            thisRound = rounds.data.find((item:any) => item.onchainId === Number(roundId) )
        }

        const outcomes = await thisRound.outcomes()
 
        const maxOutcomeId = outcomes.data.reduce((result: number, item: any) => {
            if (item.onchainId > result) {
                result = item.onchainId
            }
            return result
        }, 0)

        const onchainId = maxOutcomeId + 1

        await client.models.Outcome.create({
            roundId: thisRound.id,
            onchainId,
            title,
            resolutionDate: Math.floor((new Date(resolutionDate)).valueOf() / 1000)
        })

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

    return {
        crawl,
        getProfile,
        getMarkets,
        getResources,
        getMarketsByCreator,
        addOutcome,
        getOutcomes,
        getMarketData
    }
}

export default useDatabase
