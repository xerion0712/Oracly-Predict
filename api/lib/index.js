require('dotenv').config()

const axios = require('axios')
const TOKENS = [
    {
        "coinType": "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
        "coinId" : "sui"
    }
]
const VAULTS = [
    {
        "network": "testnet",
        "vaultType": "0x61bc3f475d97acf87194fbef1241737af5e8d34e73e5a75fe040fb5dcdc78421::vault::VAULT",
        "ammGlobal": "0x75b41ba12f51e1b568d0ee536a1f31beb608687424fe2daf497ebb3fc176b0b5"
    },
    {
        "network": "testnet",
        "vaultType": "0x61bc3f475d97acf87194fbef1241737af5e8d34e73e5a75fe040fb5dcdc78421::vault_template::APR_2024",
        "ammGlobal": "0x75b41ba12f51e1b568d0ee536a1f31beb608687424fe2daf497ebb3fc176b0b5"
    },
    {
        "network": "testnet",
        "vaultType": "0x61bc3f475d97acf87194fbef1241737af5e8d34e73e5a75fe040fb5dcdc78421::vault_template::JUN_2024",
        "ammGlobal": "0x75b41ba12f51e1b568d0ee536a1f31beb608687424fe2daf497ebb3fc176b0b5"
    }
]

const BigNumber = require("bignumber.js")



const getVaultTokenPrices = async (network = "testnet") => {


    const { SuiClient, getFullnodeUrl } = require("@mysten/sui.js/client")
    require('whatwg-fetch')
    global.fetch = require('node-fetch')
    global.XMLHttpRequest = require('xhr2')

    let output = []

    const vaultList = VAULTS.filter(item => network === item.network)

    const { ammGlobal } = vaultList[0]

    const client = new SuiClient({ url: getFullnodeUrl(network) })

    const { data } = await client.getObject({
        id: ammGlobal,
        options: {
            "showType": false,
            "showOwner": false,
            "showPreviousTransaction": false,
            "showDisplay": false,
            "showContent": true,
            "showBcs": false,
            "showStorageRebate": false
        }
    })

    const content = data.content

    if (!content) {
        return output
    }

    const tableId = content.fields.pools.fields.id.id

    const dynamicFieldPage = await client.getDynamicFields({ parentId: tableId })

    for (let vault of vaultList) {

        const { vaultType } = vault
        const pool = dynamicFieldPage.data.find((item) => item.objectType.includes(vaultType))

        const result = await client.getObject({
            id: pool.objectId,
            options: {
                "showType": false,
                "showOwner": false,
                "showPreviousTransaction": false,
                "showDisplay": false,
                "showContent": true,
                "showBcs": false,
                "showStorageRebate": false
            }
        })

        const pool_name = result.data.content.fields.name.split("-")

        let price

        if (pool_name[1].includes("usdc")) {
            // x is usdc
            const coin_x_amount = BigNumber(result.data.content.fields.value.fields.coin_x).dividedBy(10 ** 6)
            const coin_y_amount = BigNumber(result.data.content.fields.value.fields.coin_y).dividedBy(10 ** 9)
            price = Number(coin_x_amount.dividedBy(coin_y_amount))

        } else {
            // y is usdc
            const coin_y_amount = BigNumber(result.data.content.fields.value.fields.coin_y).dividedBy(10 ** 6)
            const coin_x_amount = BigNumber(result.data.content.fields.value.fields.coin_x).dividedBy(10 ** 9)
            price = Number(coin_y_amount.dividedBy(coin_x_amount))
        }

        let coinId

        if (vaultType.includes("vault_template::")) {
            coinId = `pt-${vaultType.split("vault_template::")[1].toLowerCase()}`
        }

        if (vaultType.includes("vault::VAULT")) {
            coinId = "yt"
        }

        if (network === "testnet") {
            coinId = `${coinId}-testnet`
        }

        output.push({
            coinId,
            coinType: vaultType,
            price
        })

    }


    return output
}

const getTokenPrices = async () => {
    let output = []
    for (let token of TOKENS) {

        const { coinId, coinType } = token

        const { data } = await axios.get(`https://api.coingecko.com/api/v3/simple/price?ids=${coinId}&vs_currencies=usd`, {
            headers: {
                "x-cg-pro-api-key": process.env.COINGECKO_API
            }
        })

        const price = data[coinId]["usd"]

        output.push({
            coinId,
            coinType,
            price
        })
    }
    return output
}

exports.getVaultTokenPrices = getVaultTokenPrices

exports.getTokenPrices = getTokenPrices