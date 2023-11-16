
import { useEffect, useState } from "react"
import MARKET from "../../data/market.json"
import usePortfolio from "@/hooks/usePortfolio"
import useSui from "@/hooks/useSui"
import BigNumber from "bignumber.js"
import { parseAmount } from "@/helpers"

import { SmallIcon } from "../SuiIcon"

const RowContainer = ({ children }) => (
    <div className="mx-2  border-2 border-gray-700 rounded-md text-sm px-2 mt-1.5 hover:border-blue-700 cursor-pointer ">
        {children}
    </div>
)

const RowStakedSui = ({
    stakingPool,
    validatorAddress,
    stakes,
    validators
}) => {

    const validatorInfo = validators.find(item => item.suiAddress.toLowerCase() === validatorAddress.toLowerCase())

    return (
        <>
            {stakes.map((item, index) => {

                const total = Number(`${(BigNumber(item.principal)).dividedBy(BigNumber(10 ** 9))}`)
                const parsedTotal = parseAmount(total)

                const totalRewards = Number(`${((BigNumber(item.estimatedReward))).dividedBy(BigNumber(10 ** 9))}`)
                const parsedRewards = parseAmount(totalRewards)

                const nextEpochIn = validatorInfo && (validatorInfo.nextEpoch - new Date().valueOf())/1000/60/60

                return (
                    <div key={index}>
                        <RowContainer>
                            <div className="grid grid-cols-12">
                                <div class="col-span-3 ">
                                    <div className="p-1 flex flex-row px-0 ">
                                        <div className=" flex  items-center p-2 pl-1">
                                            <div class="relative">
                                                <img class="h-7 w-7 rounded-full  " src={validatorInfo && validatorInfo.imageUrl} alt="" />
                                            </div>
                                        </div>
                                        <div className="  flex  items-center ">
                                            <h3 class={`text-sm font-medium text-white`}>{validatorInfo && validatorInfo.name}</h3>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-span-2  flex flex-row px-0.5">
                                    <div className="ml-0 my-auto">
                                        <span className="text-gray-300 font-medium mr-1">
                                            APY:
                                        </span>
                                        {validatorInfo && validatorInfo.apy.toFixed(2)}%
                                    </div>
                                </div>
                                <div class="col-span-3  flex flex-row px-0.5">
                                    <div className="ml-0 my-auto flex flex-row">
                                        <span className="text-gray-300 font-medium mr-1">
                                            Staked:
                                        </span>
                                        {`${parsedTotal}`}<SmallIcon className="ml-1" />
                                    </div>
                                </div>
                                <div class="col-span-4  flex flex-row px-0.5">
                                    <div className="ml-0 my-auto flex flex-row">
                                        {item.status.toLowerCase() === "active" && (
                                            <>
                                                <span className="text-gray-300 font-medium mr-1">
                                                    Est. rewards:
                                                </span>
                                                {`${parsedRewards}`}<SmallIcon className="ml-1" />
                                            </>
                                        )

                                        }
                                        {item.status.toLowerCase() === "pending" && (
                                            <>
                                                <span className="text-gray-300 font-medium mr-1">
                                                    Pending to stake in {nextEpochIn ? nextEpochIn.toFixed(0) : 0} hrs.
                                                </span>
                                            </>
                                        )

                                        }
                                    </div>
                                </div>

                            </div>
                        </RowContainer>
                    </div>
                )
            })}
        </>

    )
}

const AssetList = ({ assetKey, account, isTestnet }) => {

    const market = MARKET[assetKey]

    const [objects, setObjects] = useState([])
    const [validators, setValidators] = useState([])

    const { fetchSuiSystem } = useSui()

    const { getAllObjectsByKey } = usePortfolio()

    useEffect(() => {
        assetKey && getAllObjectsByKey(assetKey, account.address, isTestnet).then(setObjects)
    }, [assetKey, account, isTestnet])

    useEffect(() => {
        assetKey === "SUI_TO_STAKED_SUI" && fetchSuiSystem(isTestnet ? "testnet" : "mainnet").then(
            ({ summary, validators }) => {
                const nextEpoch = new Date(Number(summary.epochStartTimestampMs) + Number(summary.epochDurationMs))
                setValidators(validators.map(item => ({ ...item, epoch: summary.epoch, nextEpoch })))
            }
        )
    }, [assetKey, isTestnet])

    return (
        <div className="w-full">

            <div className="flex  flex-col">
                <div className="  flex flex-row gap-3 p-2 pt-0 ">
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
                            Available Balance
                            <h3 class={`text-lg font-medium text-white`}>
                                $100
                            </h3>
                        </div>
                        <div className="col-span-1 border-2 border-gray-700   px-8 border-l-0 p-2 rounded-r-md">
                            Pending
                            <h3 class={`text-lg font-medium text-white`}>
                                $100
                            </h3>
                        </div>
                    </div>
                </div>
                {/* TABLE */}
                <div class="text-gray-300 text-sm px-2">
                    All Assets
                </div>

                {objects.map((item, key) => {

                    return (
                        <div key={key}>
                            {item.assetKey === "SUI_TO_STAKED_SUI" && <RowStakedSui validators={validators} {...item} />}
                        </div>
                    )
                })}
            </div>
        </div>
    )
}

export default AssetList