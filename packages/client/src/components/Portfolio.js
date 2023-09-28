import { Fragment, useEffect, useState } from 'react'
import { useWallet } from "@suiet/wallet-kit"
import useLegato from '@/hooks/useLegato'
import { VAULT } from "../constants"

const Portfolio = () => {

    const activeVault = VAULT[0]

    const [tab, setTab] = useState(1)

    const { getPTBalance, getYTBalance } = useLegato()

    const wallet = useWallet()
    const { account } = wallet

    const [pt, setPT] = useState(0)
    const [yt, setYT] = useState(0)

    useEffect(() => {
        account && account.address && getPTBalance(account.address).then(
            (output) => {
                setPT(output)
            }
        )
        account && account.address && getYTBalance(account.address).then(setYT)
    }, [account])


    return (
        <div>
            <div className="max-w-4xl mx-auto">
                <div class="wrapper pt-10">
                    <p class="text-neutral-400 text-sm p-5 text-center">
                        All your positions on Legato
                    </p>
                    <div class="rounded-xl p-px bg-gradient-to-b  from-blue-800 to-purple-800">
                        <div class="rounded-[calc(0.8rem-1px)] p-10 pl-5 pr-5 pt-3 bg-gray-900">
                            <div class="text-sm font-medium text-center  border-b  text-gray-400 border-gray-700">
                                <ul class="flex flex-wrap -mb-px">
                                    <li class="mr-2">
                                        <span onClick={() => setTab(1)} class={`inline-block cursor-pointer p-4 border-b-2 rounded-t-lg ${tab === 1 ? "active text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"} `}>
                                            PT & YT
                                        </span>
                                    </li>
                                    <li class="mr-2">
                                        <span onClick={() => setTab(2)} class={`inline-block  cursor-pointer p-4  border-b-2  rounded-t-lg ${tab === 2 ? "active  text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"}`} aria-current="page">
                                            Liquidity
                                        </span>
                                    </li>
                                </ul>
                            </div>
                            <div class="h-[200px] flex">
                                {pt === 0 && <div class="mx-auto font-medium mt-auto mb-auto">
                                    No active positions
                                </div>
                                }
                                {pt > 0 && <>
                                    <div class=" mt-4 mb-4 text-gray-100 py-3 w-full">
                                        <div class="grid grid-cols-7 gap-3 px-2 mt-4 mb-4 ">
                                            <div class="col-span-2 flex flex-col text-md">
                                                <div class="mt-auto mb-auto">
                                                    {activeVault.symbol}
                                                </div>
                                            </div>
                                            <div class="col-span-2 flex flex-col text-md">
                                                <div class="mt-auto mb-auto">
                                                    Vault {activeVault.name}
                                                </div>
                                            </div>
                                            <div class="col-span-2 flex flex-col text-md">
                                                <div class="mt-auto ml-auto">
                                                    Balance: {pt.toLocaleString()}
                                                </div>
                                            </div>
                                            <div class="col-span-1 flex flex-col text-md">
                                                <button className=" py-1 rounded-lg pl-5 pr-5 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                                                    Unstake
                                                </button>
                                            </div>
                                        </div>
                                        {yt > 0 && <>
                                            <div class=" mt-0 mb-4 text-gray-100 py-3 w-full">
                                                <div class="grid grid-cols-7 gap-3 px-2 mt-0 mb-4 ">
                                                    <div class="col-span-2 flex flex-col text-md">
                                                        <div class="mt-auto mb-auto">
                                                            {activeVault.ytSymbol}
                                                        </div>
                                                    </div>
                                                    <div class="col-span-2 flex flex-col text-md">
                                                        <div class="mt-auto mb-auto">
                                                            Vault {activeVault.name}
                                                        </div>
                                                    </div>
                                                    <div class="col-span-2 flex flex-col text-md">
                                                        <div class="mt-auto ml-auto">
                                                            Balance: {yt.toLocaleString()}
                                                        </div>
                                                    </div>
                                                    <div class="col-span-1 flex flex-col text-md">
                                                        <div class="mt-auto mb-auto">
                                                            <button className=" py-1 rounded-lg pl-5 pr-5 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                                                                Claim
                                                            </button>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </>}
                                    </div>
                                </>}
                            </div>

                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default Portfolio