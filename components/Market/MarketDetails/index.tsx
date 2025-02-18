
import Overview from "./Overview"
import System from "./System"
import WalletPanel from "./WalletPanel"
import AllOutcomes from "./AllOutcomes"

const MarketDetails = () => {
    return (
        <>
            <div className=" grid grid-cols-1 sm:grid-cols-5 gap-3">
                
                <div className="col-span-3 flex flex-col ">
                    <Overview />
                    <WalletPanel />
                </div>

                <div className="col-span-2 flex flex-col h-full  ">

                    <System />

                </div>

                <div className="col-span-5 ">
                    <AllOutcomes />

                </div>

            </div>



        </>
    )
}

export default MarketDetails