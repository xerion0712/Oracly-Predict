
import MarketCard from "./MarketCard"



const MarketListNew = () => {



    return (
        <>

            <div className="heading mb-0 text-center lg:text-left ">
                <h6 className="inline-block bg-secondary/10 px-2.5 py-2 !text-secondary">markets</h6>
                <h4 className="!font-black">
                    EXPLORE <span className="text-secondary">MARKETS</span>
                </h4>
            </div>
            <p className="mt-2.5 text-center text-lg font-medium lg:text-left ">
                discover active markets by participating in decentralized market forecasting
            </p>

            <div className="grid grid-cols-1 gap-3 py-6 max-w-[900px]">

                <MarketCard />

            </div>

        </>
    )
}

export default MarketListNew