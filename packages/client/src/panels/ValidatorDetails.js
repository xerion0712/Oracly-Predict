import BasePanel from "./Base"
import { useEffect, useState } from "react"
import { ArrowRightIcon, ArrowLeftIcon } from "@heroicons/react/20/solid"
import BigNumber from "bignumber.js"

const RowItem = ({
    name,
    value,
    link = false
}) => {
    return (
        <div className="grid grid-cols-2 py-2 gap-5 border-b border-gray-300">
            <div className="col-span-1 mt-auto mb-auto font-medium">
                <h2>{name}</h2>
            </div>
            <div className="col-span-1 mt-auto mb-auto flex">
                {!link && (
                    <h4
                        className="text-lg ml-auto font-extrabold text-white"
                    >
                        {value}
                    </h4>
                )

                }
                {(link && value) && (
                    <a href={value} target="_blank"
                        className="text-lg truncate ml-auto hover:underline  text-white"
                    >
                        {value}
                    </a>
                )}

            </div>
        </div>
    )
}

const ValidatorDetails = ({ visible, close, data, select }) => {

    return (
        <BasePanel
            visible={visible}
            close={close}
        >
            {data && (
                <div className="text-gray-300">
                    <h2 class="text-3xl mb-2 mt-2 font-bold text-white">
                        {`${data.name}`}
                        <span class="bg-blue-100 ml-3 text-blue-800 text-xs font-medium px-2.5 py-0.5 rounded ">#{data.index + 1}</span>
                    </h2>

                    <div className="grid grid-cols-5 p-2 gap-5 py-0 sm:py-4 h-[180px]">
                        <div class="col-span-5 lg:col-span-1">
                            <img
                                class="h-full w-full object-contain object-center"
                                src={data.imageUrl}
                                alt=""
                            />
                        </div>
                        <div class="col-span-5 lg:col-span-4 flex">
                            <div className="text-white mt-auto mb-auto">
                                {data.description}
                            </div>
                        </div>
                    </div>

                    <div class="p-2">
                        <RowItem
                            name="Website"
                            value={data.projectUrl}
                            link={true}
                        />
                        <RowItem
                            name="Staking Volume (24h)"
                            value={`$${(Number(data.vol) * data.suiPrice).toLocaleString()}`}
                        />
                        <RowItem
                            name="Current Staked"
                            value={`${(Number(`${(BigNumber(data.stakingPoolSuiBalance).dividedBy(BigNumber(1000000000)).toFixed(2))}`) / 1000000).toFixed(1)}M SUI`}
                        />
                        <RowItem
                            name="Next Epoch Stake"
                            value={`${(Number(`${(BigNumber(data.nextEpochStake).dividedBy(BigNumber(1000000000)).toFixed(0))}`)).toLocaleString()} SUI`}
                        />
                        <RowItem
                            name="Current APY"
                            value={`${data.apy.toFixed(2)}%`}
                        />
                        <RowItem
                            name="Commission Rate"
                            value={`${(Number(data.commissionRate) / 100).toFixed(2)}%`}
                        />
                    </div>

                    <div class="text-sm font-medium text-gray-300 grid grid-cols-2  p-2">
                        <div >
                            <a onClick={() => {
                                select(data.index-1)
                            }} className="flex flex-row hover:underline cursor-pointer">
                                <ArrowLeftIcon className="h-5 w-5 mr-1" />
                                Back
                            </a>
                        </div>
                        <div className="flex justify-end">
                            <a onClick={() => {
                                select(data.index+1)
                            }} className="flex flex-row hover:underline cursor-pointer">
                                Next
                                <ArrowRightIcon className="h-5 w-5 ml-1" />
                            </a>
                        </div>


                    </div>

                </div>
            )}
        </BasePanel>
    )
}

export default ValidatorDetails