
const { SuiClient, getFullnodeUrl } = require("@mysten/sui.js/client")
const BigNumber = require("bignumber.js")

class ApyReader {

  client

  MAX_VALIDATORS = 3

  constructor() {
    this.client = new SuiClient({ url: getFullnodeUrl("mainnet") });
  }

  fetchRates = async () => {

    const summary = await this.client.call("suix_getLatestSuiSystemState")

    const { activeValidators } = summary

    const validators = activeValidators.map(({ stakingPoolId, suiAddress, exchangeRatesId, exchangeRatesSize, name }) => ({ name, stakingPoolId, suiAddress, exchangeRatesId, exchangeRatesSize }))

    let randomIds = [];

    while (randomIds.length < this.MAX_VALIDATORS) {
      const randomId = Math.floor(Math.random() * validators.length);

      if (!randomIds.includes(randomId)) {
        randomIds.push(randomId);
      }
    }

    const randomItems = validators.filter((_, index) => randomIds.includes(index));

    return (await this.findRates(randomItems))
  }

  findRates = async (items) => {
    let output = []

    for (let validator of items) {

      const { name } = validator

      console.log(`reading rates from ${name}`)

      let items = []

      let { data, nextCursor, hasNextPage } = await this.client.call("suix_getDynamicFields", [
        validator.exchangeRatesId
      ])

      items = items.concat(data)

      while (hasNextPage) {

        const response = await this.client.call("suix_getDynamicFields", [
          validator.exchangeRatesId,
          nextCursor
        ])

        hasNextPage = response.hasNextPage
        nextCursor = response.nextCursor

        items = items.concat(response.data)

        hasNextPage = false
      }

      let rates = []

      for (let item of items) {

        const { objectId } = item

        const response = await this.client.call("sui_getObject", [
          objectId,
          {
            "showContent": true
          }
        ])

        const { data } = response
        const { content } = data

        rates.push({
          epoch: Number(content["fields"]["name"]),
          "pool_token_amount": content["fields"]["value"]["fields"]["pool_token_amount"],
          "sui_amount": content["fields"]["value"]["fields"]["sui_amount"]
        })

      }

      output.push({
        name,
        rates: rates.sort(function (a, b) {
          return a.epoch - b.epoch;
        })
      })

      console.log(`reading rates from ${name} - DONE`)

    }

    return output

  }

  calculateApy = async (rates, stakeSubsidyStartEpoch = 20) => {

    let apys = []
    let highestEpoch = 0

    for (let i = 0; i < rates.length; i++) {
      const rate = rates[i]

      const { epoch, pool_token_amount, sui_amount } = rate
      if (epoch > highestEpoch) highestEpoch = epoch

      const rate_e = rates[i - 1]

      if (epoch > stakeSubsidyStartEpoch && sui_amount && rate_e && rate_e.sui_amount) {

        const numerator = BigNumber(sui_amount).dividedBy(BigNumber(pool_token_amount))
        const denominator = BigNumber(rate_e.sui_amount).dividedBy(BigNumber(rate_e.pool_token_amount))

        const result = Number(numerator.dividedBy(denominator).minus(1).multipliedBy(365 / (Number(epoch) - Number(rate_e.epoch))))
        if (result > 0 && result < 0.1) {
          apys.push({
            epoch,
            apy : result
          })
        }

      }

    }

    // const sliced = apys.slice(-30)
    const sliced = apys.filter(item => highestEpoch - 30 < item.epoch).map(item => item.apy)
    return sliced.reduce((a, b) => a + b, 0) / sliced.length;
  }

}

exports.ApyReader = ApyReader