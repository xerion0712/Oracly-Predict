
import { useWallet } from '@suiet/wallet-kit'
import { useCallback } from 'react';
import { PACKAGE_ID, TREASURY_CAP, RESERVE, MARKETPLACE } from '@/constants';
import { Ed25519Keypair, JsonRpcProvider, testnetConnection, RawSigner, TransactionBlock } from '@mysten/sui.js';
import { useEffect, useState } from 'react';

const useLegato = () => {

    const wallet = useWallet();

    const provider = new JsonRpcProvider(testnetConnection);

    const [correctedChain, setCorrectedChain] = useState(false)

    const { connected, account } = wallet

    useEffect(() => {
        if (!wallet.connected) return;
        setCorrectedChain(wallet.chain.id === "sui:testnet" ? true : false)
    }, [wallet.connected])

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

        const coins = await provider.getCoins({
            owner: address,
            coinType: `${packageObjectId}::vault::VAULT`
        });
        
        return coins.data.filter(item => Number(item.balance) !== 0).map(item => item.coinObjectId)
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
                arr.push(item.parsedJson['object_id'])
            }
            return arr
        }, [])

        return listing.filter(item => buying.indexOf(item['object_id']) === -1)
    }, [])


    // const getTotalSupply = useCallback(async () => {
    //     const txn = await provider.getObject({
    //         id: '0xcc2bd176a478baea9a0de7a24cd927661cc6e860d5bacecb9a138ef20dbab231',
    //         // fetch the object content field
    //         options: { showContent: true },
    //     });
    // },[])

    const stake = useCallback(async (coinId) => {
        if (!connected) {
            return
        }

        // define a programmable transaction
        const tx = new TransactionBlock();
        const packageObjectId = PACKAGE_ID
        tx.moveCall({
            target: `${packageObjectId}::vault::mint`,
            arguments: [tx.pure(RESERVE), tx.pure(`${coinId}`)],
        });

        const resData = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });

    }, [connected, wallet])

    const createOrder = useCallback(async (tokenId, price) => {

        if (!connected) {
            return
        }

        const tx = new TransactionBlock();
        // const [coin] = tx.splitCoins(tx.gas, [tx.pure(1000)]);

        const packageObjectId = PACKAGE_ID
        tx.moveCall({
            target: `${packageObjectId}::marketplace::list`,
            arguments: [tx.pure(MARKETPLACE), tx.pure(`${tokenId}`), tx.pure(`${price}`)],
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
        buy
    }
}

export default useLegato