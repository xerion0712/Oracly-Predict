import { useCallback } from "react"
import { useWallet } from '@suiet/wallet-kit'
import BigNumber from "bignumber.js"

import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';

import { TransactionBlock } from '@mysten/sui.js/transactions';

import { SUI_SYSTEM_STATE, SUI_SYSTEM } from '@/constants';
import useSui from "./useSui";



const useSuiStake = () => {

    const wallet = useWallet()
    const { connected, account } = wallet

    const { getSuiPrice } = useSui()

    const stake = useCallback(async (validatorAddress, amount) => {

        if (!connected) {
            return
        }

        const tx = new TransactionBlock();
        const packageObjectId = SUI_SYSTEM

        const [coin] = tx.splitCoins(tx.gas, [tx.pure(BigNumber(amount).multipliedBy(10 ** 9))]);

        tx.moveCall({
            target: `${packageObjectId}::sui_system::request_add_stake`,
            arguments: [tx.pure(SUI_SYSTEM_STATE), coin, tx.pure(validatorAddress)],
        });

        // tx.transferObjects([coin], tx.pure(account.address));

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected])

    const getStake = useCallback(async (address, isTestnet = false) => {
        const suiClient = new SuiClient({ url: getFullnodeUrl(isTestnet ? "testnet" : "mainnet") });

        const data = await suiClient.getStakes({
            owner: address
        })

        return data
    }, [])

    const getTotalStaked = useCallback(async (address, isTestnet = false) => {
        const suiClient = new SuiClient({ url: getFullnodeUrl(isTestnet ? "testnet" : "mainnet") });

        const data = await suiClient.getStakes({
            owner: address
        })

        let totalStaked = BigNumber(0)
        let totalPending = BigNumber(0)

        for (let val of data) {
            for (let stake of val.stakes) {
                if (stake.status.toLowerCase() === "active") {
                    totalStaked = totalStaked.plus(BigNumber(stake.principal)).plus(BigNumber(stake.estimatedReward))
                } else {
                    totalPending = totalPending.plus(BigNumber(stake.principal))
                }
            }
        }

        const suiPrice = await getSuiPrice()

        return {
            suiPrice,
            totalStaked,
            totalPending
        }

    }, [])

    return {
        stake,
        getStake,
        getTotalStaked
    }
}

export default useSuiStake