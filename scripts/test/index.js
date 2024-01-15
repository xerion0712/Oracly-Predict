const chai = require('chai');
const { ApyReader } = require("../lib");

const { expect } = chai

// const RATES_DATA = require("../lib/Result2.json")

describe('#calculate apy script', function () {

    let reader

    before(function () {
        reader = new ApyReader()
    })

    it('should get rates success ', async () => {

        const rates = await reader.fetchRates()
        // console.log("result : ", JSON.stringify(rates))

        expect(rates.length > 0).to.true
    })

    it('should calculate APY success ', async () => {

        const output = await reader.fetchRates()

        for (let validator of output) {

            const { rates } = validator
            const apy = await reader.calculateApy(rates)

            // console.log("apy output : ", apy)
            expect(0.1 > apy).to.true
        }

        expect(true).to.true

    })

})