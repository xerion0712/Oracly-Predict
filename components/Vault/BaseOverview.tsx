


const BaseOverview = ({ network }: any) => {



    return (
        <div className=" mx-auto w-full flex flex-col  overflow-hidden rounded-lg bg-black px-4 py-4  bg-[url(/assets/images/consulting/business-img.png)]  bg-cover bg-center bg-no-repeat">
            {/* <div className="flex mt-2 mb-1 ">
                <div className="flex flex-row text-sm sm:text-lg text-white">
                    <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={network === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"} alt="" />
                    <div className="mt-auto mb-auto ml-2  ">
                        {network === "sui" ? "SUI" : "APTOS"}
                    </div>
                </div>
                <div className="ml-auto  flex flex-row pr-1 sm:pr-4  justify-between">
                    <h4 className="!font-black text-sm sm:text-base ml-auto mt-[5px] tracking-wide sm:mt-0.5">
                        CURRENT <span className="text-secondary">APY</span>
                    </h4>
                    <h4 className='text-white mr-auto ml-1 sm:ml-3.5 text-2xl sm:text-[28px] leading-7 font-bold'>{(3)?.toLocaleString()}%</h4>
                </div>
            </div>
            <div className="grid grid-cols-4  h-full">
                <div className="col-span-4 sm:col-span-2 hidden sm:flex">
                </div>
                <div className="col-span-4 sm:col-span-2 flex p-2">
                    <div className="my-auto">
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2"> Total Staked:</span>
                            <div className={`   flex flex-row  text-white text-sm `}>
                                
                            </div>
                        </div>
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2">Unstaking Delay:</span>
                            <div className={`   flex flex-row  text-white text-sm `}>
                                1d
                            </div>
                        </div>
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2">Staking Status:</span>
                            <div className={`   flex flex-row  text-white text-sm `}>
                                Active
                            </div>
                        </div>
                    </div>
                </div>
            </div> */}

            {/* <div className="grid grid-cols-4  h-full">
                <div className="col-span-4 sm:col-span-2">
                    <div className="flex flex-row text-sm sm:text-lg text-white">
                        <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={network === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"} alt="" />
                        <div className="mt-auto mb-auto ml-2  ">
                            {network === "sui" ? "SUI" : "APTOS"}
                        </div>
                    </div>
                </div>
                <div className="col-span-4 sm:col-span-2 flex p-2 py-4">
                    <div className="my-auto">
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2"> Base/Boost APR:</span>
                            <div className={`   flex flex-row  text-white text-sm `}>

                            </div>
                        </div>
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2"> Total Staked:</span>
                            <div className={`   flex flex-row  text-white text-sm `}>

                            </div>
                        </div>
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2">Unstaking Delay:</span>
                            <div className={`   flex flex-row  text-white text-sm `}>
                                1d
                            </div>
                        </div> 
                    </div>
                </div>
            </div> */}

            <div className="grid grid-cols-4 h-full">
                <div className="col-span-4 sm:col-span-2 flex">
                    <div className="my-auto  w-full sm:w-[200px]">
                        <h4 className="!font-black ml-auto mt-0.5 text-white uppercase">
                            Legato Next-Gen Prediction Markets <span className="text-secondary">Powered by AI</span>
                        </h4>
                    </div>
                </div>
                <div className="col-span-4 sm:col-span-2 flex p-2">
                    <div className="my-auto">
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2">Total Liquidity:</span>
                            <div className={`flex flex-row  text-white text-sm `}>
                                {/* ${(balance).toLocaleString()} */}
                                -
                            </div>
                        </div>
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2">Base/Boost APR:</span>
                            <div className={` flex flex-row  text-white text-sm `}>
                                {/* {capacity.toLocaleString()} {(symbol)} */}
                                -%
                            </div>
                        </div>
                        {/* <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2">Utilization:</span>
                            <div className={` flex flex-row  text-white text-sm `}>
                                10%
                            </div>
                        </div> */}
                        <div className=" py-0.5 text-sm  flex flex-row">
                            <span className="font-bold mr-2">Unstaking Delay:</span>
                            <div className={` flex flex-row  text-white text-sm `}>
                                {network === "sui" ? "3d" : "Up to 10d"}
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div className="mt-2 flex flex-row  ">
                <div className="relative mt-auto mb-auto">
                    <div className="w-3 h-3 bg-secondary rounded-full"></div>
                    {/* <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-ping"></div>
                    <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-pulse"></div> */}
                </div>
                <div className="font-semibold my-auto mx-2.5 ">
                    Status
                </div>
                <div className=" text-white my-auto flex flex-row">
                    Inactive
                </div>
                <div className="ml-auto text-white  my-auto flex flex-row  pt-[2px] pr-2  text-sm sm:text-lg">
                    <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={network === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"} alt="" />
                    <div className="mt-auto mb-auto ml-2  ">
                        {network === "sui" ? "SUI" : "APTOS"}
                    </div>
                </div>
            </div>

        </div>
    )
}

export default BaseOverview