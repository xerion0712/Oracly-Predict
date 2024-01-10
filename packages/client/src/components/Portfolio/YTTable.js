
import { useContext, useState, useCallback, useEffect } from "react"
import { LegatoContext } from "@/hooks/useLegato"
import BigNumber from "bignumber.js"
import { parseAmount } from "@/helpers"
import YTItemModal from "@/modals/YTItem"


const YTTable = ({ account, isTestnet }) => {

    const { getTotalYT } = useContext(LegatoContext)
    const [tick, setTick] = useState(0)
    const [yt, setYT] = useState([])
    const [selected, setSelected] = useState(undefined)

    const increaseTick = useCallback(() => {
        setTick(tick + 1)
    }, [tick])

    useEffect(() => {
        account && account.address && getTotalYT(account.address, isTestnet).then(setYT)
    }, [account, isTestnet, tick])

    return (
        <>
            <YTItemModal
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

            {yt.map((item, index) => {

                const amount = Number(`${(BigNumber(item.balance)).dividedBy(BigNumber(10 ** 9))}`)
                const parsedAmount = parseAmount(amount)

                return (
                    <tr onClick={() => setSelected({
                        ...item
                    })} key={index} class="border-b border-gray-700 hover:border-blue-700 cursor-pointer ">
                        <td class="px-6 py-4  text-white">
                            <div className=" flex flex-row">
                                <div className=" flex  items-center ">
                                    <div class="relative">
                                        <img class="h-5 w-5 rounded-full" src={"./sui-sui-logo.svg"} alt="" />
                                        <img src="/pt-badge.png" class="bottom-0 right-2 absolute  w-4 h-2" />
                                    </div>
                                </div>
                                <div className=" ml-2 flex  items-center ">
                                    ytStaked SUI
                                </div>
                            </div>
                        </td>
                        <td scope="row" class="px-6 py-4   text-white">
                            <div className=" flex flex-row">
                                <div className=" flex  items-center ">
                                    <div class="relative">
                                        <img class="h-5 w-5 rounded-full" src={"./vault-icon-2.png"} alt="" />
                                    </div>
                                </div>
                                <div className=" ml-2 flex  items-center ">
                                    <h3 class={`text-sm  text-white`}>{item.vault}</h3>
                                </div>
                            </div>
                        </td>
                        
                        <td class="px-6 py-4  text-white">
                            {parsedAmount}{` YT`}
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

export default YTTable