import { parseAmount, shortAddress } from "@/helpers"
import BaseModal from "./Base"
import { useContext } from "react"
import BigNumber from "bignumber.js"

const StakedSuiModal = ({ visible, close, info, validatorInfo, isTestnet }) => {

    console.log("info --> ", info)

    const stakedAmount = info && BigNumber(info.principal).dividedBy(10 ** 9)

    return (
        <BaseModal
            title="Object Details"
            visible={visible}
            close={close}
            borderColor="border-gray-700"
            maxWidth="max-w-lg"
        >

            {
                info && (
                    <div className="flex flex-col">
                        <div className="border rounded-lg mt-2 p-2 border-gray-400">
                            <div className="flex items-center">
                                <div className="p-2 flex flex-row">
                                    <img src={validatorInfo && validatorInfo.imageUrl} alt="" className="h-6 w-6  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                                    <span className="ml-1 block text-white font-medium text-right hover:underline cursor-pointer">
                                        {validatorInfo && validatorInfo.name}
                                    </span>
                                </div>
                                <div class="ml-auto  flex font-medium flex-row items-center text-gray-300 text-right text-sm px-2">
                                    APY:
                                    <div className=" ml-1 text-white  text-base">
                                        {validatorInfo && validatorInfo.apy.toFixed(2)}%
                                    </div>
                                </div>

                                {/* <div class="ml-auto text-gray-300 text-sm font-medium">
                            <a className="hover:underline" href={validator.projectUrl} target="_blank">
                                {validator.projectUrl}
                            </a>

                        </div> */}
                            </div>
                            <div className="p-2  text-gray-300 pt-0 text-xs  ">
                                {validatorInfo && validatorInfo.description}
                            </div>
                            <div className="p-2  text-white pt-0 text-xs  font-medium ">
                                <a className="hover:underline" href={validatorInfo && validatorInfo.projectUrl} target="_blank">
                                    {validatorInfo && validatorInfo.projectUrl}
                                </a>
                            </div>
                        </div>

                        <div className="border rounded-lg mt-4 p-4 border-gray-400">

                            <InfoRow
                                name={"Object ID"}
                                value={`${shortAddress(info.stakedSuiId, 8, -6)}`}
                                link={`https://suiexplorer.com/object/${info.stakedSuiId}${isTestnet ? "?network=testnet" : ""}`}
                            />

                            <InfoRow
                                name={"Staked amount"}
                                value={`${parseAmount(stakedAmount)} SUI`}
                            />

                            <InfoRow
                                name={"Staked since"}
                                value={`Epoch ${info.stakeRequestEpoch}`}
                            />

                            {/* <InfoRow
                                name={"Status"}
                                value={info.status}
                            /> */}

                        </div>
                    </div>
                )
            }

        </BaseModal>
    )
}

const InfoRow = ({ name, value, link }) => {
    return (
        <div class="flex flex-row gap-2 mt-1 mb-2">
            <div class="text-gray-300 text-sm font-medium">
                {name}
            </div>
            <div className="flex-grow text-right font-medium text-sm  mr-3">
                {!link && <>{value}</>}
                {link && <a href={link} className="hover:underline" target="_blank">{value}</a>}
            </div>
        </div>
    )
}


export default StakedSuiModal