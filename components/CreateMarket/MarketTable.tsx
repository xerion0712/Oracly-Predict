import { slugify } from "@/helpers"
import Link from "next/link"

interface IMarketTable {
    name: string
    icon: string
    marketList: any[]
}

const MarketTable = ({ name, icon, marketList }: IMarketTable) => {


    marketList = []

    return (
        <div className="space-y-0">
            <div className={`bg-white dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent  rounded-t-xl  px-2 sm:px-5  border border-transparent h-[60px] sm:h-[70px]`} >
                <div className='grid grid-cols-7 h-full'>
                    <div className="col-span-3 sm:col-span-2 flex ">
                        <div className='mt-auto mb-auto flex flex-row'>
                            <div className="mt-auto mb-auto flex items-center ">
                                <img className="h-6 sm:h-8 w-6 sm:w-8 rounded-full" src={icon} alt="" />
                            </div>
                            <div className="mt-auto mb-auto flex pl-3.5">
                                <h2 className='text-base lg:text-lg tracking-tight font-semibold text-white'>{name}</h2>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div className="bg-gray-dark  px-2 py-4 rounded-b-xl ">

                <div className="grid grid-cols-10 font-semibold p-0 sm:p-2 gap-1  text-white/50 text-xs sm:text-sm">
                    <div className="col-span-2">Title</div>
                    <div className="col-span-4">Description</div>
                    {/* <div className="col-span-1">Round</div> */}
                    <div className="col-span-1">Status</div> 
                    <div className="col-span-1">Closing Date</div>
                    <div className="col-span-1">Resolved Date</div> 
                </div>

                {marketList.sort((a: any, b: any) => {
                    return new Date(b.closingDate).getTime() - new Date(a.closingDate).getTime()
                }).map((item: any, index: number) => {
                    return (
                        <Link href={"#"} key={index} className="grid gap-1 text-xs sm:text-base grid-cols-10  cursor-pointer p-0 sm:p-2 rounded-lg hover:bg-black/50">
                            <div className="col-span-2 text-white font-semibold">
                                {item.title}
                            </div>
                            <div className="col-span-4 text-white font-semibold">
                                {item.description}
                            </div>
                            {/* <div className="col-span-1 text-white font-semibold">
                                {item.round}
                            </div> */}
                            <div className="col-span-1 text-white font-semibold">
                                {item.status}
                            </div> 
                            <div className="col-span-1 text-white font-semibold">
                                {(new Date(item.closingDate)).toLocaleDateString()}
                            </div>
                            <div className="col-span-1 text-white font-semibold">
                                {item.resolutionDate ? (new Date(item.resolutionDate)).toLocaleDateString() : "Not set"}
                            </div>


                            {/* <div className="col-span-3 sm:col-span-2 flex">
                                <h2 className="text-white my-auto  font-semibold">$100.00</h2>
                            </div>
                            <div className="col-span-2 flex">
                                <h2 className="text-white my-auto  font-semibold">{item.unstaking_delay} days</h2>
                            </div> */}
                        </Link>
                    )
                })}

            </div>

        </div>
    )
}

export default MarketTable