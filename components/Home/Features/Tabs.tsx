import { useState } from "react"

enum Tab {
    Outcome,
    Bet,
    Odds,
    Resolution
}

const Tabs = () => {

    const [tab, setTab] = useState<Tab>(Tab.Outcome)

    return (
        <div className='p-2 px-0 my-4 '>
            <div className={`rounded-lg mx-auto max-w-4xl bg-black mt-2 `}>

                {/* NAV */}
                <div className='grid grid-cols-3 text-center text-base sm:text-lg overflow-hidden font-bold  leading-7'>
                    <div className={`cursor-pointer py-4 ${tab === Tab.Outcome ? "text-white" : "bg-[#141F32] rounded-tl-lg"}`} onClick={() => setTab(Tab.Outcome)}>
                        Proposing Outcomes
                    </div>
                    <div className={`cursor-pointer py-4 ${tab === Tab.Bet ? "text-white" : "bg-[#141F32] "}`} onClick={() => setTab(Tab.Bet)}>
                        Place Your Stake
                    </div>
                    <div className={`cursor-pointer py-4 ${tab === Tab.Odds ? "text-white" : "bg-[#141F32] rounded-tr-lg"}`} onClick={() => setTab(Tab.Odds)}>
                        Market Finalization
                    </div>
                </div>

                <div className=' p-2  text-sm sm:text-base'>

                    {tab === Tab.Outcome && (
                        <>
                            <video width="auto" className="rounded-lg my-4" height="auto" autoPlay loop>
                                <source src="./assets/videos/propose-outcome.mp4" type="video/mp4" />
                            </video>
                            <div className="text-center p-4 pt-2">
                                You can propose any outcome you like—whether it's about token price, ranking, or trading volume. AI-Agent will help analyze the market data and validate whether it fits the round's conditions.
                            </div>
                        </>
                    )

                    }

                    {tab === Tab.Bet && (
                        <>
                            <img className="w-full my-4 rounded" src={"./assets/images/screenshot-place-bet.png"} alt="" />
                            <div className="text-center p-4 pt-2">
                                You can chat with the AI-Agent to get insights and view all available outcomes for the round before placing a bet. If you're not satisfied with the existing outcomes, you can propose a new one.
                            </div>
                        </>
                    )

                    }

                    {tab === Tab.Odds && (
                        <>
                            <img className="w-full my-4 rounded" src={"./assets/images/screenshot-market-finalize.png"} alt="" />
                            <div className="text-center p-4 pt-2">
                            Every bet adds to the prize pool. The AI-Agent periodically reviews proposed outcomes, assigns weights based on market data. Winners receive payouts based on their stake.
                            </div>
                        </>
                    )

                    }

                </div>

            </div>
        </div>
    )
}

export default Tabs