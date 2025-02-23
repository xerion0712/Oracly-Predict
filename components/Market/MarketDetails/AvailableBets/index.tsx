import { useState, useEffect, useCallback } from "react"
import { ArrowLeft, ArrowRight } from "react-feather"
import useDatabase from "../../../../hooks/useDatabase"
import Agent from "../../../../amplify/lib/agent"
import { parseTables } from "../../../../helpers"
import { useInterval } from "@/hooks/useInterval"
import useOpenAI from "@/hooks/useOpenAI"
import useAI from "@/hooks/useAI"

const AvailableBets = ({ currentRound, marketData, onchainMarket, openBetModal }: any) => {

    // const { parse } = useOpenAI()
    const { parse } = useAI()

    const [interval, setInterval] = useState(100)

    const { getOutcomes, crawl, updateOutcomeWeight } = useDatabase()

    const [outcomes, setOutcomes] = useState([])
    const [current, setCurrent] = useState(0)
    const [tick, setTick] = useState<number>(0)

    useEffect(() => {
        currentRound && setCurrent(currentRound)
    }, [currentRound])

    const increaseTick = useCallback(() => {
        setTick(tick + 1)
    }, [tick])

    useEffect(() => {
        current > 0 && marketData ? getOutcomes(marketData.id, current).then(setOutcomes) : setOutcomes([])
    }, [marketData, current, tick])

    useInterval(
        () => {
            if (outcomes.length > 0 && onchainMarket && marketData) {
                updateWeights(outcomes, currentRound, marketData, onchainMarket)
                setInterval(10000)
            }

        }, interval
    )

    const updateWeights = useCallback(async (outcomes: any, currentRound: number, marketData: any, onchainMarket: any) => {

        const rounds = await marketData.rounds()
        const thisRound: any = rounds.data.find((item: any) => item.onchainId === Number(currentRound))

        if (!thisRound) {
            return
        }

        let need_update = false

        if (thisRound.lastWeightUpdatedAt === undefined) {
            need_update = true
        } else if ((new Date().valueOf() / 1000) - thisRound.lastWeightUpdatedAt > 86400) {
            need_update = true
        }

        if (!need_update) {
            return
        }

        const resource = await marketData.resource()

        if (resource && resource.data) {

            const source = resource.data.name
            const context = await crawl(resource.data)

            const startPeriod = (Number(onchainMarket.createdTime) * 1000) + (onchainMarket.round * (Number(onchainMarket.interval) * 1000))
            const endPeriod = startPeriod + (Number(onchainMarket.interval) * 1000)
            const period = `${new Date(startPeriod).toDateString()} - ${new Date(endPeriod).toDateString()}`

            const agent = new Agent()
            const systemPrompt = agent.getSystemPrompt(currentRound, source, parseTables(context), period)
            const outcomePrompt = agent.getOutcomePrompt(outcomes)

            const messages = [systemPrompt, outcomePrompt]

            const output = await parse([...messages, {
                role: 'user',
                content: "help assign weight for each outcome"
            }])

            console.log(output)

            if (output.length > 0) {
                await updateOutcomeWeight({ marketId: marketData.id, roundId: currentRound, weights: output })
                increaseTick()
            }

        }

    }, [increaseTick])

    const totalPool = outcomes.reduce((output: number, item: any) => {
        if (item && item.totalBetAmount) {
            output = output + item.totalBetAmount
        }
        return output
    }, 0)

    return (
        <div className="flex flex-col my-2">

            <div
                className="flex flex-row justify-between my-2 text-white ml-4 mx-4"
            >
                <div className="flex text-secondary    cursor-pointer" onClick={() => current > 1 && setCurrent(current - 1)}>
                    <ArrowLeft className="my-auto  " />
                    <div className='my-auto'>Previous Round</div>
                </div>
                <div className=" uppercase text-2xl font-bold text-white  text-center px-4">
                    Round {current} {current === currentRound && " (Current)"}
                </div>
                <div className=" flex text-secondary   cursor-pointer" onClick={() => setCurrent(current + 1)}>
                    <div className='my-auto'>Next Round</div>
                    <ArrowRight className="my-auto " />

                </div>

            </div>

            {/* <div className="mx-auto text-white font-semibold my-1">
                🏆 Round Pool: 1000 USDC
            </div> */}

            <div className="my-4 grid grid-cols-3 gap-3">
                {outcomes.map((entry: any, index:number) => {

                    let minOdds = 0
                    let maxOdds = 0

                    if (entry && outcomes) {
                        const totalPoolAfter = totalPool + 1

                        // Assumes all outcomes won
                        const totalShares = outcomes.reduce((output: number, item: any) => {
                            if (item && item.totalBetAmount) {
                                output = output + (item.totalBetAmount * (item.weight))
                            }
                            if (item.onchainId === entry.onchainId) {
                                output = output + (1 * (item.weight))
                            }
                            return output
                        }, 0)
                        const outcomeShares = (entry.totalBetAmount + 1) * (entry.weight)
                        const ratio = outcomeShares / totalShares

                        minOdds = ((ratio) * totalPoolAfter) * (1 / (entry.totalBetAmount + 1))
                        maxOdds = entry.totalBetAmount > 0 ? (totalPoolAfter) * (1 / (entry.totalBetAmount + 1)) : -1
                    }

                    return (
                        <div key={index}>
                            <OutcomeCard
                                index={index}
                                item={entry}
                                openBetModal={openBetModal}
                                marketData={marketData}
                                current={current}
                                minOdds={minOdds}
                                maxOdds={maxOdds}
                            />
                        </div>
                    )
                })}
            </div>
        </div>
    )
}



const OutcomeCard = ({ index, item, current, marketData, openBetModal, minOdds, maxOdds }: any) => {

    return (
        <div onClick={() => {

            openBetModal({
                marketId: marketData.id,
                roundId: current,
                outcomeId: item.onchainId,
            })

        }} className=" h-[150px] p-4 px-2 border-2 flex flex-col cursor-pointer border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg" >

            <div className="flex flex-row">
                {/* <img className="h-8 sm:h-10 w-8 sm:w-10 my-auto rounded-full" src={icon} alt="" /> */}
                <div className="px-2">
                    <p className="text-white font-semibold line-clamp-2">
                        {item?.title}
                    </p>
                </div>
            </div>
            <div className="px-2 text-sm font-semibold my-1">
                Resolution: {` ${(new Date(Number(item.resolutionDate) * 1000)).toUTCString()}`}
            </div>
            <div className="flex px-2 flex-row my-1 mt-auto justify-between">
                <div className=" ">
                    <p className="text-white text-base font-semibold">⚡{` ${item.totalBetAmount || 0} USDC`}</p>
                </div>
                {item.totalBetAmount && (
                    <div className=" ">
                        <p className="text-white  font-semibold"> 🔥 </p>
                    </div>
                )}
                {/* <div className=" ">
                    <p className="text-white  font-semibold">🕒{` ${ (new Date( Number(item.resolutionDate) * 1000 )).toLocaleDateString()}`}</p>
                </div> */}
                <div className=" ">
                    <p className="text-white text-base font-semibold">🎲{`${item.weight ? `${((minOdds)).toLocaleString()}` : "N/A"}`}</p>
                </div>

            </div>

        </div>
    );
}


export default AvailableBets