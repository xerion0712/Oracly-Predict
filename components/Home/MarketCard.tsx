
import { FaFire } from "react-icons/fa6";
import BlockchainList from "../../data/blockchain.json"

interface IMarketCard {
    market_name: string
    icon: string
    popular_outcome: string
    close_in: number
    chains: any
    tag: string
}


const MarketCard = ({ market_name, icon, popular_outcome, close_in, chains, tag }: IMarketCard) => {
    return (
        <div className="  p-4 px-2 border-2 cursor-pointer border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg" >

            <div className="flex flex-row">
                <img className="h-8 sm:h-10 w-8 sm:w-10 my-auto rounded-full" src={icon} alt="" />
                <div className="px-2">
                    <p className="text-white font-semibold">
                        {market_name}
                    </p>
                </div>
                {/* <div>

                </div>
                <div>
                    <div className='flex flex-row pr-2'>
                        {BlockchainList.map((item, index) => (<img src={item.image} key={index} alt="" className='w-[20px] mx-0.5  ' />))}
                    </div>
                </div> */}
            </div>
             {/* <div className="flex my-1 flex-row">
                <div>
                    <span className=" bg-secondary text-xs font-semibold me-2 px-2.5 py-0.5 rounded  text-white  ">
                        {tag}
                    </span>
                </div>
            </div> */}
            <div className="flex flex-row my-1 justify-between">
                <div className=" ">

                    {/* <span className="   bg-secondary text-xs font-semibold me-2 px-2.5 py-0.5 rounded  text-white  ">
                        Close in 4 days
                    </span> */}
                    <p className="text-white text-base font-semibold">🕒{` in ${close_in} days`}</p>
                    
                </div>
                <div>
                    {/* <div className='flex flex-row mt-0.5 sm:mt-0 ml-0 sm:ml-2'>
                        {BlockchainList.map((item, index) => (<img src={item.image} key={index} alt="" className='w-[20px] mx-0.5 sm:mx-1' />))}
                    </div>  */}
                </div>
                <div className=" ">

                    {/* <p className="text-xs font-normal text-white">most popular</p> */}
                    <p className="text-white text-base font-semibold">🔥{` ${popular_outcome}`}</p>
                </div>

            </div>
            {/* <div className="flex my-1 mb-0 flex-row">
                <div className=" ">
                    <span className=" bg-secondary text-xs font-semibold me-2 px-2.5 py-0.5 rounded  text-white  ">
                        {tag}
                    </span>
                </div>
                <div className="ml-auto mt-auto">
                    <div className='flex flex-row  pr-2'>
                        {chains.map((item: any, index: number) => { 
                            const icon = item === "sui" ? "/assets/images/sui-sui-logo.png" : "/assets/images/aptos-logo.png" 
                            return (
                                <img src={icon} key={index} alt="" className='w-[20px] mx-0.5  ' />
                            )
                        })}
                    </div>
                </div>
            </div> */}
           



        </div>
    );
}

export default MarketCard