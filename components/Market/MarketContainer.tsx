
import { useContext, useEffect, useState } from "react";
import { LegatoContext } from "@/hooks/useLegato";
import { ChevronDown, ArrowRight } from "react-feather"
import SelectNetwork from "@/modals/selectNetwork";
import useDatabase from "@/hooks/useDatabase";
import GroupCards from "./GroupCards";
import WalletSui from "../Layouts/WithWallet/WalletSui";
import WalletAptos from "../Layouts/WithWallet/WalletAptos";
import MarketList from "./MarketList"
import Promo from "./Promo"
import MarketDetailsModal from "../../modals/market" 

enum Modal {
    NONE,
    SELECT_NETWORK
}

// const MarketListContainerOLD = () => {

//     const [modal, setModal] = useState(false)
//     const [markets, setMarkets] = useState<any>([])

//     const { getMarkets } = useDatabase()

//     const { currentNetwork } = useContext(LegatoContext)

//     useEffect(() => {
//         getMarkets(currentNetwork).then(setMarkets)
//     }, [currentNetwork])

//     const categories = markets.reduce((output: any, item: any) => {
//         if (output.indexOf(item.category) === -1) {
//             output.push(item.category)
//         }
//         return output
//     }, [])

//     return (
//         <>
//             <SelectNetwork
//                 visible={modal}
//                 close={() => setModal(false)}
//             // hrefs={[`markets/sui`, `markets/aptos`]}
//             />

//             <div className="heading mb-0 text-center lg:text-left ">
//                 <h6 className="inline-block bg-secondary/10 px-2.5 py-2 !text-secondary">markets</h6>
//                 <h4 className="!font-black">
//                     EXPLORE <span className="text-secondary">MARKETS</span>
//                 </h4>
//             </div>
//             <p className="mt-2.5 text-center text-lg font-medium lg:text-left ">
//                 discover active markets by participating in decentralized market forecasting
//             </p>

//             <div className="py-4">

//                 <div className="grid grid-cols-1 sm:grid-cols-5 mb-6">
//                     <div className="col-span-1">
//                         <div onClick={() => setModal(true)} className="w-full cursor-pointer flex flex-row rounded-lg bg-[#141F32]  text-lg border border-gray/30   p-2   text-white  ">
//                             <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={currentNetwork === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"} alt="" />
//                             <div className="mt-auto mb-auto ml-2">
//                                 {currentNetwork.toUpperCase()}
//                             </div>
//                             <div className="ml-auto mt-auto mb-auto ">
//                                 <ChevronDown />
//                             </div>
//                         </div>
//                     </div>
//                 </div>


//                 {categories.map((name: any, index: number) => (
//                     <GroupCards
//                         name={name}
//                         index={index}
//                         items={markets.filter((item: any) => item.category === name)}
//                     />
//                 ))}

//             </div>
//         </>
//     )
// }

const MarketContainer = () => {

    const [modal, setModal] = useState<Modal>(Modal.NONE)
    const [currentMarket, setCurrentMarket] = useState<any>(undefined)

    const { currentNetwork } = useContext(LegatoContext)

    return (
        <>
            <SelectNetwork
                visible={modal === Modal.SELECT_NETWORK}
                close={() => setModal(Modal.NONE)}
                hrefs={[`/markets/sui`, `/markets/aptos`]}
            />
            <MarketDetailsModal
                visible={currentMarket !== undefined}
                close={() => setCurrentMarket(undefined)}
                currentMarket={currentMarket}
            />

            <div className="heading mb-0 text-center lg:text-left ">
                <h6 className="inline-block bg-secondary/10 px-2.5 py-2 !text-secondary">markets</h6>
                <h4 className="!font-black">
                    EXPLORE <span className="text-secondary">MARKETS</span>
                </h4>
            </div>
            <p className="mt-2.5 text-center text-lg font-medium lg:text-left ">
                discover active markets by participating in decentralized market forecasting
            </p>

            <div className="w-full py-4 grid grid-cols-1 lg:grid-cols-3">
                <div className='col-span-1'>
                    <div className="grid grid-cols-1 sm:grid-cols-5  mb-2">
                        <div className="col-span-3">
                            <div onClick={() => setModal(Modal.SELECT_NETWORK)} className="w-full cursor-pointer flex flex-row rounded-lg bg-[#141F32]  text-lg border border-gray/30   p-2   text-white  ">
                                <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={currentNetwork === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"} alt="" />
                                <div className="mt-auto mb-auto ml-2">
                                    {currentNetwork.toUpperCase()}
                                </div>
                                <div className="ml-auto mt-auto mb-auto ">
                                    <ChevronDown />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div className='col-span-2 '>
                    {/* <Promo/> */}
                </div>

                <div className="col-span-3">
                    <MarketList
                        setCurrentMarket={setCurrentMarket}
                    />
                </div>

            </div>

            <Promo/>

        </>
    )
}

export default MarketContainer