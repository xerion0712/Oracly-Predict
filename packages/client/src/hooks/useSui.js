import { createContext, useCallback, useMemo, useEffect, useReducer } from 'react';
import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';
import BigNumber from "bignumber.js"
import axios from 'axios';
import Vault from "../data/vault.json"

import { TransactionBlock } from '@mysten/sui.js/transactions';

const FALLBACK_SUI_PRICE = 0.8

const useSui = () => {

    const getSuiPrice = async () => {
        let response
        try {
            response = await axios.get('https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?id=20947', {
                headers: {
                    'X-CMC_PRO_API_KEY': process.env.COINMARKETCAP_API
                },
            });
        } catch (ex) {
            response = null;
            // error
            console.log(ex);
        }

        if (response) {
            const { data } = response
            const price = data.data["20947"]["quote"]["USD"]["price"]
            return Number(price)
        } else {
            return FALLBACK_SUI_PRICE
        }
    }

    const fetchSuiSystem = async (network = "mainnet") => {

        const client = new SuiClient({ url: getFullnodeUrl(network) })

        let data = await client.getLatestSuiSystemState()
        let validators = data.activeValidators

        delete data["activeValidators"]

        const { apys } = await client.getValidatorsApy()

        validators = validators.map((item) => {
            const apyItem = apys.find(a => a.address.toLowerCase() === item.suiAddress.toLowerCase())

            const vol = (BigNumber(item.stakingPoolSuiBalance).minus(BigNumber(item.nextEpochStake))).absoluteValue().dividedBy(BigNumber(1000000000))

            return {
                name: item.name,
                description: item.description,
                imageUrl: item.imageUrl,
                projectUrl: item.projectUrl,
                commissionRate: item.commissionRate,
                nextEpochStake: item.nextEpochStake,
                stakingPoolActivationEpoch: item.stakingPoolActivationEpoch,
                stakingPoolSuiBalance: item.stakingPoolSuiBalance,
                suiAddress: item.suiAddress,
                stakingPoolId: item.stakingPoolId,
                vol: `${vol}`,
                apy: apyItem ? Number(apyItem.apy) * 100 : 0
            }
        }).sort((a, b) => (BigNumber(b.stakingPoolSuiBalance)).minus(BigNumber(a.stakingPoolSuiBalance)))

        return {
            summary: data,
            avgApy: validators.map(item => Number(item.apy)).reduce((a, b) => a + b, 0) / validators.length, // TODO: Whitelisting validators
            validators
        }

    }

    const fetchAllVault = async (networkName, summary, suiPrice) => {

        const vaultList = Vault.filter(item => item.id !== 1).filter(item => networkName === "testnet" ? item.network === "testnet" : item.network !== "testnet")

        const client = new SuiClient({ url: getFullnodeUrl(networkName) })

        let output = []

        for (let vault of vaultList) {
            const { name, image, value, network, disabled } = vault

            if (disabled) {
                output.push({
                    name,
                    image,
                    value,
                    network,
                    disabled
                })
            } else {

                const { vaultId } = vault

                const { data } = await client.getObject({
                    id: vaultId,
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

                let { fields } = data.content

                delete fields.id
 
                output.push({
                    name,
                    image,
                    value: `$${(Number(`${(BigNumber(fields.principal_balance).plus(BigNumber(fields.debt_balance)).dividedBy(BigNumber(1000000000)).toFixed(2))}`) * suiPrice).toFixed(2)}`,
                    network,
                    disabled,
                    ...fields
                })
            }

        }

        return output
    }

    const getCurrentEpoch = async (networkName) => {
        const client = new SuiClient({ url: getFullnodeUrl(networkName) })
        const { epoch } = await client.call('suix_getLatestSuiSystemState', [])
        return epoch
    }

    return {
        getSuiPrice,
        fetchSuiSystem,
        fetchAllVault,
        getCurrentEpoch
    }

}

export default useSui