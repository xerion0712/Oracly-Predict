
import { useContext, useState, useCallback, useEffect } from "react"
import { LegatoContext } from "@/hooks/useLegato"
import BigNumber from "bignumber.js"
import { parseAmount } from "@/helpers"
import PTItemModal from "@/modals/PTItem"

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
                       
                        <td scope="row" class="px-6 py-4     text-white">
                            <div className=" flex flex-row">
                                <div className=" flex  items-center ">
                                    <div class="relative">
                                        <img class="h-5 w-5 rounded-full" src={"./vault-icon-3.png"} alt="" />
                                    </div>
                                </div>
                                <div className=" ml-2 flex  items-center ">
                                    <h3 class={`text-sm  text-white`}>{item.vault}</h3>
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