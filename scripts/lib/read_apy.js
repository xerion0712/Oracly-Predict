const fs = require('node:fs')
const BigNumber = require("bignumber.js")
const FileName = '../validator-data-1712029334331.json'

async function readApy() {

    try {
        const data = fs.readFileSync(FileName, 'utf8')
        const json = JSON.parse(data)

        // check how many epochs there
        let epochs = []
        json.map((item) => {
            if (!epochs.includes(item.epoch)) {
                epochs.push(item.epoch)
            }
        })
        // ignores first 30 epochs
        epochs = epochs.slice(30, epochs.length)

        let output = []

        // check APY for each validator on each epoch
        for (let epoch of epochs) {

            const validator_list = json.filter(item => item.epoch === epoch)

            let entry = {
                epoch,
                avg_apy: 0,
                validator_apy: []
            }

            let total = 0

            for (let validator of validator_list) {

                const { pool_token_amount, sui_amount } = validator.pool_token_exchange_rate
                let previousEpoch = 1;
                let sameValidatorRecentEpoch;

                while (previousEpoch <= 20) {
                    sameValidatorRecentEpoch = json.find(item => item.epoch === (epoch - previousEpoch) && item.validator_address === validator.validator_address);
                    if (sameValidatorRecentEpoch !== undefined) {
                        break;
                    }
                    previousEpoch++;
                }

                if (sameValidatorRecentEpoch) {
                    const numerator = BigNumber(sui_amount).dividedBy(BigNumber(pool_token_amount))
                    const denominator = BigNumber(sameValidatorRecentEpoch.pool_token_exchange_rate.sui_amount).dividedBy(BigNumber(sameValidatorRecentEpoch.pool_token_exchange_rate.pool_token_amount))

                    const result = Number(numerator.dividedBy(denominator).minus(1).multipliedBy(365 / (Number(epoch) - Number(sameValidatorRecentEpoch.epoch))))

                    if (result > 0 && result < 0.1) {
                        total += result
                        entry.validator_apy.push({
                            validator_address: validator.validator_address,
                            apy: result
                        })
                    }
                }

            }

            entry.avg_apy = total / entry.validator_apy.length

            output.push(entry)

            console.log("EPOCH : ", epoch, " DONE - APY : ", entry.avg_apy)

        }

        try {
            fs.writeFileSync(`../apy-data-${(new Date()).valueOf()}.json`, JSON.stringify(output));
        } catch (err) {
            console.log(err);
        }

    } catch (err) {
        console.error(err);
    }

}

readApy()