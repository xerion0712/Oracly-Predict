import BasePanel from "./Base"
import { useEffect, useState } from "react"
import Spinner from "../components/Spinner"
import { shortAddress } from "@/helpers"

const InfoRow = ({ name, value }) => {
    return (
        <div class="grid grid-cols-2 gap-2 mt-1 mb-2">
            <div class="text-gray-300 text-sm font-medium">
                {name}
            </div>
            <div className=" font-medium text-sm ml-auto mr-3">
                {value}
            </div>
        </div>
    )
}

const MintPT = ({ visible, close, selected, apr, loading, onStake, items }) => {

    const [profit, setProfit] = useState([0,0])
    const [ss, setSS] = useState()
    const [info, setInfo ] = useState()

    useEffect(() => {
        if (info && apr > 0) {
            const date1 = new Date('9/23/2024');
            const date2 = new Date();
            const diffTime = Math.abs(date2 - date1);
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
            const profit = (diffDays * (apr / 100)) / 400 
            setProfit([profit, profit * (info.fields['principal']/1000000000)])
        }
    }, [apr, info])

    useEffect(() => {
        items && items[0] && setSS(items[0].data.objectId)
    }, [items])

    useEffect(() => {
        items.map(item => {
            if (item.data.objectId === ss) {
                setInfo(item.data.content)
            }
        })
    },[items, ss])

    let base_amount = info && info.fields ? (info.fields['principal']/1000000000) : 1

    return (
        <BasePanel
            visible={visible}
            close={close}
        >
            <h2 class="text-2xl mb-2 mt-2 font-bold">
                Mint Principal Tokens
            </h2>
            <hr class="my-12 h-0.5 border-t-0 bg-neutral-100 mt-2 mb-2 opacity-50" />
            <p class="  text-sm text-gray-300  mt-2">
                Deposit your Staked SUI to convert it into Principal Tokens (PT), which locks in a fixed yield until the end of the period.
            </p>
            <div className="border rounded-lg mt-4   p-4 border-gray-400">
                <div className="flex items-center">
                    <img src={"./sui-sui-logo.svg"} alt="" className="h-6 w-6  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                    <span className="ml-1 block text-white font-medium text-right">
                        Staked SUI
                    </span>
                    <div class="ml-auto text-gray-300 text-sm font-medium">
                        {selected.name}
                    </div>
                </div>
            </div> 
            <div className="border rounded-lg mt-4 p-4 border-gray-400">
                <div className="block leading-6 mb-2 text-gray-300">Object to convert into PTs</div>
                <div class="flex mb-2">
                    <select id="large" value={ss} onChange={(e) => setSS(e.target.value)} class="block w-full px-4 py-3 text-base text-gray-900 border border-gray-300 rounded-lg bg-gray-50 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500">
                        {items.map((item, index) => {
                            return (
                                <option key={index} value={item.data.objectId}>
                                    [{shortAddress(item.data.objectId)}]{` `}{Number(item.data.content.fields.principal)/1000000000}{` `}Sui
                                </option>
                            )
                        })
                        }
                    </select>
                </div>
            </div>
            <div className="border rounded-lg mt-4 p-4 border-gray-400">
                <div class="mt-2 flex flex-row">
                    <div class="text-gray-300 text-sm font-medium">You will receive at least</div>
                    <span class="ml-auto bg-blue-100 text-blue-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-blue-900 dark:text-blue-300">
                        1 Staked SUI = {(1 + profit[0]).toLocaleString()} PT
                    </span>
                </div>

                <hr class="h-px my-4 border-0  bg-gray-600" />
                <div class="grid grid-cols-2 gap-2 mt-2 mb-2">
                    <div>
                        <h2 className="text-3xl font-medium">
                            PT
                        </h2>
                        <div class="text-gray-300 text-sm font-medium">
                            SUI at Maturity
                        </div>
                    </div>
                    <div className="flex">
                        <div className="text-3xl font-medium mx-auto mt-3 mb-auto mr-2">
                            {(base_amount + profit[1]).toLocaleString()}
                        </div>
                    </div>
                </div>
                <InfoRow
                    name={"Est. Profit at Maturity"}
                    value={profit[1].toLocaleString()}
                />
                {/* <InfoRow
                    name={"Price impact"}
                    value={"0.01%"}
                /> */}
                <InfoRow
                    name={"Fixed APR"}
                    value={`${apr}%`}
                />
                <hr class="h-px my-4 border-0 bg-gray-600" />
                <button disabled={loading} onClick={() => onStake(ss)} className=" py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                    {loading && <Spinner />}
                    Mint
                </button>
            </div>


        </BasePanel>
    )
}

export default MintPT