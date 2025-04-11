
import { useInterval } from "@/hooks/useInterval"
import { secondsToDDHHMMSS } from "../../../helpers"
import { useState, useEffect } from "react"

// TEMP

const OverviewMoveAgentKit = ({ market }: any) => {

    const [countdown, setCountdown] = useState<string | undefined>()
    const [interval, setInterval] = useState(100)
    const [period, setPeriod] = useState("")

    useInterval(() => {
        if (market) {
            const now = new Date().valueOf()
            const end = (Number(market.createdTime) * 1000) + (market.round * (Number(market.interval) * 1000))
            const diff = end - now
            if (diff > 0) {
                const totals = Math.floor(diff / 1000)
                const { days, hours, minutes, seconds } = secondsToDDHHMMSS(totals)
                setCountdown(`${days}d ${hours}h ${minutes}m ${seconds}s`)
            } else {
                setCountdown("0d - Please refresh")
            }
            setInterval(1000)
        }

    }, interval)

    useEffect(() => {
        if (market) {
            const startPeriod = (Number(market.createdTime) * 1000) + (market.round * (Number(market.interval) * 1000))
            const endPeriod = startPeriod + (Number(market.interval) * 1000)
            setPeriod(`${new Date(startPeriod).toDateString()} - ${new Date(endPeriod).toDateString()}`)
        }
    }, [market])

    return (
        <>
            <div className="heading mb-0 text-center lg:text-left "> 
                <h4 className="!font-black">
                    APTOS<span className="text-secondary">{` `}DEFI</span>
                </h4>
            </div>
            <div className="text-center lg:text-left ">

                <a href="https://metamove.build/" target="_blank" className="text-lg mt-1 text-secondary">
                https://metamove.build/
                </a>
            </div>

            <p className="mt-1 text-center text-base sm:text-lg font-medium lg:text-left ">
            Predict yields, TVL across major protocols including Joule, Thala, LiquidSwap and more  through Move Agent Kit
            </p>

            <div className={`py-1 `}>
                <div className="flex flex-row text-lg font-semibold">
                    <h2 className=" text-normal ">
                        Predicting Period:
                    </h2>

                    {market && (
                        <h2 className="  ml-2  text-white font-semibold">
                            {period}<br /> (Closes in {countdown})
                        </h2>
                    ) }
                </div>
            </div>
        </>
    )
}

export default OverviewMoveAgentKit