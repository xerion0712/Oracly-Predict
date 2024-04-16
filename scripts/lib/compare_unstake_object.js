const fs = require('node:fs')
const BigNumber = require("bignumber.js")

const ApyFileName = '../apy-data-1712135927322.json'

const UnstakeFileName = "../unstake-data-1712125046627.json"

// compares actual APY from individual assets against validator entries

async function compareApy() {

    try {
        const apyData = fs.readFileSync(ApyFileName, 'utf8')
        const jsonApy = JSON.parse(apyData)

        const assetData = fs.readFileSync(UnstakeFileName, 'utf8')
        const jsonAsset = JSON.parse(assetData)

        let output = []

        for (let asset of jsonAsset) {
            const { object_id, validator_address, principal_amount, reward_amount, stake_epoch, unstaking_epoch } = asset

            const forPeriod = Number(unstaking_epoch) - Number(stake_epoch)
            const rewardForYear = (BigNumber(reward_amount).multipliedBy(BigNumber(365))).dividedBy(BigNumber(forPeriod))

            let actualApy = (BigNumber(principal_amount).plus(BigNumber(rewardForYear))).dividedBy(principal_amount)
            const epoch_apy = jsonApy.find(item => item.epoch === stake_epoch)

            if (Number(actualApy) > 1 && epoch_apy) {
                actualApy = Number(actualApy) - 1

                const validator_apy = epoch_apy.validator_apy.find(item => item.validator_address === validator_address)
                if (validator_apy) {
                    const { apy } = validator_apy
                    output.push({
                        object_id,
                        validator_address,
                        principal_amount: Number(BigNumber(principal_amount).dividedBy(10 ** 9)),
                        reward_amount: Number(BigNumber(reward_amount).dividedBy(10 ** 9)),
                        stake_epoch,
                        unstaking_epoch: Number(unstaking_epoch),
                        actualApy,
                        estimatedApy: apy
                    })
                }
            }
        }

        try {
            fs.writeFileSync(`../compare-data-${(new Date()).valueOf()}.json`, JSON.stringify(output));
        } catch (err) {
            console.log(err);
        }

    } catch (err) {
        console.error(err);
    }

}

compareApy()