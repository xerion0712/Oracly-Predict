import { ArrowLeft, ChevronLeft, Plus, ArrowRight, ChevronRight } from "react-feather"
import { Tab, TabGroup, TabList, TabPanel, TabPanels } from '@headlessui/react'
import { useCallback, useEffect, useState } from "react"
import { useInterval } from "@/hooks/useInterval"
import { secondsToDDHHMMSS } from "../../../helpers"
import NewOutcomeModal from "@/modals/newOutcome"
import useDatabase from "@/hooks/useDatabase"


const START_TIMESTAMP = 1739588048
const MARKET_ID = "717dacc1-92f9-4be6-a935-ca221e1af1f9"

const AllOutcomes = () => {

    const [modal, setModal] = useState(false)

    const { getOutcomes }: any = useDatabase()

    const [currentRound, setRound] = useState(1)

    const [tick, setTick] = useState(1)
    const [outcomes, setOutcomes] = useState<any[]>([])

    const increaseTick = useCallback(() => {
        setTick(tick + 1)
    }, [tick])

    useEffect(() => {
        getOutcomes().then(setOutcomes)
    }, [tick])

    return (
        <>

            <NewOutcomeModal
                visible={modal}
                close={() => setModal(false)}
                roundId={Number(currentRound)}
                marketId={MARKET_ID}
                increaseTick={increaseTick}
            />

            <div className="flex flex-row my-2">
                <h3 className="text-3xl font-bold text-white my-auto">🎯 </h3>

                <div
                    className="flex flex-row my-2 text-white ml-4 mx-4"
                >
                    <div className="ml-auto flex">
                        <ArrowLeft className="my-auto cursor-pointer" onClick={() => currentRound > 1 && setRound(currentRound - 1)} />
                    </div>
                    <div className="text-3xl font-bold text-white   px-4">
                        Round {currentRound}
                    </div>
                    <div className="mr-auto flex">
                        <ArrowRight className="my-auto cursor-pointer" onClick={() => setRound(currentRound + 1)} />
                    </div>

                </div>
                <button onClick={() => setModal(true)} type="button" className="btn ml-auto  my-auto bg-white text-sm flex rounded-lg px-8 py-3 hover:scale-100  flex-row hover:text-black hover:bg-white ">
                    <div className='my-auto'>
                        New Outcome
                    </div>
                    <Plus size={18} className='mt-[3px] ml-1' />
                </button>

            </div>

            {/* <TabGroup className="  w-full my-4 flex flex-col">
                <TabList className=" gap-3 space-x-2 mx-auto flex justify-between w-full max-w-xl ">
                    {[1, 2, 3, 4].map((name) => (
                        <Tab
                            key={name}
                            onClick={() => setRound(Number(name))}
                            className="rounded text-sm cursor-pointer py-1.5 px-8   text-white border border-gray/30  focus:outline-none data-[selected]:bg-[#141F32] data-[hover]:bg-[#141F32] data-[selected]:data-[hover]:bg-[#141F32] data-[focus]:outline-1 data-[focus]:outline-white"
                        >
                            Round {name}
                        </Tab>
                    ))} 
                </TabList>
                <div className="text-secondary mx-auto my-2 ">
                     {countdown}
                </div>

            </TabGroup> */}

            {/* <div
                className="flex flex-row my-2 text-white"
            >
                <div className="ml-auto flex">
                    <ChevronLeft className="my-auto" />
                </div>
                <div className="text-xl font-semibold px-4">
                    Round {currentRound}
                </div>
                <div className="mr-auto flex">
                    <ChevronRight className="my-auto" />
                </div>

            </div> */}
            <p className="my-2 text-center text-lg font-medium mx-auto ">
                Check out all available outcomes for the selected round to place your bet or propose a new one
            </p>
            <CountdownRow
                currentRound={currentRound}
            />

            <div className="my-4 grid grid-cols-3 gap-3">
                {outcomes.filter((item: any) => item.roundId === currentRound).map((item, index) => {
                    return (
                        <OutcomeCard
                            index={index}
                            item={item}
                        />
                    )
                })}
            </div>
        </>
    )
}


const OutcomeCard = ({ index, item, market_name, icon, popular_outcome, close_in, chains, tag }: any) => {

    return (
        <div key={index} className="  p-4 px-2 border-2 flex flex-col cursor-pointer border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg" >

            <div className="flex flex-row">
                {/* <img className="h-8 sm:h-10 w-8 sm:w-10 my-auto rounded-full" src={icon} alt="" /> */}
                <div className="px-2">
                    <p className="text-white font-semibold">
                        {item?.title}
                    </p>
                </div>
            </div>
            <div className="flex flex-row my-1 mt-auto justify-between">
                <div className=" ">
                    <p className="text-white text-base font-semibold">⚡{` 0 USDC`}</p>
                </div>
            </div>

        </div>
    );
}

const CountdownRow = ({ currentRound }: any) => {

    const [countdown, setCountdown] = useState<string | undefined>()
    const [interval, setInterval] = useState(100)

    useInterval(
        () => {
            const diffTime = ((START_TIMESTAMP + (currentRound * 86400 * 7)) * 1000) - (new Date()).valueOf()
            const totals = Math.floor(diffTime / 1000)
            const { days, hours, minutes, seconds } = secondsToDDHHMMSS(totals)

            if (0 > Number(days)) {
                setCountdown("Round Ended")
            } else {
                setCountdown(`Round Ends in ${days}d ${hours}h ${minutes}m ${seconds}s`)
            }

        }, interval
    )

    return (
        <div className="text-secondary text-sm text-center mx-auto mb-2 ">
            {countdown}
        </div>
    )
}

export default AllOutcomes