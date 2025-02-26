
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

    const getMyPositions = async (userId: string, marketId: string) => {
        const positions = await client.models.Position.list({
            filter: {
                userId: {
                    eq: userId
                },
                marketId: {
                    eq: marketId
                }
            }
        })
        return positions.data
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

    const getOutcomeById = async (outcomeId: number) => {
        const outcomes = await client.models.Outcome.list({
            filter: {
                onchainId: {
                    eq: outcomeId
                }
            }
        })
        return outcomes && outcomes.data[0] ? outcomes.data[0] : undefined
    }

    const getOutcomes = async (marketId: string, roundId: number) => {

        const market = await client.models.Market.get({
            id: marketId
        })

        if (!market.data) {
            throw new Error("Market not found")
        }

        let rounds = await market.data.rounds()
        let thisRound: any = rounds.data.find((item: any) => item.onchainId === Number(roundId))

        if (!thisRound) {
            return []
        } else {
            const outcomes = await thisRound.outcomes()
            return outcomes.data
        }

    }

    const getAllOutcomes = async () => {

        const markets = await client.models.Market.list()


        let output: any = []

        for (let market of markets.data) {
            let rounds = await market.rounds()
            for (let round of rounds.data) {
                const outcomes = await round.outcomes()
                output = output.concat(outcomes.data)
            }
        }


        if (output.length <= 8) return output;
        return output.sort(() => 0.5 - Math.random()).slice(0, 8);
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
        let thisRound: any = rounds.data.find((item: any) => item.onchainId === Number(roundId))

        if (!thisRound) {
            await client.models.Round.create({
                marketId,
                onchainId: Number(roundId)
            })
            rounds = await market.data.rounds()
            thisRound = rounds.data.find((item: any) => item.onchainId === Number(roundId))
        }

        const outcomes = await client.models.Outcome.list()

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

    const updateOutcomeWeight = async ({ marketId, roundId, weights }: any) => {

        const market = await client.models.Market.get({
            id: marketId
        })

        if (!market.data) {
            throw new Error("Market not found")
        }

        const rounds = await market.data.rounds()
        const thisRound: any = rounds.data.find((item: any) => item.onchainId === Number(roundId))

        const outcomes = await thisRound.outcomes()

        for (let outcome of outcomes.data) {

            const currentOutcome = weights.find((item: any) => item.outcomeId === outcome.onchainId)
            const weight = currentOutcome.outcomeWeight

            console.log("updating..", outcome.id, weight)

            await client.models.Outcome.update({
                id: outcome.id,
                weight
            })

        }

        const lastWeightUpdatedAt = Math.floor((new Date().valueOf()) / 1000)

        await client.models.Round.update({
            id: thisRound.id,
            lastWeightUpdatedAt
        })
    }

    // const finalizeWeights = async (roundId: number) => {

    //     const market: any = await getMarketData(1)
    //     const rounds: any = await market.rounds()

    //     for (let round of rounds.data) {
    //         if (roundId > round.onchainId) {
    //             if (!round.finalizedTimestamp) {

    //                 const { data } = await round.outcomes()
    //                 const outcomes = data.sort((a: any, b: any) => {
    //                     return a.onchainId - b.onchainId
    //                 })

    //                 let outcomeIds = []
    //                 let outcomeWeights = []

    //                 for (let outcome of outcomes) {

    //                     if (outcome.onchainId && outcome.weight) {
    //                         const outcomeId = outcome.onchainId
    //                         const outcomeWeight = outcome.weight

    //                         outcomeIds.push(outcomeId)
    //                         outcomeWeights.push(outcomeWeight*100)
    //                     }

    //                 }

    //                 // update weights


    //             }
    //         }


    //     }

    // }

    const addPosition = async ({ marketId, userId, roundId, outcomeId, amount, walletAddress }: any) => {

        const positions = await client.models.Position.list()

        const maxPositionId = positions.data.reduce((result: number, item: any) => {
            if (item.onchainId > result) {
                result = item.onchainId
            }
            return result
        }, 0)

        const onchainId = maxPositionId

        await client.models.Position.create({
            marketId,
            userId,
            roundId,
            onchainId,
            predictedOutcome: outcomeId,
            betAmount: amount,
            walletAddress
        })

    }

    const increaseOutcomeBetAmount = async ({ marketId, roundId, outcomeId, amount }: any) => {

        const market = await client.models.Market.get({
            id: marketId
        })

        if (!market.data) {
            throw new Error("Market not found")
        }

        let rounds = await market.data.rounds()
        let thisRound: any = rounds.data.find((item: any) => item.onchainId === Number(roundId))

        const outcomes = await thisRound.outcomes()

        const outcome = outcomes.data.find((item: any) => item.onchainId === outcomeId)

        await client.models.Outcome.update({
            id: outcome.id,
            totalBetAmount: outcome.totalBetAmount + amount
        })

        await client.models.Market.update({
            id: marketId,
            betPoolAmount: market.data.betPoolAmount + amount
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
        getMarketData,
        addPosition,
        increaseOutcomeBetAmount,
        getMyPositions,
        updateOutcomeWeight,
        getAllOutcomes,
        getOutcomeById
        // finalizeWeights
    }
}

export default useDatabase
