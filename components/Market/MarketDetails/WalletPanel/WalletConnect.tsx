import { useState, useReducer, useCallback, useEffect, useContext } from "react"
import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import BaseModal from "@/modals/base";
import { useInterval } from "@/hooks/useInterval";
import BigNumber from "bignumber.js"
import useAptos from "@/hooks/useAptos";
import { shortAddress } from "@/helpers"; 

const WalletConnect = () => {



    return (
        <>
            <div className="grid grid-cols-1 lg:grid-cols-5">
                <div className={` col-span-4 `}>
                    <div className="py-2 pt-0 my-2 mb-0 ">
                        <WalletSelector />
                    </div>
                </div>
                <div className={` col-span-3 `}>
                    <div className="flex flex-row">
                        <h2 className="my-auto">
                            Your Balance
                        </h2>
                        <img src="https://s2.coinmarketcap.com/static/img/coins/64x64/3408.png" className="h-5 w-5 my-auto mx-1.5"/>
                        <h2 className="my-auto text-white font-semibold">
                            0 USDC
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

export default WalletConnect