const AWS = require("aws-sdk");
const aws = require("@pulumi/aws");
const awsx = require("@pulumi/awsx");

const headers = {
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
}


const getPriceById = async (event, tableName) => {

    const route = event.pathParameters["tokenId"]

    console.log(`Incoming tokenId '${route}'`)

    const client = new AWS.DynamoDB.DocumentClient();

    try {

        const params = {
            TableName: tableName,
            Key: {
                "key": "token",
                "value": route
            }
        }

        const { Item } = await client.get(params).promise()

        return {
            statusCode: 200,
            headers: headers,
            body: JSON.stringify({
                status: "ok",
                prices: Item && Item.prices ? Item.prices : {}
            })
        }
    } catch (error) {
        return {
            statusCode: 400,
            headers: headers,
            body: JSON.stringify({
                status: "error",
                message: `${error.message || "Unknown error."}`
            }),
        };
    }
}

exports.getPriceById = getPriceById