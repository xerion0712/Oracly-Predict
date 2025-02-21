import { useState, useEffect } from "react"
import { ArrowLeft, ArrowRight } from "react-feather"
import useDatabase from "../../../../hooks/useDatabase"


const AvailableBets = ({ currentRound, marketData, onchainMarket, openBetModal }: any) => {

    const { getOutcomes } = useDatabase()

    const [outcomes, setOutcomes] = useState([])
    const [current, setCurrent] = useState(0)

    useEffect(() => {
        currentRound && setCurrent(currentRound)
    }, [currentRound])

    useEffect(() => {
        current > 0 && marketData ? getOutcomes(marketData.id, current).then(setOutcomes) : setOutcomes([])
    }, [marketData, current])

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
                {outcomes.map((item, index) => {
                    return (
                        <OutcomeCard
                            index={index}
                            item={item}
                            openBetModal={openBetModal}
                            marketData={marketData}
                            current={current}
                        />
                    )
                })}
            </div>



        </div>
    )
}



const OutcomeCard = ({ index, item, current, marketData, openBetModal }: any) => {

    return (
        <div key={index} onClick={() => {

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
                { item.totalBetAmount && (
                    <div className=" ">
                    <p className="text-white  font-semibold"> 🔥 </p>
                </div> 
                )}
                {/* <div className=" ">
                    <p className="text-white  font-semibold">🕒{` ${ (new Date( Number(item.resolutionDate) * 1000 )).toLocaleDateString()}`}</p>
                </div> */}
                <div className=" ">
                    <p className="text-white text-base font-semibold">🎲{` N/A`}</p>
                </div>

            </div>

        </div>
    );
}


export default AvailableBets