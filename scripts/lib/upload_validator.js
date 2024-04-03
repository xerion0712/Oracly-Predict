
const fs = require('node:fs')
const AWS = require("aws-sdk")

AWS.config.update({ region: 'ap-southeast-1' })

const TableName = "legatoSuiValidatorTable-50039f8"

const FileName = '../validator-data-1712029334331.json'

async function uploadValidatorData() {

    try {
        const data = fs.readFileSync(FileName , 'utf8')
        const json = JSON.parse(data)

        const client = new AWS.DynamoDB.DocumentClient()

        for (let entry of json) {

            console.log("putting validator / epoch : ", entry.validator_address, entry.epoch)

            await client.put({ TableName, Item: entry }).promise();

            console.log("putting validator / epoch : ", entry.validator_address, entry.epoch, " - DONE")

        }


    } catch (err) {
        console.error(err);
    }

}

uploadValidatorData()