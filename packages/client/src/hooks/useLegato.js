
import { useWallet } from '@suiet/wallet-kit'
import { useCallback } from 'react';
import { PACKAGE_ID, TREASURY_CAP, RESERVE, MARKETPLACE, TYPE } from '@/constants';
import { Ed25519Keypair, JsonRpcProvider, testnetConnection, RawSigner, TransactionBlock } from '@mysten/sui.js';
import { useEffect, useState } from 'react';

const useLegato = () => {

    const wallet = useWallet();

    const provider = new JsonRpcProvider(testnetConnection);

    const { connected, account } = wallet

    // useEffect(() => {
    //     if (!wallet.connected) return;
    //     setCorrectedChain(wallet.chain.id === "sui:testnet" ? true : false)
    // }, [wallet.connected])

    const correctedChain = wallet && wallet.connected && wallet.chain.id === "sui:testnet" ? true : false

    const faucet = useCallback(async (amount) => {

        if (!connected) {
            return
        }

        const tx = new TransactionBlock();
        const packageObjectId = PACKAGE_ID

        const [coin] = tx.splitCoins(tx.gas, [tx.pure(Number(amount) * 1000000000)]);
        tx.moveCall({
            target: `${packageObjectId}::staked_sui::wrap`,
            arguments: [tx.pure(Number(amount) * 1000000000), coin],
        });
        tx.transferObjects([coin], tx.pure(account.address));

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet, account, provider])

    const getSuiBalance = useCallback(async (address) => {

        // const packageObjectId = PACKAGE_ID
        const coins = await provider.getBalance({
            owner: address,
            coinType: `0x2::sui::SUI`,
        });

        //FIXME : use bn
        return `${(Number(coins.totalBalance) / 1000000000).toFixed(2)}`

    }, [])

    const getStakedSui = useCallback(async (address) => {

        console.log("get all staked SUI for :", address)

        const coins = await provider.getOwnedObjects({
            owner: address
        });

        const objects = await provider.multiGetObjects({
            ids: coins && coins.data ? coins.data.map(item => item.data.objectId) : [],
            // only fetch the object type
            options: { showType: true, showContent: true },
        });

        return objects.filter(item => item.data.type && item.data.type.includes("staked_sui::StakedSui"))
    }, [])

    const getAllVaultTokens = useCallback(async (address) => {

        console.log("get all vault tokens for :", address)

        const packageObjectId = PACKAGE_ID

        // coin::Coin<0x89b77424c9514f64537f83ae5e260286ee08f03bbc723cf1cc15c601cea9fb8d::vault::PT<0x89b77424c9514f64537f83ae5e260286ee08f03bbc723cf1cc15c601cea9fb8d::staked_sui::STAKED_SUI>>

        const coins = await provider.getCoins({
            owner: address,
            coinType: `${packageObjectId}::vault::PT<0x89b77424c9514f64537f83ae5e260286ee08f03bbc723cf1cc15c601cea9fb8d::staked_sui::STAKED_SUI>`
        });
        return coins.data.filter(item => Number(item.balance) !== 0)
    }, [])

    const getAllOrders = useCallback(async () => {

        console.log("get all orders")

        const packageObjectId = PACKAGE_ID

        const events = await provider.queryEvents({
            query: { MoveModule: { package: packageObjectId, module: 'vault' } }
        });

        const listing = events.data.reduce((arr, item) => {
            if (item.type.indexOf("ListEvent") !== -1) {
                arr.push(item.parsedJson)
            }
            return arr
        }, [])

        const buying = events.data.reduce((arr, item) => {
            if (item.type.indexOf("BuyEvent") !== -1) {
                arr.push(item.parsedJson['order_id'])
            }
            return arr
        }, [])

        return listing.filter(item => buying.indexOf(item['order_id']) === -1)
    }, [])

    const getRates = useCallback(async () => {

        console.log("get AMM rates")

        const packageObjectId = PACKAGE_ID

        const events = await provider.queryEvents({
            query: { MoveModule: { package: packageObjectId, module: 'vault' } }
        });

        const priceEvents = events.data.reduce((arr, item) => {
            if (item.type.indexOf("PriceUpdatedEvent") !== -1) {
                arr.push(item.parsedJson)
            }
            return arr
        }, [])

        return priceEvents.sort(function (a, b) {
            return Number(a.timestamp) > Number(b.timestamp);
        })[0]
    }, [])

    const getApr = useCallback(async () => {

        console.log("getApr...")

        const packageObjectId = PACKAGE_ID

        const events = await provider.queryEvents({
            query: { MoveModule: { package: packageObjectId, module: 'vault' } }
        });

        const listing = events.data.reduce((arr, item) => {
            if (item.type.indexOf("PriceEvent") !== -1) {
                arr.push(item.parsedJson)
            }
            return arr
        }, [])

        return 3
    }, [])


    const getTotalSupply = useCallback(async () => {
        console.log("getTotalSupply...")

        const packageObjectId = PACKAGE_ID

        const events = await provider.queryEvents({
            query: { MoveModule: { package: packageObjectId, module: 'vault' } }
        });

        const result = events.data.reduce((r, item) => {
            if (item.type.indexOf("LockEvent") !== -1) {
                console.log(item.parsedJson)
                r += Number(item.parsedJson.deposit_amount)
            }
            return r
        }, 0)

        return result / 1000000000
    }, [])

    const getPTBalance = useCallback(async (address) => {

        console.log("get all vault tokens for :", address)

        const packageObjectId = PACKAGE_ID

        const coins = await provider.getCoins({
            owner: address,
            coinType: `${packageObjectId}::vault::TOKEN<0x9c22e4ec6439f67b4bd1c84c9fe7154969e4c88fe1b414602c1a4d56a54209f6::vault::PT>`
        });

        const result = coins.data.reduce((r, item) => {
            if (Number(item.balance) !== 0) {
                r += Number(item.balance)
            }
            return r
        }, 0)
        return result / 1000000000
    }, [])

    const getYTBalance = useCallback(async (address) => {

        console.log("get all vault tokens for :", address)

        const packageObjectId = PACKAGE_ID

        const coins = await provider.getCoins({
            owner: address,
            coinType: `${packageObjectId}::vault::TOKEN<0x9c22e4ec6439f67b4bd1c84c9fe7154969e4c88fe1b414602c1a4d56a54209f6::vault::YT>`
        });

        const result = coins.data.reduce((r, item) => {
            if (Number(item.balance) !== 0) {
                r += Number(item.balance)
            }
            return r
        }, 0)
        return result / 1000000000
    }, [])

    const stake = useCallback(async (objectId) => {
        if (!connected) {
            return
        }

        console.log("objectId : ", objectId)

        // define a programmable transaction
        const tx = new TransactionBlock();
        const packageObjectId = PACKAGE_ID
        tx.moveCall({
            // typeArguments: [TYPE],
            target: `${packageObjectId}::vault::lock`,
            arguments: [tx.pure(RESERVE), tx.pure(`${objectId}`)],
        });

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    const createOrder = useCallback(async (amount, price) => {

        if (!connected) {
            return
        }

        console.log("create order : ", amount, price)

        const packageObjectId = PACKAGE_ID

        let coins = await provider.getCoins({
            owner: wallet.address,
            coinType: `${packageObjectId}::vault::TOKEN<0x9c22e4ec6439f67b4bd1c84c9fe7154969e4c88fe1b414602c1a4d56a54209f6::vault::PT>`
        });

        const coinIds = coins.data.map(item => item.coinObjectId)

        const tx = new TransactionBlock();

        if (coinIds.length > 1) {

            // FIXME: Merge coin

            let sorted = coins.data.sort((a, b) => {
                if (Number(b.balance) < Number(a.balance)) {
                    return -1;
                }
            });

            const pricePerUnit = Number(amount) / Number(price)

            let bpricePerUnit = (pricePerUnit * 1000000000).toFixed(0)
            let bamount = (amount * 1000000000).toFixed(0)

            tx.moveCall({
                target: `${packageObjectId}::vault::list`,
                arguments: [tx.pure(RESERVE), tx.pure(`${sorted[0].coinObjectId}`), tx.pure(bamount), tx.pure(bpricePerUnit)]
            });



            const resData = await wallet.signAndExecuteTransactionBlock({
                transactionBlock: tx
            });
        } else if (coinIds.length === 1) {
            const pricePerUnit = Number(amount) / Number(price)

            let bpricePerUnit = (pricePerUnit * 1000000000).toFixed(0)
            let bamount = (amount * 1000000000).toFixed(0)

            tx.moveCall({
                target: `${packageObjectId}::vault::list`,
                arguments: [tx.pure(RESERVE), tx.pure(`${coinIds[0]}`), tx.pure(bamount), tx.pure(bpricePerUnit)]
            });

            const resData = await wallet.signAndExecuteTransactionBlock({
                transactionBlock: tx
            });
        }

    }, [connected, wallet])

    const buy = useCallback(async (orderId, price) => {

        if (!connected) {
            return
        }

        const balance = await getSuiBalance(wallet.address)

        const tx = new TransactionBlock();
        const [coin] = tx.splitCoins(tx.gas, [tx.pure(((balance * 0.9) * 1000000000).toFixed(0) )]);

        const packageObjectId = PACKAGE_ID

        tx.moveCall({
            target: `${packageObjectId}::vault::buy`,
            arguments: [tx.pure(RESERVE), tx.pure(`${orderId}`), tx.pure(Number(100000000)), coin],
        });

        tx.transferObjects([coin], tx.pure(wallet.address));

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    const swapSui = useCallback(async (amount) => {

        if (!connected) {
            return
        }

        const balance = await getSuiBalance(wallet.address)

        const tx = new TransactionBlock();
        // const [coin] = tx.splitCoins(tx.gas, [tx.pure((balance * 0.9)*1000000000)]);
        const [coin] = tx.splitCoins(tx.gas, [tx.pure((amount) * 1000000000)]);

        const packageObjectId = PACKAGE_ID

        tx.moveCall({
            target: `${packageObjectId}::vault::swap_sui`,
            arguments: [tx.pure(RESERVE), tx.pure(amount * 1000000000), coin],
        });

        tx.transferObjects([coin], tx.pure(wallet.address));

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    return {
        faucet,
        correctedChain,
        createOrder,
        getSuiBalance,
        getStakedSui,
        getAllVaultTokens,
        getAllOrders,
        stake,
        getApr,
        getTotalSupply,
        buy,
        swapSui,
        getPTBalance,
        getYTBalance,
        getRates
    }
}

export default useLegato