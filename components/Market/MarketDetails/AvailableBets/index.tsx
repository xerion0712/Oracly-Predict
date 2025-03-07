import { useState, useEffect, useCallback, useReducer } from "react"
import { ArrowLeft, ArrowRight } from "react-feather"
import useDatabase from "../../../../hooks/useDatabase"
import Agent from "../../../../amplify/lib/agent"
import { parseTables, secondsToDDHHMMSS, titleToIcon } from "../../../../helpers"
import { useInterval } from "@/hooks/useInterval"
import useOpenAI from "@/hooks/useOpenAI"
import useAI from "@/hooks/useAI"
import BigNumber from "bignumber.js"
import BaseModal from "@/modals/base"

enum SortBy {
    MostPopular = "MostPopular",
    HighestOdds = "HighestOdds",
    LowestOdds = "LowestOdds",
    Newest = "Newest"
}

const AvailableBets = ({ currentRound, marketData, onchainMarket, openBetModal }: any) => {

    const { getOutcomes } = useDatabase()

    const [outcomes, setOutcomes] = useState([])
    const [current, setCurrent] = useState(0)
    const [tick, setTick] = useState<number>(0)

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            sorted: SortBy.MostPopular,
            infoModal: undefined
        })

    const { sorted, infoModal } = values

    useEffect(() => {
        currentRound && setCurrent(currentRound)
    }, [currentRound])

    // const increaseTick = useCallback(() => {
    //     setTick(tick + 1)
    // }, [tick])

    useEffect(() => {
        current > 0 && marketData ? getOutcomes(marketData.id, current).then(
            (outcomes) => {
                const outcomesWithOdds = outcomes.map((outcome: any, index: number) => {
                    let minOdds = 0
                    let maxOdds = 0
                    let odds = "Medium"

                    if (outcome && outcomes) {
                        const totalPoolAfter = totalPool + 1

                        // Assumes all outcomes won
                        const totalShares = outcomes.reduce((output: number, item: any) => {
                            if (item && item.totalBetAmount) {
                                output = output + (item.totalBetAmount * (item.weight))
                            }
                            if (item.onchainId === outcome.onchainId) {
                                output = output + (1 * (item.weight))
                            }
                            return output
                        }, 0)
                        const outcomeShares = (outcome.totalBetAmount + 1) * (outcome.weight)
                        const ratio = outcomeShares / totalShares

                        minOdds = ((ratio) * totalPoolAfter) * (1 / (outcome.totalBetAmount + 1))
                        maxOdds = outcome.totalBetAmount > 0 ? (totalPoolAfter) * (1 / (outcome.totalBetAmount + 1)) : -1

                        if (minOdds >= 3) {
                            odds = "Very High"
                        } else if (minOdds >= 2) {
                            odds = "High"
                        } else if (minOdds >= 1) {
                            odds = "Medium"
                        } else {
                            odds = "Low"
                        }
                    }

                    return {
                        minOdds,
                        maxOdds,
                        odds,
                        ...outcome,
                        totalBetAmount: outcome.totalBetAmount ? outcome.totalBetAmount : 0
                    }
                })

                setOutcomes(outcomesWithOdds)
            }
        ) : setOutcomes([])
    }, [marketData, current, tick])

    // useInterval(
    //     () => {
    //         if (outcomes.length > 0 && onchainMarket && marketData) {
    //             updateWeights(outcomes, currentRound, marketData, onchainMarket) 
    //             setInterval(10000)
    //         }

    //     }, interval
    // )

    // const updateWeights = useCallback(async (outcomes: any, currentRound: number, marketData: any, onchainMarket: any) => {

    //     const rounds = await marketData.rounds()
    //     const thisRound: any = rounds.data.find((item: any) => item.onchainId === Number(currentRound))

    //     if (!thisRound) {
    //         return
    //     }

    //     let need_update = false

    //     if (thisRound.lastWeightUpdatedAt === undefined) {
    //         need_update = true
    //     } else if ((new Date().valueOf() / 1000) - thisRound.lastWeightUpdatedAt > 86400) {
    //         need_update = true
    //     }

    //     if (!need_update) {
    //         return
    //     }

    //     const resource = await marketData.resource()

    //     if (resource && resource.data) {

    //         const source = resource.data.name
    //         const context = await crawl(resource.data)

    //         const startPeriod = (Number(onchainMarket.createdTime) * 1000) + (onchainMarket.round * (Number(onchainMarket.interval) * 1000))
    //         const endPeriod = startPeriod + (Number(onchainMarket.interval) * 1000)
    //         const period = `${new Date(startPeriod).toDateString()} - ${new Date(endPeriod).toDateString()}`

    //         const agent = new Agent()
    //         const systemPrompt = agent.getSystemPrompt(currentRound, source, parseTables(context), period)
    //         const outcomePrompt = agent.getOutcomePrompt(outcomes)

    //         const messages = [systemPrompt, outcomePrompt]

    //         const output = await parse([...messages, {
    //             role: 'user',
    //             content: "help assign weight for each outcome"
    //         }])

    //         console.log(output)

    //         if (output.length > 0) {
    //             await updateOutcomeWeight({ marketId: marketData.id, roundId: currentRound, weights: output })
    //             increaseTick()
    //         }

    //     }

    // }, [increaseTick])

    const totalPool = outcomes.reduce((output: number, item: any) => {
        if (item && item.totalBetAmount) {
            output = output + item.totalBetAmount
        }
        return output
    }, 0)


    let outcomesSorted = []

    if (sorted === SortBy.MostPopular) {
        outcomesSorted = outcomes.sort(function (a: any, b: any) {
            return Number(b.totalBetAmount) - Number(a.totalBetAmount)
        })
    } else if (sorted === SortBy.HighestOdds) {
        outcomesSorted = outcomes.sort(function (a: any, b: any) {
            return Number(b.minOdds) - Number(a.minOdds)
        })
    } else if (sorted === SortBy.LowestOdds) {
        outcomesSorted = outcomes.sort(function (a: any, b: any) {
            return Number(a.minOdds) - Number(b.minOdds)
        })
    } else if (sorted === SortBy.Newest) {
        outcomesSorted = outcomes.sort(function (a: any, b: any) {
            return Number(b.onchainId) - Number(a.onchainId)
        })
    } else {
        outcomesSorted = outcomes
    }

    const poolSize = onchainMarket ? Number(BigNumber(onchainMarket.balance).dividedBy(10 ** 6)) : 0
    const endTimestamp = onchainMarket ? (Number(onchainMarket.createdTime) * 1000) + (current * (Number(onchainMarket.interval) * 1000)) : 0

    let endIn = "0d"
    if (endTimestamp) {
        const now = new Date().valueOf()
        const diff = endTimestamp - now
        if (diff > 0) {
            const totals = Math.floor(diff / 1000)
            const { days, hours } = secondsToDDHHMMSS(totals)
            if (days !== "0") {
                endIn = `${days}d`
            } else {
                endIn = `${hours}h`
            }

        }
    }

    return (
        <>

            <BaseModal
                visible={infoModal}
                close={() => dispatch({ infoModal: undefined })}
                title={"Outcome Results"}
                maxWidth="max-w-xl"
            >

                {infoModal && (
                    <>
                        <div className="grid grid-cols-2 py-2 text-gray">
                            <div className=" py-0.5  col-span-2 text-lg font-semibold  text-white flex flex-row">
                                {infoModal.title}
                            </div>

                            {!infoModal.revealedTimestamp && (
                                <>
                                    <div className=" py-0.5 col-span-2  text-sm  flex flex-row">
                                        <span className="font-bold mr-2">At:</span>
                                        <div className={`   flex flex-row  text-white text-sm `}>
                                            {` ${(new Date(Number(infoModal.resolutionDate) * 1000)).toUTCString()}`}
                                        </div>
                                    </div>
                                    <div className="col-span-2 rounded-lg   h-[100px] mt-[10px] flex border border-gray/30">
                                        <div className="m-auto text-white font-semibold">
                                            The result is not yet revealed
                                        </div>
                                    </div>
                                </>
                            )}

                            {infoModal.revealedTimestamp && (
                                <>
                                    <div className=" py-0.5 col-span-2  text-sm  flex flex-row">
                                        <span className="font-bold mr-2">Checked At:</span>
                                        <div className={`   flex flex-row  text-white text-sm `}>
                                            {` ${(new Date(Number(infoModal.revealedTimestamp) * 1000)).toUTCString()}`}
                                        </div>
                                    </div>
                                    <div className="col-span-2 rounded-lg grid grid-cols-2 mt-[10px] p-4 py-2 border border-gray/30">
                                        <div className=" py-0.5 col-span-1  text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Result:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {infoModal.isWon ? "✅" : "❌"}
                                            </div>
                                        </div>
                                        <div className=" py-0.5 col-span-1  text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Disputed:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {infoModal.isDisputed ? "✅" : "❌"}
                                            </div>
                                        </div>
                                        <div className=" py-0.5 col-span-2  text-sm  flex flex-row">
                                            <div className="text-white my-1">
                                                {infoModal.result}
                                            </div>
                                        </div>
                                    </div>

                                </>
                            )}



                            {/* <div className=" py-0.5 text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Current Odds:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {`${outcome.weight ? `${minOdds.toLocaleString()}-${`${maxOdds !== -1 ? maxOdds.toLocaleString() :"10"}`}` : "N/A"}`}
                                            </div>
                                        </div>
                                        <div className=" py-0.5 text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Round Pool:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {`${totalPool} USDC`}
                                            </div>
                                        </div>  */}
                        </div>
                    </>
                )

                }

            </BaseModal>

            <div className="flex flex-col my-2">

                <div
                    className="flex flex-row justify-between my-2 text-white ml-4 mx-4"
                >
                    <div className="flex text-secondary    cursor-pointer" onClick={() => current > 1 && setCurrent(current - 1)}>
                        <ArrowLeft className="my-auto  " />
                        <div className='my-auto'>Previous Round</div>
                    </div>
                    <div className=" uppercase text-2xl font-bold text-white  text-center px-4">
                        Round {current} {current === currentRound && " 🆕"}
                    </div>
                    {currentRound > current ? (
                        <div className=" flex text-secondary cursor-pointer" onClick={() => setCurrent(current + 1)}>
                            <div className='my-auto'>Next Round</div>
                            <ArrowRight className="my-auto " />
                        </div>
                    ) : <div className="flex w-[100px]"></div>}

                </div>

                <div className="grid grid-cols-3 my-1 mb-0">
                    <div className="flex flex-row">
                        <div className="text-white my-auto text-sm mr-2 font-semibold">
                            Sort by
                        </div>
                        <select value={sorted} onChange={(e: any) => {
                            dispatch({ sorted: e.target.value })
                        }} className="  p-2 px-3 py-1 cursor-pointer my-auto rounded-lg text-sm bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none">
                            <option value={SortBy.MostPopular}>Most Popular</option>
                            <option value={SortBy.HighestOdds}>Highest Odds</option>
                            <option value={SortBy.LowestOdds}>Lowest Odds</option>
                            <option value={SortBy.Newest}>Newest</option>
                        </select>
                    </div>
                    <div className="text-center flex">
                        {currentRound === current && (
                            <div className="text-white text-sm my-auto mx-auto font-semibold">
                                🟢 Accepting bets for the next {endIn}
                            </div>
                        )}
                        {currentRound > current && (
                            <>
                                {(currentRound - current === 1) ? (
                                    <div className="text-white text-sm my-auto mx-auto font-semibold">
                                        🟡 Determining winning outcomes
                                    </div>
                                ) : (
                                    <div className="text-white text-sm my-auto mx-auto font-semibold">
                                        🔵 All outcomes have been revealed and verified
                                    </div>
                                )}
                            </>
                        )}

                    </div>
                    <div className="text-white my-auto text-sm ml-auto font-semibold">
                        🏦 Current Pool Size: {poolSize.toLocaleString() || 0} USDC
                    </div>
                </div>

                {/* <div className="mx-auto text-white font-semibold my-1">
    🏆 Round Pool: 1000 USDC
</div> */}

                <div className="my-4 grid grid-cols-3 gap-3">
                    {outcomesSorted.map((entry: any, index: number) => {

                        return (
                            <div key={index}>
                                <OutcomeCard
                                    index={index}
                                    item={entry}
                                    openBetModal={openBetModal}
                                    openInfoModal={() => dispatch({ infoModal: entry })}
                                    marketData={marketData}
                                    current={current}
                                    minOdds={entry.minOdds}
                                    maxOdds={entry.maxOdds}
                                    odds={entry.odds}
                                    isPast={currentRound > current}
                                />
                            </div>
                        )
                    })}
                </div>
            </div>
        </>
    )
}



const OutcomeCard = ({ index, item, current, marketData, openInfoModal, openBetModal, minOdds, maxOdds, odds, isPast }: any) => {

    const icon = titleToIcon(item?.title)

    return (
        <div onClick={() => {

            !isPast && openBetModal({
                marketId: marketData.id,
                roundId: current,
                outcomeId: item.onchainId,
            })
            isPast && openInfoModal()

        }} className=" h-[150px] p-4 px-2 border-2 flex flex-col cursor-pointer border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg" >

            <div className="flex flex-row">
            <img className="h-8 sm:h-10 w-8 sm:w-10 my-auto rounded-full" src={icon} alt="" />
                <div className="px-2">
                    <p className="text-white font-semibold line-clamp-2">
                        {item?.title}
                    </p>
                </div>
            </div>
            <div className="px-2 text-sm font-semibold my-1">
                At: {` ${(new Date(Number(item.resolutionDate) * 1000)).toUTCString()}`}
            </div>
            <div className="flex px-2 flex-row my-1 mt-auto justify-between">
                <div className=" ">
                    <p className="text-white text-base font-semibold">🔥{` ${item.totalBetAmount || 0} USDC`}</p>
                </div>
                {/* {item.totalBetAmount && (
                    <div className=" ">
                        <p className="text-white  font-semibold"> 🔥 </p>
                    </div>
                )} */}
                {/* <div className=" ">
                    <p className="text-white  font-semibold">🕒{` ${ (new Date( Number(item.resolutionDate) * 1000 )).toLocaleDateString()}`}</p>
                </div> */}

                {isPast && (
                    <div className=" ">
                        {item.revealedTimestamp && <> {item.isWon ? "✅" : item.isDisputed ? "⚠️" : "❌"} </>}
                    </div>
                )}

                <div className=" flex flex-row">
                    <p className="text-white text-base font-semibold">🔢{`${item.weight ? ` ${item.weight.toLocaleString()}%` : "N/A"}`}</p>
                </div>

            </div>

        </div>
    );
}


export default AvailableBets