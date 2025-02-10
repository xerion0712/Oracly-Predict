import Link from "next/link"
import { Plus } from "react-feather"
import MarketTable from "./MarketTable"
import { useContext, useEffect, useState } from "react"
import { LegatoContext } from "@/hooks/useLegato"
import useDatabase from "@/hooks/useDatabase"

const CreateMarketContainer = () => {

    const { currentProfile } = useContext(LegatoContext)
    const { getMarketsByCreator } = useDatabase()
    const [ markets, setMarkets ] = useState<any>([])

    useEffect(() => {
        if (currentProfile && currentProfile.id) {
            getMarketsByCreator(currentProfile.id).then(setMarkets)
        }
    },[currentProfile])

    return (
        <>

            <div className="heading mb-0 text-center lg:text-left ">
                <h6 className="inline-block bg-secondary/10 px-2.5 py-2 !text-secondary">markets</h6>
                <h4 className="!font-black">
                    MANAGE <span className="text-secondary">MARKETS</span>
                </h4>
            </div>
            <p className="mt-2.5 text-center text-lg font-medium lg:text-left ">
                Launch your custom market and share fees with Legato
            </p>

            <div className="space-y-3 sm:space-y-4 py-4">

                <div className="grid grid-cols-1 sm:grid-cols-5  mb-6">
                    <div className="col-span-1">
                        <Link href="/auth/my-markets/new">
                            <button type="button" className="btn rounded-lg  bg-white py-3.5 px-10  hover:text-black hover:bg-white flex flex-row">
                                New Market
                                <Plus size={18} className="my-auto ml-1.5" />
                            </button>
                        </Link>

                    </div>
                </div>


                <MarketTable
                    name="APTOS"
                    icon="/assets/images/aptos-logo.png"
                    marketList={markets.filter((item: any) => item.chainId === "aptos")}
                />

                <MarketTable
                    name="SUI"
                    icon="/assets/images/sui-sui-logo.svg"
                    marketList={markets.filter((item: any) => item.chainId === "sui")}
                />

            </div>

        </>
    )
}

export default CreateMarketContainer