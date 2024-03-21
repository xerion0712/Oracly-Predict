"use strict";

const AWS = require("aws-sdk");
const pulumi = require("@pulumi/pulumi");
const aws = require("@pulumi/aws");
const awsx = require("@pulumi/awsx");

const { getPriceById } = require("./routes")
const { getTokenPrices, getVaultTokenPrices } = require("./lib/index.js")

// Assets table
const legatoTable = new aws.dynamodb.Table(
    "legatoTable",
    {
        attributes: [
            {
                name: "key",
                type: "S"
            },
            {
                name: "value",
                type: "S"
            }
        ],
        hashKey: "key",
        rangeKey: "value",
        billingMode: "PAY_PER_REQUEST"
    }
)

// API endpoints
const endpoint = new awsx.classic.apigateway.API(`legato-api`, {
    routes: [
        {
            path: "/price/{tokenId+}",
            method: "GET",
            eventHandler: async (event) => await getPriceById(event, legatoTable.name.get())
        }
    ]
})


// token prices bot
const tokensBot = async (event) => {

    const tableName = legatoTable.name.get()
    const client = new AWS.DynamoDB.DocumentClient()

    const tokens = await getTokenPrices()

    for (let token of tokens) {

        const { coinId, price } = token

        const params = {
            TableName: tableName,
            Key: {
                "key": "token",
                "value": coinId
            }
        };

        let { Item } = await client.get(params).promise()
        if (!Item) {

            let prices = {}
            let currentDate = new Date()

            currentDate.setUTCHours(0)
            currentDate.setUTCMinutes(0)
            currentDate.setUTCSeconds(0)
            currentDate.setUTCMilliseconds(0)

            prices[currentDate.valueOf()] = price

            const NewItem = {
                key: "token",
                value: coinId,
                prices
            }
            console.log("Saving New Item : ", NewItem)
            await client.put({ TableName: tableName, Item: NewItem }).promise();
        } else {

            let currentDate = new Date()

            currentDate.setUTCHours(0)
            currentDate.setUTCMinutes(0)
            currentDate.setUTCSeconds(0)
            currentDate.setUTCMilliseconds(0)

            Item.prices[currentDate.valueOf()] = price

            console.log("Saving Existing Item : ", Item)
            await client.put({ TableName: tableName, Item: Item }).promise();
        }

    }

}


// vault token prices bot
const vaultTokensBot = async (event) => {

    const tableName = legatoTable.name.get()
    const client = new AWS.DynamoDB.DocumentClient()

    const tokens = (await getVaultTokenPrices("testnet")).concat(await getVaultTokenPrices("mainnet"))

    for (let token of tokens) {

        const { coinId, price } = token

        const params = {
            TableName: tableName,                                       
            Key: {
                "key": "token",
                "value": coinId                                                                         
            }               
        };

        let { Item } = await client.get(params).promise()
        if (!Item) {

            let prices = {}
            let currentDate = new Date()

            currentDate.setUTCHours(0)
            currentDate.setUTCMinutes(0)                    
            currentDate.setUTCSeconds(0)
            currentDate.setUTCMilliseconds(0)

            prices[currentDate.valueOf()] = price

            const NewItem = {
                key: "token",
                value: coinId,
                prices
            }
            console.log("Saving New Item : ", NewItem)
            await client.put({ TableName: tableName, Item: NewItem }).promise();
        } else {

            let currentDate = new Date()

            currentDate.setUTCHours(0)
            currentDate.setUTCMinutes(0)
            currentDate.setUTCSeconds(0)
            currentDate.setUTCMilliseconds(0)

            Item.prices[currentDate.valueOf()] = price

            console.log("Saving Existing Item : ", Item)
            await client.put({ TableName: tableName, Item: Item }).promise();
        }

    }

}

const tokensBotScheduler = new aws.cloudwatch.onSchedule(
    "tokensBotScheduler",
    "rate(12 hours)",
    tokensBot,
);

const vaultTokensBotScheduler = new aws.cloudwatch.onSchedule(
    "vaultTokensBotScheduler",
    "rate(12 hours)",
    vaultTokensBot,
);


exports.endpoint = endpoint.url