import { useState, useReducer, useCallback, useEffect, useContext } from "react"
import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import BaseModal from "@/modals/base";
import { useInterval } from "@/hooks/useInterval";
import BigNumber from "bignumber.js"
import useAptos from "@/hooks/useAptos";
import { shortAddress } from "@/helpers";


interface IWalletAptos {
    showWallet: boolean
}

const WalletAptos = ({ showWallet }: IWalletAptos) => {

    const wallet = useWallet()
    const { account, network } = wallet

    const address = account && account.address
    const isMainnet = network ? network.name === "mainnet" : true

    const { getBalanceAPT } = useAptos()

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            apt: 0
        }
    )

    const { apt } = values


    useInterval(() => {

        if (address && isMainnet) {
            getBalanceAPT(address, isMainnet).then(
                (apt) => {
                    dispatch({ apt })
                }
            )
        } else {
            dispatch({
                apt: 0
            })
        }

    }, 3000)

    useEffect(() => {
        if (address && isMainnet) {
            getBalanceAPT(address, isMainnet).then(
                (apt) => {
                    dispatch({ apt })
                }
            )
        }
    }, [address, isMainnet])

    return (
        <>

            {/* <BaseModal
                visible={network ? network.name !== "mainnet" : false}
                close={() => { }}
                title="Wrong Network"
                maxWidth="max-w-md"
            >
                <div className="p-2 px-0">
                    <p>Legato only operates on Aptos Mainnet. Please switch to the Mainnet to continue using our services</p>
                    <div className="px-2  pt-3">
                        <li className="text-sm text-secondary font-semibold">
                            Check your wallet settings and switch the network
                        </li>
                    </div>

                </div>
            </BaseModal> */}

            <div className="grid grid-cols-1 lg:grid-cols-5">
                <div className={` ${showWallet ? "col-span-4" : "col-span-5"} `}>
                    <div className="py-2 pt-0 my-2 sm:pt-2">
                        <WalletSelector />
                    </div>
                    {showWallet && (
                        <>
                            <div className="dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent rounded-t-xl py-2 px-2 sm:px-5 flex flex-row  " >
                                <div className='mt-auto mb-auto flex flex-row w-full'>
                                    <div className="mt-auto mb-auto flex text-white pl-0">
                                        <div className="my-auto ml-0 font-semibold">
                                            All assets
                                        </div>
                                    </div>
                                    <div className="ml-auto  text-white  flex pr-2">
                                        {apt.toLocaleString()} APT
                                    </div>
                                </div>
                            </div>
                        </>
                    )}

                    {/* 
                    <div className="bg-black/60 rounded-b-xl mb-3.5 pb-2 overflow-y-auto">
                        {showPosition && (
                            <>
                                <table className="w-full text-sm sm:text-base text-left">
                                    <thead className="text-xs text-secondary">
                                        <tr>
                                            <th scope="col" className="px-6 py-3">
                                                Bet positions ({positions.length})
                                            </th>
                                            <th scope="col" className="px-6 py-3 text-right">

                                            </th>
                                        </tr>
                                    </thead>

                                    {positions.map((item: any, index: number) => {

                                        const amount = Number(BigNumber(item.bet_amount).dividedBy(10 ** 8))
                                        const odds = Number(item.placing_odds) / 10000

                                        return (
                                            <tr key={index} className="text-sm">
                                                <td className="px-6 py-1.5 pl-4 text-white">
                                                    <div className=" flex flex-row"> 
                                                        <Badge>
                                                            {item.market} ({item.round})
                                                        </Badge>
                                                        <BadgePurple>
                                                            {item.selected_outcome === 1 && "A"}
                                                            {item.selected_outcome === 2 && "B"}
                                                            {item.selected_outcome === 3 && "C"}
                                                            {item.selected_outcome === 4 && "D"}
                                                        </BadgePurple>
                                                        <div className="text-xs  px-1 font-semibold my-auto">
                                                            {amount.toLocaleString()} APT / {odds.toLocaleString()}
                                                        </div> 
                                                    </div>
                                                </td>
                                                <td scope="row" className="px-6 py-1.5 text-white text-right">

                                                    <Badge>
                                                        {item.is_open ? "not settled" : "settled"}
                                                    </Badge>
                                                </td>
                                            </tr>
                                        )
                                    })

                                    }

                                </table>
                            </>
                        )}
                        {showWallet && (
                            <>
                                <table className="w-full text-sm sm:text-base text-left">
                                    <thead className="text-xs text-secondary">
                                        <tr>
                                            <th scope="col" className="px-6 py-3">
                                                All assets (2)
                                            </th>
                                            <th scope="col" className="px-6 py-3 text-right">

                                            </th>
                                        </tr>
                                    </thead>

                                    <tr className="text-sm">
                                        <td className="px-6 py-1.5 pl-4 text-white">
                                            <div className=" flex flex-row">
                                                <div className="hidden sm:flex items-center ">
                                                    <img className="h-5   w-5   rounded-full" src={"/assets/images/aptos-logo.png"} alt="" />
                                                </div>
                                                <div className=" ml-2 flex items-center ">
                                                    Legato Vault Token
                                                </div>
                                            </div>
                                        </td>
                                        <td scope="row" className="px-6 py-1.5 text-white text-right">
                                            {lvApt.toFixed(6)}
                                        </td>
                                    </tr>
                                    <tr className="text-sm">
                                        <td className="px-6 py-1.5 pl-4 text-white">
                                            <div className=" flex flex-row">
                                                <div className="hidden sm:flex items-center ">
                                                    <img className="h-5   w-5   rounded-full" src={"/assets/images/legato-icon.png"} alt="" />
                                                </div>
                                                <div className=" ml-2 flex items-center ">
                                                    Market LP Token
                                                </div>
                                            </div>
                                        </td>
                                        <td scope="row" className="px-6 py-1.5 text-white text-right">
                                            {marketLp.toFixed(6)}
                                        </td>
                                    </tr>
                                </table>
                            </>
                        )}
                    </div> */}

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

export default WalletAptos
