import { ChevronRight } from "react-feather"
import { shortAddress } from "@/helpers"
import { Badge, BadgeWhite } from "@/components/Badge"


const Overview = () => {



    return (
        <>

            <div className="mx-auto w-full flex flex-col  overflow-hidden rounded-lg bg-black px-4 py-4  bg-[url(/assets/images/consulting/business-img.png)]  bg-cover bg-center bg-no-repeat">
                <div className="flex mt-2 mb-1 ">
                    <div className="flex flex-row text-sm sm:text-lg text-white">
                        <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={"/assets/images/sui-sui-logo.png"} alt="" />
                        <div className="mt-auto mb-auto ml-2  ">
                            SUI
                        </div>
                    </div>
                    {/* <div className="ml-auto  flex flex-row pr-1 sm:pr-4">
                        <div className="relative mt-auto mb-auto">
                            <div className="w-3 h-3 bg-secondary rounded-full"></div>
                            <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-ping"></div>
                            <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-pulse"></div>
                        </div>
                        <div className="font-semibold my-auto mx-2.5 ">
                            Validator
                        </div>
                        <div className=" text-white flex flex-row">
                            <div className="my-auto font-semibold">
                                0x12345
                            </div>
                        </div>
                    </div> */}
                </div>
                <div className="grid grid-cols-4 h-full">
                    <div className="col-span-4 sm:col-span-2 hidden sm:flex">
                        <div className="my-auto pl-2">
                            <div className=" py-0.5 text-sm  flex flex-row">
                                <span className="font-bold mr-2"> Net APR:</span>
                                <div className={`   flex flex-row  text-white text-sm `}>
                                    7%
                                </div>
                            </div>
                            <div className=" py-0.5 text-sm  flex flex-row">
                                <span className="font-bold mr-2">Boost APR:</span>
                                <div className={`   flex flex-row  text-white text-sm `}>
                                    2%
                                </div>
                            </div>
                            <div className=" py-0.5 text-sm  flex flex-row">
                                <span className="font-bold mr-2">Base APR:</span>
                                <div className={`   flex flex-row  text-white text-sm `}>
                                    5%
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="col-span-4 sm:col-span-2 flex p-2">
                        <div className="my-auto">
                            <div className=" py-0.5 text-sm  flex flex-row">
                                <span className="font-bold mr-2"> Total Staked:</span>
                                <div className={`   flex flex-row  text-white text-sm `}>
                                    $1000
                                </div>
                            </div>
                            <div className=" py-0.5 text-sm  flex flex-row">
                                <span className="font-bold mr-2">Unstaking Delay:</span>
                                <div className={`   flex flex-row  text-white text-sm `}>
                                    10d
                                </div>
                            </div>
                            <div className=" py-0.5 text-sm  flex flex-row">
                                <span className="font-bold mr-2">Utilization:</span>
                                <div className={`   flex flex-row  text-white text-sm `}>
                                    12%
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div className="mt-0.5 flex flex-row  ">
                    {/* <div className="relative mt-auto mb-auto">
                        <div className="w-3 h-3 bg-secondary rounded-full"></div>
                        <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-ping"></div>
                        <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-pulse"></div>
                    </div>
                    <div className="font-semibold my-auto mx-2.5 ">
                        Validator
                    </div>
                    <div className=" text-white flex flex-row">
                        <div className="my-auto font-semibold">
                            10.34%
                        </div>
                    </div> */}
                    <div className="ml-auto pr-2">
                        {/* <div className="flex flex-row text-sm sm:text-lg text-white">
                            <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={"/assets/images/sui-sui-logo.png"} alt="" />
                            <div className="mt-auto mb-auto ml-2  ">
                                SUI
                            </div>
                        </div> */}
                        {/* <BadgeWhite>
                        Read more{` >>`}
                    </BadgeWhite> */}
                    </div>
                </div>
            </div>
        </>
    )
}

export default Overview