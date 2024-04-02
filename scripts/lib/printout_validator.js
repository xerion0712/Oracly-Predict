
const { SuiClient, getFullnodeUrl } = require("@mysten/sui.js/client")
// const BigNumber = require("bignumber.js")
const fs = require('node:fs')

// Function print out validator data to .txt file
async function printValidatorData() {

    const client = new SuiClient({ url: getFullnodeUrl("mainnet") });

    let items = []

    let { data, nextCursor, hasNextPage } = await client.call("suix_queryEvents",
        [
            {
                "MoveEventType": "0x3::validator_set::ValidatorEpochInfoEventV2"
            }
        ])

    items = items.concat(data)

    while (hasNextPage) {

        const response = await client.call("suix_queryEvents", [
            {
                "MoveEventType": "0x3::validator_set::ValidatorEpochInfoEventV2"
            },
            nextCursor
        ])

        hasNextPage = response.hasNextPage
        nextCursor = response.nextCursor

        items = items.concat(response.data)

    }

    try {
        fs.writeFileSync(`validator-data-${(new Date()).valueOf()}`, JSON.stringify(items.map((item) => ({ ...item.parsedJson }))));
    } catch (err) {
        console.log(err);
    }

}

// Call the function to print out the validator data
printValidatorData();