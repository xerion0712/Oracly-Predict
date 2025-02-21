import { useState, useReducer, useCallback, useEffect, useContext } from "react"
import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import BaseModal from "@/modals/base";
import { useInterval } from "@/hooks/useInterval";
import BigNumber from "bignumber.js"
import useAptos from "@/hooks/useAptos";
import { shortAddress } from "@/helpers";
import { LegatoContext } from "@/hooks/useLegato";

const WalletBalance = () => {

    const { balance, loadBalance } = useContext(LegatoContext)

    const { account, network } = useWallet()

    const address = account && account.address
    
    useEffect(() => {
        address && loadBalance(address)
    },[address])

    return (
        <>
            <div className="mt-1">
                <div className={` `}>
                    <div className="py-2 pt-0 my-2 mb-0 ">
                        <WalletSelector />
                    </div>
                </div>
                <div className={`  text-lg`}>
                    <div className="flex flex-row">
                        <h2 className="my-auto font-semibold">
                            Your Balance
                        </h2>
                        <img src="https://s2.coinmarketcap.com/static/img/coins/64x64/3408.png" className="h-5 w-5 my-auto mx-1.5" />
                        <h2 className="my-auto text-white font-semibold">
                            {address ? balance.toLocaleString() : 0} USDC
                        </h2>
                    </div>
                </div>
            </div>

            <style>
                {

                    `
        
        .wallet-button {
            width: 100%;
            z-index: 1;
            border-width: 0px;
          } 

        
        
        `
                }
            </style>
        </>
    )
}

export default WalletBalance