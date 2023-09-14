
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

    const faucet = useCallback(async () => {

        if (!connected) {
            return
        }

        // define a programmable transaction
        const tx = new TransactionBlock();
        const packageObjectId = PACKAGE_ID
        tx.moveCall({
            target: `${packageObjectId}::staked_sui::mint`,
            arguments: [tx.pure(TREASURY_CAP), tx.pure("100000000")],
        });

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    const getMockBalance = useCallback(async (address) => {

        console.log("get mock balance for :", address)

        const packageObjectId = PACKAGE_ID

        const coins = await provider.getBalance({
            owner: address,
            coinType: `${packageObjectId}::staked_sui::STAKED_SUI`,
        });

        //FIXME : use bn
        return `${(Number(coins.totalBalance) / 100000000).toFixed(2)}`

    }, [])

    const getAllCoins = useCallback(async (address) => {

        console.log("get all coins for :", address)

        const packageObjectId = PACKAGE_ID

        const coins = await provider.getCoins({
            owner: address,
            coinType: `${packageObjectId}::staked_sui::STAKED_SUI`
        });

        return coins.data.map(item => item.coinObjectId)
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
            query: { MoveModule: { package: packageObjectId, module: 'marketplace' } }
        });

        const listing = events.data.reduce((arr, item) => {
            if (item.type.indexOf("ListEvent") !== -1) {
                arr.push(item.parsedJson)
            }
            return arr
        }, [])

        const buying = events.data.reduce((arr, item) => {
            if (item.type.indexOf("BuyEvent") !== -1) {
                arr.push(item.parsedJson['item_id'])
            }
            return arr
        }, [])

        return listing.filter(item => buying.indexOf(item['item_id']) === -1)
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

        return (Number(listing[listing.length - 1].value) / 1000)
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
                r += Number(item.parsedJson.collateral)
            }
            return r
        }, 0)
        return result/100000000
    },[])

    const getPTBalance = useCallback(async (address) => {

        console.log("get all vault tokens for :", address)

        const packageObjectId = PACKAGE_ID

        // coin::Coin<0x89b77424c9514f64537f83ae5e260286ee08f03bbc723cf1cc15c601cea9fb8d::vault::PT<0x89b77424c9514f64537f83ae5e260286ee08f03bbc723cf1cc15c601cea9fb8d::staked_sui::STAKED_SUI>>

        const coins = await provider.getCoins({
            owner: address,
            coinType: `${packageObjectId}::vault::PT<0x89b77424c9514f64537f83ae5e260286ee08f03bbc723cf1cc15c601cea9fb8d::staked_sui::STAKED_SUI>`
        });
        
        const result = coins.data.reduce((r, item) => {
            if (Number(item.balance) !== 0) {
                r += Number(item.balance)
            }
            return r
        }, 0)
        return result/100000000
    }, [])

    const stake = useCallback(async (coinId) => {
        if (!connected) {
            return
        }

        console.log("coinId : ", coinId)

        // define a programmable transaction
        const tx = new TransactionBlock();
        const packageObjectId = PACKAGE_ID
        tx.moveCall({
            typeArguments: [TYPE],
            target: `${packageObjectId}::vault::lock`,
            arguments: [tx.pure(RESERVE), tx.pure(`${coinId}`)],
        });

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    const createOrder = useCallback(async (coin, price) => {

        if (!connected) {
            return
        }

        const { coinObjectId} = coin

        const tx = new TransactionBlock();
        // const [coin] = tx.splitCoins(tx.gas, [tx.pure(1000)]);

        const packageObjectId = PACKAGE_ID
        tx.moveCall({ 
            target: `${packageObjectId}::marketplace::list`,
            arguments: [tx.pure(MARKETPLACE), tx.pure(`${coinObjectId}`), tx.pure(`${price}`)],
        });

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    const buy = useCallback(async (objectId, price) => {

        if (!connected) {
            return
        }

        console.log("buy", objectId, price)

        const tx = new TransactionBlock();
        const [coin] = tx.splitCoins(tx.gas, [tx.pure(Number(price))]);

        const packageObjectId = PACKAGE_ID

        tx.moveCall({
            target: `${packageObjectId}::marketplace::buy_and_take`,
            arguments: [tx.pure(MARKETPLACE), tx.pure(`${objectId}`), coin],
        });

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    return {
        faucet,
        correctedChain,
        createOrder,
        getMockBalance,
        getAllCoins,
        getAllVaultTokens,
        getAllOrders,
        stake,
        getApr,
        getTotalSupply,
        buy,
        getPTBalance
    }
}

export default useLegato