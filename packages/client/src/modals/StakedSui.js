import { parseAmount, shortAddress } from "@/helpers"
import BaseModal from "./Base"
import { useCallback, useContext, useState } from "react"
import BigNumber from "bignumber.js"
import { TextInput } from "@/components/Input"
import useSuiStake from "@/hooks/useSuiStake"
import Spinner from "@/components/Spinner"

const StakedSuiModal = ({ visible, close, info, validators, isTestnet }) => {

    // const validatorInfo = info && validators && validators.find(v => v.suiAddress.toLowerCase() === info.validatorAddress.toLowerCase())

    const validatorInfo = info && validators && validators.find(v => v.suiAddress.toLowerCase() === info.validatorAddress.toLowerCase())

    const [tab, setTab] = useState(1)

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
                                    <span className="ml-1 block text-white font-medium text-right  ">
                                        {validatorInfo && validatorInfo.name}
                                    </span>
                                </div>
                                <div class="ml-auto  flex font-medium flex-row items-center text-gray-300 text-right text-sm px-2">
                                    APY:
                                    <div className=" ml-1 text-white   ">
                                        {validatorInfo && validatorInfo.apy.toFixed(2)}%
                                    </div>
                                </div>
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

                        <div className="py-1">
                            <div class="border-b-2 border-gray-700">
                                <ul class="flex flex-wrap -mb-px text-sm  text-center text-gray-300">
                                    <li class="me-2">
                                        <div onClick={() => setTab(1)} class={`cursor-pointer inline-flex items-center justify-center p-4 py-2.5 border-b-2 rounded-t-lg  group ${tab === 1 ? "text-white border-blue-700 active" : "border-transparent hover:border-blue-700 "} `}>
                                            Unstake
                                        </div>
                                    </li>
                                    <li class="me-2">
                                        <div onClick={() => setTab(2)} class={`cursor-pointer inline-flex items-center justify-center p-4 py-2.5 border-b-2 rounded-t-lg  group ${tab === 2 ? "text-white border-blue-700 active" : "border-transparent hover:border-blue-700 "} `}>
                                            Transfer
                                        </div>
                                    </li>
                                </ul>
                            </div>
                        </div>

                        {tab === 1 && <UnstakePanel info={info} close={close} />}
                        {tab === 2 && <TransferPanel info={info} close={close} />}

                    </div>
                )
            }

        </BaseModal>
    )
}

const UnstakePanel = ({ info, close }) => {

    const { stakedSuiId } = info

    const { unstake } = useSuiStake()
    const [errorMessage, setErrorMessage] = useState()
    const [loading, setLoading] = useState(false)

    const isActive = info && info.status.toLowerCase() === "active"
    const estReward = isActive && info && BigNumber(info.estimatedReward).dividedBy(10 ** 9)
    const total = isActive && info && (BigNumber(info.estimatedReward).plus(BigNumber(info.principal))).dividedBy(10 ** 9)

    const onUnstake = useCallback(async () => {

        setLoading(true)
        setErrorMessage()

        try {
            await unstake(stakedSuiId)
            close()
        } catch (e) {
            console.log("error:", e)
            setErrorMessage(e.message)
        }

        setLoading(false)

    }, [unstake, stakedSuiId])

    return (
        <>
            {(isActive) && (
                <div className="border rounded-lg mt-2 p-4 border-gray-400">
                    <InfoRow
                        name={"Est. rewards"}
                        value={`${parseAmount(estReward)} SUI`}
                    />
                    <InfoRow
                        name={"You will receive"}
                        value={`${parseAmount(total)} SUI`}
                    />
                </div>
            )}

            {(!isActive) && (
                <div className="border rounded-lg mt-2 flex justify-center items-center h-[80px] font-medium text-sm border-gray-400">
                    Your stake is still pending
                </div>
            )}
            <button disabled={!isActive || loading} onClick={onUnstake} className={`${(!isActive || loading) && "opacity-40"} mt-4 py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700`}>
                {loading && <Spinner />}
                Unstake
            </button>
            {errorMessage && (
                <div className="text-xs font-medium p-2 text-center text-yellow-300">
                    {errorMessage}
                </div>
            )}
        </>
    )
}

const TransferPanel = ({ info, close }) => {

    const { stakedSuiId } = info
    const [toAddress, setAddress] = useState()

    const { transferObject } = useSuiStake()
    const [errorMessage, setErrorMessage] = useState()
    const [loading, setLoading] = useState(false)

    const onTransfer = useCallback(async () => {

        setLoading(true)
        setErrorMessage()

        try {
            await transferObject(stakedSuiId, toAddress)
            close()
        } catch (e) {
            console.log("error:", e)
            setErrorMessage(e.message)
        }

        setLoading(false)

    }, [transferObject, stakedSuiId, toAddress])

    return (
        <>
            <div className="border rounded-lg mt-2 flex justify-center items-center h-[80px] font-medium text-sm border-gray-400">
                <div className="px-4 w-full my-2 flex flex-row">
                    <div className="text-sm text-gray-300  font-medium mt-auto mb-auto mr-2">To:</div>
                    <TextInput
                        placeholder="0x7d20dcdb2bca4f508ea9613994683eb4e76e9c4ed371169677c1be02aaf0b58e"
                        value={toAddress}
                        onChange={(e) => setAddress(e.target.value)}
                    />
                </div>
            </div>
            <button disabled={loading} onClick={onTransfer} className={`${loading && "opacity-40"} mt-4 py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700`}>
                {loading && <Spinner />}
                Transfer
            </button>
            {errorMessage && (
                <div className="text-xs font-medium p-2 text-center text-yellow-300">
                    {errorMessage}
                </div>
            )}
        </>
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