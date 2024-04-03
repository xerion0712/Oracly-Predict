const { SuiClient, getFullnodeUrl } = require("@mysten/sui.js/client")
const fs = require('node:fs')
const { v4: uuidv4 } = require('uuid')

// Function print out unstaking assets to .txt file
async function printUnstakeObjects() {

    const client = new SuiClient({ url: getFullnodeUrl("mainnet") });

    let items = []

    let { data, nextCursor, hasNextPage } = await client.call("suix_queryEvents",
        [
            {
                "MoveEventType": "0x3::validator::UnstakingRequestEvent"
            },
            null,
            50,
            true
        ])

    items = items.concat(data)

    try {
        while (hasNextPage) {
            const response = await client.call("suix_queryEvents", [
                {
                    "MoveEventType": "0x3::validator::UnstakingRequestEvent"
                },
                nextCursor,
                50,
                true
            ])

            hasNextPage = response.hasNextPage
            nextCursor = response.nextCursor

            items = items.concat(response.data)

            console.log("here...", items.length)

        }
    } catch (e) {
        console.log("error :", items[items.length-1])
    }

    try {
        fs.writeFileSync(`unstake-data-${(new Date()).valueOf()}.json`, JSON.stringify(items.map((item) => ({ ...item.parsedJson, stake_epoch: Number(item.parsedJson.stake_activation_epoch), object_id: uuidv4() }))));
    } catch (err) {
        console.log(err);
    }

}


printUnstakeObjects()