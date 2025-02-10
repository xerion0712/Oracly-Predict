import {
    ConnectButton,
    useAccountBalance,
    useWallet,
    SuiChainId,
    ErrorCode,
    formatSUI
} from "@suiet/wallet-kit"
import BigNumber from "bignumber.js"
import { parseSuiAmount, shortAddress } from "@/helpers"
import BaseModal from "@/modals/base"
import { useContext, useEffect, useCallback, useState } from "react"
import { useInterval } from "@/hooks/useInterval"

interface IWalletSui {
    showWallet: boolean
}

const WalletSui = ({ showWallet }: IWalletSui) => {

    const wallet = useWallet()

    const { account, connected } = wallet
    const address = account && account?.address
    const isMainnet = connected && account && account.chains && account.chains[0] === "sui:mainnet" ? true : false

    let parsedBalance = 0

    if (address) {
        const { balance } = useAccountBalance()
        parsedBalance = parseSuiAmount(balance, 9)
    }

    return (
        <>

            {connected && (
                <BaseModal
                    visible={!isMainnet}
                    close={() => { }}
                    title="Wrong Network"
                    maxWidth="max-w-md"
                >
                    <div className="p-2 px-0">
                        <p>Legato only operates on Sui Mainnet. Please switch to the Mainnet to continue using our services</p>
                        <div className="px-2  pt-3">
                            <li className="text-sm text-secondary font-semibold">
                                Check your wallet settings and switch the network
                            </li>
                        </div>

                    </div>
                </BaseModal>
            )}

            <div className="grid grid-cols-1 lg:grid-cols-5">
                <div className={` ${showWallet ? "col-span-4" : "col-span-5"} `}>

                    <div className="py-2 pt-0 sm:pt-2">
                        {wallet && wallet.connected ? (
                            <button onClick={() => {
                                wallet.disconnect()
                            }} type="button" className="btn mx-auto bg-white hover:bg-white hover:text-black py-3.5 w-full rounded-lg my-2">
                                {shortAddress(address || "")}
                            </button>
                        ) :
                            <ConnectButton style={{ width: "100%", borderRadius: "8px" }}>
                                Connect
                            </ConnectButton>
                        }
                    </div>

                    {showWallet && (
                        <>
                            <div className="dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent rounded-t-xl py-2 px-2 sm:px-5 flex flex-row" >
                                <div className='mt-auto mb-auto flex flex-row w-full'>
                                    <div className="mt-auto mb-auto flex text-white pl-2">
                                        <div className="my-auto font-semibold">
                                            All assets
                                        </div>
                                    </div>
                                    <div className="ml-auto  text-white  flex pr-2">
                                        {parsedBalance.toLocaleString()} SUI
                                    </div>
                                </div>
                            </div>
                        </>
                    )}

                    {/*
                    <div className="bg-black/60 rounded-b-xl mb-3.5 pb-2 overflow-y-auto">
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
                                    {balances.map((item: any, index: any) => {
                                        return (
                                            <tr key={index} className="text-sm">
                                                <td className="px-6 py-1.5 pl-4 text-white">
                                                    <div className=" flex flex-row">
                                                        <div className="hidden sm:flex items-center ">
                                                            <img className="h-5   w-5   rounded-full" src={item.icon} alt="" />
                                                        </div>
                                                        <div className=" ml-2 flex items-center ">
                                                            {item.name}
                                                        </div>
                                                    </div>
                                                </td>
                                                <td scope="row" className="px-6 py-1.5 text-white text-right">
                                                    {item.balance.toLocaleString()}
                                                </td>
                                            </tr>
                                        )
                                    })}
                                </table>
                            </>)}
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

                                    {filtered.map((item: any, index: number) => {

                                        const amount = Number(BigNumber(item.amount).dividedBy(10 ** 9))
                                        const odds = Number(item.placing_odds) / 10000

                                        let market

                                        if (item.market_type == 0) {
                                            market = "BTC"
                                        } else if (item.market_type == 1) {
                                            market = "SUI"
                                        }

                                        return (
                                            <tr key={index} className="text-sm">
                                                <td className="px-6 py-1.5 pl-4 text-white">
                                                    <div className=" flex flex-row">
                                                        <Badge>
                                                            {market} ({item.round})
                                                        </Badge>
                                                        <BadgePurple>
                                                            {item.predicted_outcome === 1 && "A"}
                                                            {item.predicted_outcome === 2 && "B"}
                                                            {item.predicted_outcome === 3 && "C"}
                                                            {item.predicted_outcome === 4 && "D"}
                                                        </BadgePurple>
                                                        <div className="text-xs  px-1 font-semibold my-auto">
                                                            {amount.toLocaleString()} SUI / {odds.toLocaleString()}
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
                                    })}
                                </table>
                            </>
                        )}
                    </div> */}

                </div>
            </div>

        </>
    )
}

export default WalletSui