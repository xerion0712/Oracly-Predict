
import { generateClient } from "aws-amplify/data";
import FirecrawlApp from '@mendable/firecrawl-js';
import type { Schema } from "../amplify/data/resource"

const FIRECRAWL_API_KEY = process.env.FIRECRAWL_API_KEY || ""

const client = generateClient<Schema>();

const app = new FirecrawlApp({ apiKey: FIRECRAWL_API_KEY });

const useDatabase = () => {

    const getProfile = async (userId: string) => {

        // const user = await client.models.User.list({
        //     filter: {
        //         username: {
        //             eq: userId
        //         }
        //     }
        // })

        // if (user.data.length === 0) {
        //     const newUser = {
        //         username: userId,
        //         credits: 100
        //     }
        //     await client.models.User.create({
        //         ...newUser
        //     })
        //     return newUser
        // } else {
        //     return user.data[0]
        // }
        return undefined
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

    const crawl = async (resource: any) => {

        // let need_update = false

        // if (resource.last_crawled_at === undefined) {
        //     need_update = true
        // } else if ((new Date().valueOf() / 1000) - resource.last_crawled_at > 86400) {
        //     need_update = true
        // }

        // if (need_update) {

        //     const result: any = (await app.scrapeUrl(resource.url, { formats: ['markdown', 'html'] }))

        //     await client.models.Resource.update({
        //         id: resource.id,
        //         last_crawled_at: Math.floor((new Date().valueOf()) / 1000),
        //         crawled_data: result.markdown
        //     })

        // } else {
        //     return resource.crawled_data
        // }
        return undefined
    }

    return {
        crawl,
        getProfile,
        getMarkets,
        getResources,
        getMarketsByCreator
    }
}

export default useDatabase
