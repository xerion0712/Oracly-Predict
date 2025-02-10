import { slugify } from "@/helpers"
import Link from "next/link"

interface IVaultTable {
    name: string
    icon: string
    vaultList: any[]
}

const VaultTable = ({ name, icon, vaultList }: IVaultTable) => {

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

                <div className="  grid grid-cols-12 font-semibold p-0 sm:p-2 gap-1  text-white/50 text-xs sm:text-sm">
                    <div className="col-span-3">Name</div>
                    <div className="col-span-2 sm:col-span-1">Utilization</div>
                    <div className="col-span-2 sm:col-span-1">Net APR</div>
                    <div className="hidden sm:flex col-span-1">Boost APR</div>
                    <div className="hidden sm:flex col-span-1">Base APR</div> 
                    <div className="col-span-3 sm:col-span-2">Total Staked</div>
                    <div className="col-span-2">Unstaking Delay</div>
                    <div className="hidden sm:flex col-span-1">Accepts</div>
                </div>

                {vaultList.map((item, index) => {
                    return (
                        <Link href={`/vault/${name.toLowerCase()}/${slugify(item.name)}`} key={index} className="grid gap-1 text-xs sm:text-base  grid-cols-12  cursor-pointer p-0 sm:p-2 rounded-lg hover:bg-black/50">
                            <div className="col-span-3  flex flex-row">
                                <img className="h-4 sm:h-8 w-4 sm:w-8 rounded-full my-auto flex" src={item.icon} alt="" />
                                <div className="mt-auto mb-auto flex pl-1.5 sm:pl-3.5">
                                    <h2 className="text-white   font-semibold">{item.name}</h2>
                                </div>
                            </div>
                            <div className="col-span-2 sm:col-span-1 flex">
                                <h2 className="text-white my-auto  font-semibold">10%</h2>
                            </div>
                            <div className="col-span-2 sm:col-span-1 flex">
                                <h2 className="text-white my-auto  font-semibold">3%</h2>
                            </div>
                            <div className="col-span-1 hidden sm:flex">
                                <h2 className="text-white my-auto  font-semibold">3%</h2>
                            </div>
                            <div className="col-span-1 hidden sm:flex">
                                <h2 className="text-white my-auto  font-semibold">7.5%</h2>
                            </div>
                            <div className="col-span-3 sm:col-span-2 flex">
                                <h2 className="text-white my-auto  font-semibold">$100.00</h2>
                            </div>
                            <div className="col-span-2 flex">
                                <h2 className="text-white my-auto  font-semibold">{item.unstaking_delay} days</h2>
                            </div>
                            <div className="hidden col-span-1 sm:flex"> 
                                <div className="mt-auto mb-auto flex ">
                                    <h2 className="text-white text-sm font-semibold">
                                        {item.available_asset}
                                    </h2>
                                </div> 
                            </div>

                        </Link>
                    )
                })}

            </div>

        </div>
    )
}

export default VaultTable