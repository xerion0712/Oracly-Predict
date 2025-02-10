import { useState } from "react"
import BaseModal from "@/modals/base"

const MarketTitle = ({ dispatch, markets, marketTitle }: any) => {

    const [text, setText] = useState<any>()
    const [modal, setModal] = useState<boolean>(false)

    const titles = markets.reduce((output: any, item: any) => {
        if (output.indexOf(item.title) === -1) {
            output.push(item.title)
        }
        return output
    }, [])

    const total = markets.reduce((output: number, item: any) => {
        if (item.title === marketTitle) {
            output += 1
        }
        return output
    }, 0)

    return (
        <>

            <BaseModal
                visible={modal}
                title="Add New Title"
                maxWidth="max-w-lg" close={() => {
                    setModal(false)
                }}>

                <div className="py-2 pt-4">
                    <input type="text" value={text} onChange={(e) => setText(e.target.value)} id="market-title-new" placeholder="Ex. BTC Price Prediction" className={`block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none`} />
                    <p className="text-gray mt-2 px-0.5 text-base">Please use a unique, short and descriptive title. We reserve the right to make changes. </p>
                </div>

                <div className="mt-4 flex   flex-row">
                    <button onClick={() => {
                        dispatch({ marketTitle: text })
                        setModal(false)
                    }} type="button" className="btn ml-auto mr-1 rounded-lg  bg-white py-2.5 px-8  hover:text-black hover:bg-white flex flex-row">
                        Save
                    </button>
                    <button onClick={() => {
                        setText(undefined)
                        setModal(false)
                    }} type="button" className="btn mr-auto ml-1 rounded-lg  bg-white py-2.5 px-8  hover:text-black hover:bg-white flex flex-row">
                        Cancel
                    </button>
                </div>

            </BaseModal>

            <div className="grid grid-cols-7">
                <div className="col-span-2 text-white text-lg font-semibold flex">
                    <div className="m-auto mr-4">
                        Market Title:
                    </div>
                </div>
                <div className="col-span-3">
                    <select value={marketTitle} onChange={(e: any) => {

                        if (e.target.value === "clear") {
                            dispatch({ marketTitle: undefined })
                        } else {
                            const market = markets.sort((a: any, b: any) => {
                                return new Date(b.closingDate).getTime() - new Date(a.closingDate).getTime()
                            }).find((m: any) => m.title === e.target.value)


                            if (market) {
                                dispatch({
                                    marketTitle: e.target.value,
                                    marketDescription: market.description,
                                    totalOutcomes: market.outcomes.length,
                                    marketOutcomeA: market.outcomes[0] || undefined,
                                    marketOutcomeB: market.outcomes[1] || undefined,
                                    marketOutcomeC: market.outcomes[2] || undefined,
                                    marketOutcomeD: market.outcomes[3] || undefined
                                })
                            } else {
                                dispatch({
                                    marketTitle: e.target.value,
                                    marketDescription: undefined
                                })
                            }
                        }

                    }} className="block w-full p-2 cursor-pointer  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none">
                        {text === undefined
                            ?
                            <option value={"clear"}>Use existing title</option>
                            :
                            <option value={text}>{text}</option>
                        }
                        {titles.map((t: any, index: number) => (
                            <option key={index} value={t}>{t}</option>
                        ))}
                    </select>
                </div>

                <div className="col-span-2 px-2">
                    <button onClick={() => {
                        setModal(true)
                    }} type="button" className="btn ml-2  rounded-lg  bg-white py-2.5 px-8  hover:text-black hover:bg-white flex flex-row">
                        Add New Title
                    </button>
                </div>
                <div className="col-span-2 ">

                </div>
                <div className="col-span-3">
                    {marketTitle ? (
                        <>
                            <p className="text-sm py-2 pb-0 ">{total} markets grouped under the same title.</p>
                        </>
                    ) : <p className="text-sm py-2 pb-0 ">Use an existing title to group related markets together.</p>}

                </div>
            </div>
        </>
    )
}

export default MarketTitle