import { ChevronRight } from "react-feather"
import { useState } from "react"
import { useInterval } from "@/hooks/useInterval"
import { secondsToDDHHMMSS } from "../../helpers"


const PreviewCard = ({ item, setCurrentMarket }: any) => {

    const [countdown, setCountdown] = useState<string | undefined>()
    const [interval, setInterval] = useState(100)

    const expired_date = item ? new Date((item.closingDate)) : new Date()

    useInterval(
        () => {
            if (item) {

                if (item.status === "RESOLVED") {
                    setCountdown(`Ended`)
                } else {

                    const diffTime = expired_date.valueOf() - (new Date()).valueOf()
                    const totals = Math.floor(diffTime / 1000)
                    const { days, hours, minutes, seconds } = secondsToDDHHMMSS(totals)

                    if (0 > Number(days)) {
                        setCountdown("Concluding")
                    } else {
                        setCountdown(`Due in ${days}d ${hours}h ${minutes}m ${seconds}s`)
                    }
                }
                setInterval(1000)
            }

        }, interval
    )

    return (
        <div className="flex flex-col group ">
            <div className={`bg-white dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent  flex rounded-t-xl  px-2 sm:px-5  border border-transparent h-[40px]  `} >
                <div className="mt-auto mb-auto flex">
                    <div className="mt-auto mb-auto flex items-center ">
                        <img className="h-5 w-5 rounded-full" src={item.image} alt="" />
                    </div>
                    <div className="mt-auto mb-auto flex pl-2.5">
                        <h2 className='text-base lg:text-lg tracking-tight font-semibold text-white'>{item.title}</h2>
                    </div>
                </div>
            </div>
            <div className="p-4 px-2.5 mb-[40px] bg-gray-dark rounded-b-lg shadow-md hover:shadow-lg">

                <div className='mx-auto' >
                    <h4 className="!font-black  text-center text-white text-sm ">
                        {item.description}
                    </h4>
                </div>

                <div className='  mx-auto  '>
                    {item && item.outcomes.map((outcome: string, index: number) => {

                        let letter = "?"
                        let won = false

                        switch (index) {
                            case 0:
                                letter = "A"
                                won = item && item.resolvedOutcome === 1
                                break;
                            case 1:
                                letter = "B"
                                won = item && item.resolvedOutcome === 2
                                break;
                            case 2:
                                letter = "C"
                                won = item && item.resolvedOutcome === 3
                                break;
                            case 3:
                                letter = "D"
                                won = item && item.resolvedOutcome === 4
                                break;
                            default:
                                break;

                        }

                        // const liquidity = Number((BigNumber(market.liquidity[index])).dividedBy(BigNumber(10 ** 8)))
                        // const odds = 1 / (Number(market.probability[index]) / 10000)

                        const resolved = item && item.resolvedOutcome


                        return (
                            <div key={index}> 
                                <Outcome
                                    market={item}
                                    outcomeId={index + 1}
                                    letter={letter}
                                    text={outcome}
                                    resolved={resolved}
                                    won={won}
                                    select={setCurrentMarket}
                                />
                            </div>
                        )
                    })}
                </div>

                {/* 
                                <h3 className="text-xl font-semibold mb-2">{item.title}</h3>
                                <p className="text-sm text-gray-500 mb-4">Category: {item.category}</p>*/}
                {/* <button className="mt-4 w-full bg-secondary text-white py-2 rounded">View Market</button>  */}
                <div className=' px-4 py-2 pt-1 text-xs text-center font-semibold text-secondary'>
                    {countdown || "Checking"}
                </div>

            </div>
        </div>
    )
}


const Square = ({ content }: any) => (
    <span className=" flex h-[25px] w-[25px] min-w-[25px] items-center justify-center my-auto rounded-[8px] bg-secondary font-semibold text-sm text-white">
        {content}
    </span>
)

const Outcome = ({ market, letter, text, resolved, won, select, outcomeId }: any) => {

    

    return (
        <div 
            onClick={() => {
                !resolved && select({
                    ...market,
                    outcomeId
                })
            }}
            className={` my-2.5 flex items-start gap-[10px] rounded-[10px] border border-transparent   py-2 px-4  
            ${resolved ? `bg-secondary/10 ${won && "bg-transparent border border-[#B476E5] "}` : " cursor-pointer bg-secondary/10 hover:border-secondary hover:bg-transparent  "}
             `}
        >
            <Square content={letter} />
            <div className='w-[40%] my-auto  mr-2 sm:mr-0'>
                <h6 className=" font-semibold text-sm  text-white">
                    {text}
                </h6>
            </div>
            {/* <div className="text-xs font-semibold ml-auto my-auto mr-2">
                ${(liquidity * 8).toLocaleString()}
            </div> */}
            {/* <div className="ml-auto  my-auto font-bold mr-2">
                {odds.toLocaleString()}
            </div> */}
        </div>
    )
}


export default PreviewCard