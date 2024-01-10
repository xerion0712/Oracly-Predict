import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useState } from "react"
import MARKET from "../data/market.json"
import VAULT from "../data/vault.json"
import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';
import { TransactionBlock, Inputs } from '@mysten/sui.js/transactions'; 
import { useWallet } from "@suiet/wallet-kit";
import BigNumber from "bignumber.js"

export const LegatoContext = createContext()

const Provider = ({ children }) => {

    const wallet = useWallet()
    const { connected } = wallet

    const [values, dispatch] = useReducer(
        (curVal, newVal) => ({ ...curVal, ...newVal }),
        {
            market: MARKET.SUI_TO_STAKED_SUI,
            validators: [],
            avgApy: 0,
            isTestnet: false,
            vaults: [],
            summary: undefined
        }
    )

    const { market, validators, avgApy, isTestnet, vaults, summary } = values

    const updateMarket = (key) => {
        dispatch({ market: MARKET[key] })
    }

    const updateValues = (values) => {
        dispatch({ ...values })
    }

    const mint = useCallback(async (vault, amount, selectedObject) => {

        if (!connected) {
            return
        }

        const { packageId, vaultType, vaultId, suiSystemStateId } = VAULT.find(item => item.name === vault.name)
        const { stakedSuiId } = selectedObject

        const tx = new TransactionBlock()

        if (selectedObject.principal === `${(BigNumber(amount)).multipliedBy(BigNumber(10 ** 9))}`) {
            // input amount equals Staked SUI object values

            tx.moveCall({
                typeArguments: [vaultType],
                target: `${packageId}::vault::mint`,
                arguments: [
                    tx.pure(suiSystemStateId),
                    tx.pure(`${vaultId}`),
                    tx.pure(`${stakedSuiId}`)
                ]
            })

            await wallet.signAndExecuteTransactionBlock({
                transactionBlock: tx
            });

        } else {

            if (Number((BigNumber(selectedObject.principal)).dividedBy(BigNumber(10 ** 9)).minus(BigNumber(amount))) < 1) {
                throw new Error("The post-split value must be more than 1")
            }

            // splitting to new object
            const [splited_staked_sui] = tx.moveCall({
                target: `0x3::staking_pool::split`,
                arguments: [
                    tx.pure(stakedSuiId),
                    tx.pure(`${(BigNumber(amount)).multipliedBy(BigNumber(10 ** 9))}`)
                ]
            })

            tx.moveCall({
                typeArguments: [vaultType],
                target: `${packageId}::vault::mint`,
                arguments: [
                    tx.pure(suiSystemStateId),
                    tx.pure(`${vaultId}`),
                    splited_staked_sui
                ]
            })

            await wallet.signAndExecuteTransactionBlock({
                transactionBlock: tx
            });

        }

    }, [connected])


    const swap = useCallback(async (baseCurrency, pairCurrency, amount, isTestnet = false) => {

        if (!connected) {
            return
        }

        const { symbol } = baseCurrency

        if (symbol === "SUI") {
            const { vaultId } = pairCurrency
            const { ammId, packageId, vaultType } = VAULT.find(item => item.id === vaultId)

            await suiToYT(packageId, vaultType, ammId, amount)
        } else if (symbol.includes("yt")) {
            const { vaultId } = baseCurrency
            const { ammId, packageId, vaultType } = VAULT.find(item => item.id === vaultId)

            await ytToSui(packageId, vaultType, ammId, amount, isTestnet)
        }

    }, [connected])

    const suiToYT = useCallback(async (packageId, vaultType, ammId, amount) => {

        const tx = new TransactionBlock()

        const [coin] = tx.splitCoins(tx.gas, [tx.pure((amount) * 1000000000)]);

        tx.moveCall({
            typeArguments: [
                "0x2::sui::SUI",
                `${packageId}::vault::TOKEN<${vaultType}, ${packageId}::vault::YT>`
            ],
            target: `${packageId}::amm::swap_out`,
            arguments: [
                tx.pure(ammId),
                coin,
                tx.pure(1),
                tx.pure(true)
            ]
        })

        await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected])

    const ytToSui = useCallback(async (packageId, vaultType, ammId, amount, isTestnet) => {

        const allYT = await getTotalYT(wallet.account.address, isTestnet)

        const ytObject = allYT.find(item => Number(amount) <= Number(BigNumber(item.balance).dividedBy(BigNumber(10 ** 9))))
        if (ytObject) {
            const { objectId } = ytObject

            const tx = new TransactionBlock()

            // splitting to new object
            const [splited_coin] = tx.moveCall({
                typeArguments: [
                    `${packageId}::vault::TOKEN<${vaultType}, ${packageId}::vault::YT>`
                ],
                target: `0x2::coin::split`,
                arguments: [
                    tx.pure(objectId),
                    tx.pure(`${(BigNumber(amount)).multipliedBy(BigNumber(10 ** 9))}`)
                ]
            })

            tx.moveCall({
                typeArguments: [
                    `${packageId}::vault::TOKEN<${vaultType}, ${packageId}::vault::YT>`,
                    "0x2::sui::SUI"
                ],
                target: `${packageId}::amm::swap_out`,
                arguments: [
                    tx.pure(ammId),
                    splited_coin,
                    tx.pure(1),
                    tx.pure(false)
                ]
            })


            await wallet.signAndExecuteTransactionBlock({
                transactionBlock: tx
            });

        } else {
            throw new Error("Invalid amount")
        }


    }, [connected, wallet])

    const getTotalPT = useCallback(async (address, isTestnet = false) => {

        const suiClient = new SuiClient({ url: getFullnodeUrl(isTestnet ? "testnet" : "mainnet") })

        const vaultList = VAULT.filter(item => !item.disabled && item.network === (isTestnet ? "testnet" : "mainnet"));

        const objects = await Promise.all(
            vaultList.map(async (vault) => {
                const { vaultType, packageId } = vault;
                const StructType = `0x2::coin::Coin<${packageId}::vault::TOKEN<${vaultType},${packageId}::vault::PT>>`;
                const { data } = await suiClient.call("suix_getOwnedObjects", [
                    address,
                    {
                        "filter": {
                            "MatchAll": [
                                {
                                    "StructType": StructType
                                }
                            ]
                        },
                        "options": {
                            "showContent": true
                        }
                    }
                ]);

                return data.map(({ data }) => ({
                    vault: vault.name,
                    digest: data.digest,
                    objectId: data.objectId,
                    version: data.version,
                    balance: data.content.fields.balance
                }));
            })
        ).then((results) => [].concat(...results));

        return objects
    }, [])

    const getTotalYT = useCallback(async (address, isTestnet = false) => {

        const suiClient = new SuiClient({ url: getFullnodeUrl(isTestnet ? "testnet" : "mainnet") })

        const vaultList = VAULT.filter(item => !item.disabled && item.network === (isTestnet ? "testnet" : "mainnet"));

        const objects = await Promise.all(
            vaultList.map(async (vault) => {
                const { vaultType, packageId } = vault;
                const StructType = `0x2::coin::Coin<${packageId}::vault::TOKEN<${vaultType},${packageId}::vault::YT>>`;
                const { data } = await suiClient.call("suix_getOwnedObjects", [
                    address,
                    {
                        "filter": {
                            "MatchAll": [
                                {
                                    "StructType": StructType
                                }
                            ]
                        },
                        "options": {
                            "showContent": true
                        }
                    }
                ]);

                return data.map(({ data }) => ({
                    vault: vault.name,
                    digest: data.digest,
                    objectId: data.objectId,
                    version: data.version,
                    balance: data.content.fields.balance
                }));
            })
        ).then((results) => [].concat(...results));

        return objects

    }, [])

    const claim = useCallback(async (vaultName, objectId, digest, version) => {

        if (!connected) {
            return
        }

        const { packageId, vaultType, vaultId, suiSystemStateId, ammId } = VAULT.find(item => item.name === vaultName)
        
        const tx = new TransactionBlock()

        // console.log("version --> ", version)
        // console.log("packageId --> ", packageId)
        // console.log("vaultType --> ", vaultType)
        // console.log("ammId --> ", ammId)

        tx.moveCall({
            typeArguments: [vaultType],
            target: `${packageId}::vault::claim`,
            arguments: [
                tx.pure(suiSystemStateId),
                tx.pure(vaultId),
                tx.pure(ammId),
                tx.object(Inputs.ObjectRef({
                    objectId,
                    digest,
                    version
                }))
            ]
        })

        await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        })

    }, [connected])

    const legatoContext = useMemo(
        () => ({
            market,
            currentMarket: Object.keys(MARKET).find(item => MARKET[item] === market),
            updateMarket,
            validators,
            avgApy,
            isTestnet,
            updateValues,
            vaults,
            summary,
            mint,
            getTotalPT,
            getTotalYT,
            swap,
            claim
        }),
        [
            market,
            validators,
            vaults,
            avgApy,
            isTestnet,
            summary,
            mint,
            swap,
            claim
        ]
    )

    return (
        <LegatoContext.Provider value={legatoContext}>
            {children}
        </LegatoContext.Provider>
    )
}

export default Provider