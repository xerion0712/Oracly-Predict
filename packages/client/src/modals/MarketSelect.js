import BaseModal from "./Base"
import MARKET from "../data/market.json"
import { useContext } from "react"
import { LegatoContext } from "@/hooks/useLegato"
import { Badge, YellowBadge } from "@/components/Badge"


const MarketSelectModal = ({ visible, close, currentMarket, info }) => {

    const { updateMarket } = useContext(LegatoContext)

    let currentKey

    const marketList = Object.keys(MARKET).map((key) => {

        if (currentMarket === MARKET[key]) currentKey = key

        return {
            key,
            active: currentMarket === MARKET[key],
            ...MARKET[key]
        }
    })

    return (
        <BaseModal
            title="Select Market"
            visible={visible}
            close={close}
            borderColor="border-gray-700"
            maxWidth="max-w-4xl"
        >
            <div class="grid grid-cols-7 gap-2 my-4 h-[30vh]">
                <div className="col-span-2 p-1">

                    {marketList.map((item, index) => {
                        return (
                            <div key={index} onClick={() => updateMarket(item.key)} class={` ${item.active && "bg-gray-700"} flex gap-4 items-center border-2 border-gray-700  hover:border-blue-700 flex-1 p-2 mb-2 hover:cursor-pointer py-3 px-5  rounded-md`}>
                                <div class="relative">
                                    <img class="h-12 w-12 rounded-full" src={item.img} alt="" />
                                    {item.isPT && <img src="/pt-badge.png" class="bottom-0 right-7 absolute  w-7 h-4  " />}
                                </div>
                                <div>
                                    <h3 class={`text-xl font-medium text-white`}>{item.from}</h3>
                                    <span class="text-sm tracking-wide text-gray-400">{item.to}</span>
                                </div>
                            </div>
                        )
                    })}

                </div>
                <div className="col-span-5 p-1 border-l-2 border-gray-700">

                    <div className="   rounded-md px-4 py-2">
                        <div class="grid grid-cols-7 gap-3  ">
                            <div className="col-span-2">
                                <span className="font-bold">
                                    Stake:
                                </span>
                                <span className="ml-1  ">
                                    {currentMarket.from}
                                </span>

                            </div>
                            <div className="col-span-2">
                                <span className="font-bold">
                                    For:
                                </span>
                                <span className="ml-1  ">
                                    {currentMarket.to}
                                </span>
                            </div>
                            <div className="col-span-1">
                                <span className="font-bold">
                                    APY:
                                </span>
                                <span className="ml-1  ">
                                    {currentKey === "SUI_TO_STAKED_SUI" && `${info && info.suiSystemApy && info.suiSystemApy.toFixed(2)}%`}
                                </span>
                            </div>
                        </div>

                        <p className="text-sm mt-2 text-gray-400">
                            {currentMarket.description}
                        </p>

                        <div className="mt-2">

                            {currentMarket.networks.find(item => item === "mainnet") && (
                                <Badge>
                                    Mainnet
                                </Badge>
                            )}

                            {currentMarket.networks.find(item => item === "testnet") && (
                                <YellowBadge>
                                    Testnet
                                </YellowBadge>
                            )}
                        </div>

                    </div>

                </div>
            </div>


        </BaseModal>
    )
}

export default MarketSelectModal