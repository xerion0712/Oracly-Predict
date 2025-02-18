
import Overview from "./Overview"
import System from "./System"
import WalletPanel from "./WalletPanel"
import AllOutcomes from "./AllOutcomes"

const MarketDetails = () => {
    return (
        <>
            <div className=" grid grid-cols-1 sm:grid-cols-5 gap-3">
            <div className="col-span-5 mb-2 bg-secondary/10 border-l-4 border-secondary text-secondary p-4 rounded-lg">
 
  <p>AI-Agent for this market is being redeployed. We will be back in a few days.</p>
</div>
                <div className="col-span-3 flex flex-col ">
                    <Overview />
                    <WalletPanel />
                </div>

                <div className="col-span-2 flex flex-col h-full  ">

                    <System />

                </div>

                <div className="col-span-5 ">
                    <AllOutcomes/>

                </div>

            </div>



        </>
    )
}

export default MarketDetails