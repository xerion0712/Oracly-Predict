
import { FaFire } from "react-icons/fa6";
import BlockchainList from "../../data/blockchain.json"
import Link from "next/link";

interface IMarketCard {
    market_name: string
    icon: string
    popular_outcome?: string
    close_in?: string
    chains?: any
    tag?: string
}


const MarketCard = ({ market_name, icon, popular_outcome, close_in, chains, tag }: IMarketCard) => {
    return (
        <Link href="/markets/coinmarketcap" >
            <div className="p-4 px-2 border-2 cursor-pointer border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg">
                <div className="flex flex-row">
                    <img className="h-8 sm:h-10 w-8 sm:w-10 my-auto rounded-full" src={icon} alt="" />
                    <div className="px-2">
                        <p className="text-white font-semibold line-clamp-3">
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
                        <p className="text-white text-base font-semibold">🕒{` in ${close_in} days`}</p>

                    </div>
                    <div>
                    </div>
                    <div className="flex flex-row ">
                        <img src="https://s2.coinmarketcap.com/static/img/coins/64x64/3408.png" className="h-5 w-5 my-auto mx-1.5" />
                        <p className="text-white text-base font-semibold">
                            {` ${popular_outcome || 0} USDC`}</p>
                    </div>
                </div>
            </div>

        </Link>
    );
}

export default MarketCard