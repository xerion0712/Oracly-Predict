import { LegatoContext } from "@/hooks/useLegato"
import { useContext, useEffect, useState } from "react"
import useDatabase from "@/hooks/useDatabase";
import GroupCards from "./GroupCards";

const MarketList = ({ setCurrentMarket }: any) => {

    const [selected, setSelected] = useState<any>(undefined)

    const [markets, setMarkets] = useState<any>([])

    const { currentNetwork } = useContext(LegatoContext)

    const { getMarkets } = useDatabase()

    useEffect(() => {
        getMarkets(currentNetwork).then(setMarkets)
    }, [currentNetwork])

    const categories = markets.reduce((output: any, item: any) => {
        if (output.indexOf(item.category) === -1) {
            output.push(item.category)
        }
        return output
    }, [])

    const titles = markets.reduce((arr: any, item: any) => {
        if (arr.indexOf(item.title) === -1) {
            arr.push(item.title)
        }
        return arr
    }, [])

    return (
        <div className=" mt-1">

            <div className="flex flex-row space-x-2 py-2 mb-4">

                <TitleButton active={selected === undefined} onClick={() => setSelected(undefined)}>
                    All
                </TitleButton>

                {titles.map((title: string, index: number) => {
                    return (
                        <TitleButton index={index} active={selected === title} onClick={() => setSelected(title)}>
                            {title}
                        </TitleButton>
                    )
                })}
            </div>

            {/* {categories.map((name: any, index: number) => (
                <GroupCards
                    name={name}
                    index={index}
                    items={markets.filter((item: any) => item.category === name)}
                    filter={selected}
                    setCurrentMarket={setCurrentMarket}
                />
            ))} */}
        </div>
    )
}

const TitleButton = ({ children, onClick, index, active }: any) => {
    return (
        <button key={index} onClick={onClick} className={`cursor-pointer  rounded-[10px] border border-transparent  py-1 px-2  ${active ? "bg-secondary text-white" : "bg-secondary/10  hover:border-secondary hover:bg-transparent"} `}>
            {children}
        </button>
    )
}


export default MarketList