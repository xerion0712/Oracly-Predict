
import { useWallet } from '@suiet/wallet-kit'
import { useCallback } from 'react';
import { PACKAGE_ID, TREASURY_CAP } from '@/constants';
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
        return `${(Number(coins.totalBalance)/ 100000000).toFixed(2)}`
            
    }, [])

    return {
        faucet,
        correctedChain,
        getMockBalance
    }
}

export default useLegato