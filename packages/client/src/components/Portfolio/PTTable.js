
import MARKET from "../../data/market.json"

const PTTable = ({ assetKey }) => {

    const market = MARKET[assetKey]

    return (
        <div className="w-full">
            <div className="flex  flex-col">
                <div className="flex flex-row gap-3 p-2 pt-0 ">
                    <div className="grid grid-cols-3 w-full my-1 text-center text-sm text-gray-300">
                        <div className="col-span-1 border-2 border-gray-700  p-2 flex flex-row  rounded-l-md">
                            <div className=" flex  items-center p-2">
                                <div class="relative">
                                    <img class="h-8 w-8 rounded-full  " src={market.img} alt="" />
                                    {market.isPT && <img src="/pt-badge.png" class="bottom-0 right-4 absolute  w-7 h-4  " />}
                                </div>
                            </div>
                            <div className="  flex  items-center ">
                                <h3 class={`text-base font-medium text-white`}>{market.to}</h3>
                            </div>
                        </div>
                        
                        <div className="col-span-1 border-2  border-l-0 border-gray-700   px-8    p-2  ">
                            Total Staked
                            <h3 class={`text-lg font-medium text-white`}>
                                $0
                            </h3>
                        </div>
                        <div className="col-span-1 border-2 border-gray-700   px-8 border-l-0 p-2 rounded-r-md">
                            Pending
                            <h3 class={`text-lg font-medium text-white`}>
                                $0
                            </h3>
                        </div>
                    </div>
                </div>

                <div class="text-gray-300 text-sm px-2">
                    All Assets (-)
                </div>

            </div>
        </div>
    )
}

export default PTTable