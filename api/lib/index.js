require('dotenv').config()

const axios = require('axios')
const TOKENS = require("./token.json")


const getTest = async () => {
    return "hello"
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

exports.getTest = getTest

exports.getTokenPrices = getTokenPrices