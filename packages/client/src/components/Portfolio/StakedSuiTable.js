import { useEffect, useState } from "react"
import MARKET from "../../data/market.json"
import usePortfolio from "@/hooks/usePortfolio"
import useSui from "@/hooks/useSui"
import { shortAddress } from "@/helpers"
import BigNumber from "bignumber.js"
import { parseAmount } from "@/helpers"

import { SmallIcon } from "../SuiIcon"
import { Badge, YellowBadge } from "../Badge"
import StakedSuiModal from "@/modals/StakedSui"
import useSuiStake from "@/hooks/useSuiStake"

const RowContainer = ({ children }) => (
    <div className="mx-2  border-2 border-gray-700 rounded-md text-sm px-2 mt-1.5 hover:border-blue-700 cursor-pointer ">
        {children}
    </div>
)

const TabPanel = ({
    perValidator,
    validators,
    isTestnet
}) => {

    const validatorInfo = validators.find(item => item.suiAddress.toLowerCase() === perValidator.validatorAddress.toLowerCase())

    const [selected, setSelected] = useState(undefined)

    return (
        <>
            <StakedSuiModal
                visible={selected !== undefined}
                close={() => setSelected(undefined)}
                info={selected}
                validatorInfo={validatorInfo}
                isTestnet={isTestnet}
            />

            {perValidator.stakes.map((item, index) => {

                const total = Number(`${(BigNumber(item.principal)).dividedBy(BigNumber(10 ** 9))}`)
                const parsedTotal = parseAmount(total)

                const totalRewards = Number(`${((BigNumber(item.estimatedReward))).dividedBy(BigNumber(10 ** 9))}`)
                const parsedRewards = parseAmount(totalRewards)

                const nextEpochIn = validatorInfo && (validatorInfo.nextEpoch - new Date().valueOf()) / 1000 / 60 / 60

                const last = validatorInfo && Number(validatorInfo.epoch) - Number(item.stakeActiveEpoch)

                return (
                    <div onClick={() => setSelected({
                        ...item,
                    })} key={index}>
                        <RowContainer>
                            <div className="grid grid-cols-12 py-2">
                                {/* <div class="col-span-2  flex flex-row px-0.5">
                                    <div className="ml-0 my-auto">
                                        <span className="text-gray-300 font-medium mr-1">
                                            APY:
                                        </span>
                                        {validatorInfo && validatorInfo.apy.toFixed(2)}%
                                    </div>
                                </div> */}
                                <div class="col-span-3  flex flex-row px-0.5">
                                    <div className="ml-0 my-auto flex flex-row">
                                        <span className="text-gray-300 font-medium mr-1">
                                            ID:
                                        </span>
                                        {shortAddress(item.stakedSuiId, 2, -4)}
                                    </div>
                                </div>
                                <div class="col-span-3  flex flex-row px-0.5">
                                    <div className="ml-0 my-auto flex flex-row">
                                        <span className="text-gray-300 font-medium mr-1">
                                            Staked:
                                        </span>
                                        {`${parsedTotal} SUI`}
                                    </div>
                                </div>
                                <div class="col-span-4  flex flex-row px-0.5">
                                    <div className="ml-0 my-auto flex flex-row">
                                        {item.status.toLowerCase() === "active" && (
                                            <>
                                                <span className="text-gray-300 font-medium mr-1">
                                                    Est. rewards:
                                                </span>
                                                {`${parsedRewards} SUI`}
                                            </>
                                        )}
                                        {item.status.toLowerCase() === "pending" && (
                                            <>
                                                <span className="text-gray-300 font-medium mr-1">
                                                    Pending to stake in {nextEpochIn ? nextEpochIn.toFixed(0) : 0} hrs.
                                                </span>
                                            </>
                                        )}
                                    </div>
                                </div>
                                <div class="col-span-2 flex flex-row ">
                                    {item.status.toLowerCase() === "active" ? (
                                        <div className="ml-auto my-auto flex flex-row">
                                            <Badge>{last} epo.</Badge>
                                        </div>
                                    ) : <>
                                        <div className="ml-auto my-auto flex flex-row">
                                            <YellowBadge>pending</YellowBadge>
                                        </div>
                                    </>}

                                </div>
                            </div>
                        </RowContainer>
                    </div>
                )
            })

            }
        </>
    )
}


const StakedSuiTable = ({ assetKey, account, isTestnet }) => {

    const market = MARKET[assetKey]

    const { getAllObjectsByKey } = usePortfolio()
    const { getTotalStaked } = useSuiStake()

    const [tab, setTab] = useState(0)

    const [perValidators, setPerValidators] = useState([])
    const [validators, setValidators] = useState([])
    const [totalStaked, setTotalStaked] = useState(0)
    const [totalPending, setTotalPending] = useState(0)

    const { fetchSuiSystem } = useSui()

    useEffect(() => {
        getAllObjectsByKey(assetKey, account.address, isTestnet).then(setPerValidators)
    }, [account, isTestnet])

    useEffect(() => {
        setTimeout(() => {
            getTotalStaked(account.address, isTestnet).then(
                ({ suiPrice, totalStaked, totalPending }) => {
                    const totalStakedUsd = BigNumber(totalStaked).dividedBy(10 ** 9).multipliedBy(suiPrice)
                    setTotalStaked(Number(`${totalStakedUsd}`))
                    
                    const totalPendingUsd = BigNumber(totalPending).dividedBy(10 ** 9).multipliedBy(suiPrice)
                    setTotalPending(Number(`${totalPendingUsd}`))
                }
            )
        }, 1000)
    }, [account, isTestnet])

    useEffect(() => {
        fetchSuiSystem(isTestnet ? "testnet" : "mainnet").then(
            ({ summary, validators }) => {
                const nextEpoch = new Date(Number(summary.epochStartTimestampMs) + Number(summary.epochDurationMs))
                setValidators(validators.map(item => ({ ...item, epoch: summary.epoch, nextEpoch })))
            }
        )
    }, [isTestnet])

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
                            Total Staked
                            <h3 class={`text-lg font-medium text-white`}>
                                ${Number(totalStaked).toLocaleString()}
                            </h3>
                        </div>
                        <div className="col-span-1 border-2 border-gray-700   px-8 border-l-0 p-2 rounded-r-md">
                            Pending
                            <h3 class={`text-lg font-medium text-white`}>
                                ${Number(totalPending).toLocaleString()}
                            </h3>
                        </div>
                    </div>
                </div>
                {
                    perValidators.length === 0 && (
                        <div class="text-gray-300 text-sm px-2">
                            All Assets (0)
                        </div>
                    )
                }
                {
                    perValidators.length !== 0 && (
                        <div className="px-2">
                            <div class="border-b-2 border-gray-700">
                                <ul class="flex flex-wrap -mb-px text-sm  text-center text-gray-300">
                                    {perValidators.map((item, index) => {
                                        const validatorInfo = validators.find(v => v.suiAddress.toLowerCase() === item.validatorAddress.toLowerCase())
                                        return (
                                            <li key={index} class="me-2">
                                                <div onClick={() => setTab(index)} class={`cursor-pointer inline-flex items-center justify-center ${validatorInfo ? "p-2" : "p-4"} py-2.5 border-b-2 rounded-t-lg  group ${index === tab ? "text-white border-blue-700 active" : "border-transparent hover:border-blue-700 "} `}>
                                                    {validatorInfo ? <><div className=" flex flex-row">
                                                        <div className=" flex  items-center ">
                                                            <div class="relative">
                                                                <img class="h-5 w-5 rounded-full  " src={validatorInfo.imageUrl} alt="" />
                                                            </div>
                                                        </div>
                                                        <div className=" ml-1 flex  items-center ">
                                                            <h3 class={`text-sm  text-white`}>{validatorInfo.name}</h3>
                                                        </div>
                                                    </div></> : shortAddress(item.validatorAddress, 5, -3)}
                                                </div>
                                            </li>
                                        )
                                    })}

                                </ul>
                            </div>
                        </div>
                    )
                }
                {perValidators.length > 0 && perValidators[tab] && (
                    <TabPanel
                        perValidator={perValidators[tab]}
                        validators={validators}
                        isTestnet={isTestnet}
                    />
                )}


            </div>
        </div>
    )
}

export default StakedSuiTable