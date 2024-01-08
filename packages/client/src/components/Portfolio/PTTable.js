
import { useContext, useState, useCallback, useEffect } from "react"
import { LegatoContext } from "@/hooks/useLegato"
import BigNumber from "bignumber.js"
import { parseAmount } from "@/helpers"
import PTItemModal from "@/modals/PTItem"

// const PTTableOLD = ({ assetKey }) => {

//     const market = MARKET[assetKey]

//     return (
//         <div className="w-full">
//             <div className="flex  flex-col">
//                 <div className="flex flex-row gap-3 p-2 pt-0 ">
//                     <div className="grid grid-cols-3 w-full my-1 text-center text-sm text-gray-300">
//                         <div className="col-span-1 border-2 border-gray-700  p-2 flex flex-row  rounded-l-md">
//                             <div className=" flex  items-center p-2">
//                                 <div class="relative">
//                                     <img class="h-8 w-8 rounded-full  " src={market.img} alt="" />
//                                     {market.isPT && <img src="/pt-badge.png" class="bottom-0 right-4 absolute  w-7 h-4  " />}
//                                 </div>
//                             </div>
//                             <div className="  flex  items-center ">
//                                 <h3 class={`text-base font-medium text-white`}>{market.to}</h3>
//                             </div>
//                         </div>

//                         <div className="col-span-1 border-2  border-l-0 border-gray-700   px-8    p-2  ">
//                             Total Staked
//                             <h3 class={`text-lg font-medium text-white`}>
//                                 $0
//                             </h3>
//                         </div>
//                         <div className="col-span-1 border-2 border-gray-700   px-8 border-l-0 p-2 rounded-r-md">
//                             Pending
//                             <h3 class={`text-lg font-medium text-white`}>
//                                 $0
//                             </h3>
//                         </div>
//                     </div>
//                 </div>

//                 <div class="text-gray-300 text-sm px-2">
//                     All Assets (-)
//                 </div>

//             </div>
//         </div>
//     )
// }

const PTTable = ({ account, isTestnet }) => {

    const { getTotalPT } = useContext(LegatoContext)
    const [tick, setTick] = useState(0)
    const [pt, setPT] = useState([])
    const [selected, setSelected] = useState(undefined)

    const increaseTick = useCallback(() => {
        setTick(tick + 1)
    }, [tick])

    useEffect(() => {
        account && account.address && getTotalPT(account.address, isTestnet).then(setPT)
    }, [account, isTestnet, tick])

    return (
        <>
            <PTItemModal
                visible={selected !== undefined}
                close={() => {
                    setSelected(undefined)
                    setTimeout(() => {
                        increaseTick()
                    }, 1000)
                }}
                item={selected}
                isTestnet={isTestnet}
            />

            {pt.map((item, index) => {

                const amount = Number(`${(BigNumber(item.balance)).dividedBy(BigNumber(10 ** 9))}`)
                const parsedAmount = parseAmount(amount)

                return (
                    <tr onClick={() => setSelected({
                        ...item
                    })} key={index} class="border-b border-gray-700 hover:border-blue-700 cursor-pointer ">
                        <th scope="row" class="px-6 py-4 font-medium    text-white">
                            <div className=" flex flex-row">
                                <div className=" flex  items-center ">
                                    <div class="relative">
                                        <img class="h-5 w-5 rounded-full" src={"./vault-icon.png"} alt="" />
                                    </div>
                                </div>
                                <div className=" ml-2 flex  items-center ">
                                    <h3 class={`text-sm  text-white`}>{item.vault}</h3>
                                </div>
                            </div>
                        </th>
                        <td class="px-6 py-4  text-white">
                            <div className=" flex flex-row">
                                <div className=" flex  items-center ">
                                    <div class="relative">
                                        <img class="h-5 w-5 rounded-full" src={"./sui-sui-logo.svg"} alt="" />
                                        <img src="/pt-badge.png" class="bottom-0 right-2 absolute  w-4 h-2" />
                                    </div>
                                </div>
                                <div className=" ml-2 flex  items-center ">
                                    ptStaked SUI
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4  text-white">
                            {parsedAmount}{` PT`}
                        </td>
                        <td class="px-6 py-4  text-white">
                            {`-`}
                        </td>

                    </tr>
                )
            })}

        </>
    )
}

export default PTTable