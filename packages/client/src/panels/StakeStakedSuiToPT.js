import { useWallet } from "@suiet/wallet-kit"
import BasePanel from "./Base"
import usePortfolio from "@/hooks/usePortfolio"
import { useCallback, useContext, useEffect, useReducer, useState } from "react"
import { LegatoContext } from "@/hooks/useLegato"
import BigNumber from "bignumber.js"
import { Badge, YellowBadge } from "@/components/Badge"
import { X } from "react-feather"
import { AmountInput } from "@/components/Input"
import { OptionBadge } from "@/components/Badge"
import useSui from "@/hooks/useSui"
import { useInterval } from "@/hooks/useInterval"
import { parseAmount, secondsToDDHHMMSS } from "@/helpers"
import Spinner from "@/components/Spinner"


const StakeStakedSuiToPT = ({
    visible,
    close,
    isTestnet,
    vault,
    tick
}) => {

    const { account } = useWallet()
    const { getCurrentEpoch } = useSui()
    const { getAllObjectsByKey } = usePortfolio()
    const { validators, summary, mint } = useContext(LegatoContext)

    const [countdown, setCountdown] = useState(`0d 0h 0m 0s`)

    const [values, dispatch] = useReducer(
        (curVal, newVal) => ({ ...curVal, ...newVal }),
        {
            myStakedSui: [],
            selected: undefined,
            modal: false,
            amount: 0,
            disabled: false,
            loading: false,
            errorMessage: undefined
        }
    )

    const { myStakedSui, selected, modal, amount, disabled, loading, errorMessage } = values

    useEffect(() => {
        account && account.address ? getAllObjectsByKey("SUI_TO_STAKED_SUI", account.address, isTestnet).then((myStakedSui) => dispatch({ myStakedSui, selected: undefined })) : dispatch({ myStakedSui: [], selected: undefined })
    }, [account, isTestnet, tick])

    useEffect(() => {
        myStakedSui && myStakedSui[0] && myStakedSui[0].stakes[0] && dispatch({
            selected: {
                stakingPool: myStakedSui[0].stakingPool,
                ...myStakedSui[0].stakes[0]
            }
        })
    }, [myStakedSui])

    useInterval(
        () => {

            const current = new Date()

            const diffEpoch = Number(vault.maturity_epoch) - Number(summary.epoch)
            const matureDate = new Date((new Date(Number(summary.epochStartTimestampMs))).valueOf() + (Number(summary.epochDurationMs) * (diffEpoch > 0 ? diffEpoch : 0)))

            const diffTime = Math.abs(matureDate - current);
            const totals = Math.floor(diffTime / 1000)

            const { days, hours, minutes, seconds } = secondsToDDHHMMSS(totals)

            setCountdown(`${days}d ${hours}h ${minutes}m ${seconds}s`)
        },
        1000,
    )

    const handleChange = (e) => {
        dispatch({
            amount: Number(e.target.value)
        })
    }

    const onMint = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!summary || !vault || !selected) return

        if (Number(summary.epoch) > (Number(vault.maturity_epoch) - 3)) {
            dispatch({ errorMessage: "Not allowing to mint during cooldown epochs" })
            return
        }

        if (1 > amount) {
            dispatch({ errorMessage: "Amount must be greater than 1" })
            return
        }

        dispatch({ loading: true })

        try {

            await mint(vault, amount, selected)

            dispatch({ amount: 0, loading: false })
            close()

        } catch (e) {
            console.log(e)
            dispatch({ errorMessage: `${e.message}` })
        }

        dispatch({ loading: false })

    }, [summary, vault, amount, selected])

    const validator = selected && validators && validators.find(v => v.stakingPoolId === selected.stakingPool)

    const totalAssets = myStakedSui.reduce((output, item) => {
        return output + item.stakes.length
    }, 0)

    const available = selected ? Number(`${(BigNumber(selected.principal)).dividedBy(BigNumber(10 ** 9))}`) : 0
    const apy = vault && Number(`${(BigNumber(vault.vault_apy)).dividedBy(BigNumber(10 ** 7))}`)

    const ptMulfiplier = summary && vault && 1 + ((Number(`${(BigNumber(vault.vault_apy)).dividedBy(BigNumber(10 ** 9))}`)) * (Number(vault.maturity_epoch) - Number(summary.epoch)) / 365)
    const ptAmount = ptMulfiplier ? amount * ptMulfiplier : 0

    return (
        <>
            <BasePanel
                visible={visible}
                close={close}
            >
                {modal && (
                    <Modal
                        totalAssets={totalAssets}
                        dispatch={dispatch}
                        myStakedSui={myStakedSui}
                        validators={validators}
                        selected={selected}
                    />
                )}
                <h2 class="text-2xl mb-2 mt-2 font-bold">
                    Mint ptStaked SUI
                </h2>
                <hr class="my-12 h-0.5 border-t-0 bg-neutral-100 mt-2 mb-2 opacity-50" />
                <p class="  text-sm text-gray-300  mt-2">
                    Lock in the APY of Staked SUI objects with today's floor rates. You will receive ptStaked SUI, representing the future value of your object. This can be traded now on the DEX or redeemed at a 1:1 ratio after the vault matures.
                </p>

                <div onClick={() => totalAssets > 0 && dispatch({ modal: true })} className={`border rounded-lg mt-4 p-4 border-gray-400 ${totalAssets > 0 && "hover:border-blue-700 cursor-pointer"}`}>
                    <div className="flex items-center">
                        <img src={validator && validator.imageUrl} alt="" className="h-6 w-6  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                        <span className="ml-1 block text-white font-medium text-right  ">
                            {validator ? validator.name : " "}
                        </span>
                        {selected && (
                            <>
                                <span className="ml-2">
                                    {selected.status.toLowerCase() === "active" ? (
                                        <div className="ml-auto my-auto flex flex-row">
                                            <Badge>ready</Badge>
                                        </div>
                                    ) : <>
                                        <div className="ml-auto my-auto flex flex-row">
                                            <YellowBadge>pending</YellowBadge>
                                        </div>
                                    </>}
                                </span>
                            </>
                        )}
                        <div class="ml-auto text-gray-300 text-sm font-medium">
                            <div className='flex flex-row'>
                                <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                                {available.toLocaleString()}{` SUI`}
                            </div>
                        </div>
                    </div>
                </div>

                <div class="text-gray-300 text-xs font-medium my-2 text-center ">
                    {totalAssets === 0 ? "No " : `${totalAssets}`} Staked SUI objects are present in your account
                </div>

                <div className="border rounded-lg mt-0 p-4 border-gray-400">
                    <div className="block leading-6 mb-2 text-gray-300 ">Amount to convert</div>
                    <AmountInput
                        icon="./sui-sui-logo.svg"
                        tokenName="SUI"
                        value={amount}
                        onChange={handleChange}
                    />
                    <div className="text-xs flex flex-row text-gray-300 border-gray-400  ">
                        <div className="font-medium ">
                            Available: {Number(available).toFixed(3)} SUI
                        </div>
                        <div className="ml-auto  flex flex-row ">
                            <OptionBadge onClick={() => available && Number(available) >= 1 ? dispatch({ amount: 1 }) : 0} className="cursor-pointer hover:underline">
                                1 SUI
                            </OptionBadge>
                            <OptionBadge onClick={() => dispatch({ amount: (Math.floor(Number(available) * 500) / 1000) })} className="cursor-pointer hover:underline">
                                50%
                            </OptionBadge>
                            <OptionBadge onClick={() => dispatch({ amount: (Math.floor(Number(available) * 1000) / 1000) })} className="cursor-pointer hover:underline">
                                Max
                            </OptionBadge>
                        </div>
                    </div>
                </div>

                <div className="border rounded-lg mt-4 p-4 border-gray-400">
                    <div class="mt-2 flex flex-row">
                        <div class="text-gray-300 text-sm font-medium">You will receive</div>
                        <span class="ml-auto bg-blue-100 text-blue-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-blue-900 dark:text-blue-300">
                            Vault matures in {countdown}
                        </span>
                    </div>
                    <hr class="h-px my-4 border-0  bg-gray-600" />
                    <div class="grid grid-cols-2 gap-2 mt-2 mb-2">
                        <div>
                            <h2 className="text-3xl font-medium">
                                ptStaked SUI
                            </h2>
                            <div class="text-gray-300 text-sm font-medium">
                                Fungible Token
                            </div>
                        </div>
                        <div className="flex">
                            <div className="text-3xl font-medium mx-auto mt-3 mb-auto mr-2">
                                {parseAmount(ptAmount)}
                            </div>
                        </div>
                    </div>
                    {/* <InfoRow
                        name={"Vault matures in"}
                        value={`${vault.value}`}
                    /> */}
                    <InfoRow
                        name={"Epoch at the moment"}
                        value={`${summary ? summary.epoch : 0}`}
                    />
                    <InfoRow
                        name={"Vault creation/maturity epoch"}
                        value={`${vault.created_epoch}/${vault.maturity_epoch}`}
                    />
                    <InfoRow
                        name={"Last epoch eligible for minting"}
                        value={`${Number(vault.maturity_epoch) - 3}`}
                    />
                    <InfoRow
                        name={"APY to lock-in"}
                        value={`${apy}%`}
                    />
                    <div className="w-full text-xs my-3 font-medium p-2 py-1 text-center rounded border border-blue-400 text-blue-400">
                        The vault is in private alpha, reach out to the team for grant access
                    </div>
                    <hr class="h-px my-4 border-0 bg-gray-600" />
                    <button disabled={disabled} onClick={onMint} className={`py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700 ${disabled && "opacity-60"}`}>
                        {loading && <Spinner />}
                        Mint
                    </button>
                    {errorMessage && (
                        <div className="text-xs font-medium p-2 text-center text-yellow-300">
                            {errorMessage}
                        </div>
                    )}

                </div>

            </BasePanel>
        </>
    )
}

const InfoRow = ({ name, value }) => {
    return (
        <div class="grid grid-cols-2 gap-2 mt-1 mb-2">
            <div class="text-gray-300 text-sm font-medium">
                {name}
            </div>
            <div className=" font-medium text-sm ml-auto mr-3">
                {value}
            </div>
        </div>
    )
}


const Modal = ({
    totalAssets,
    dispatch,
    myStakedSui,
    validators,
    selected
}) => {
    return (
        <div class="fixed inset-0 flex items-center justify-center  z-50">
            <div class="absolute inset-0 bg-gray-900 opacity-50"></div>
            <div class={`relative   bg-gray-800 p-6 w-full ml-5 mr-7 mb-[200px]  border  border-gray-700 text-white rounded-lg`}>
                <h5 class="text-xl font-bold mb-2"> All Staked SUI ({totalAssets})</h5>
                <button class="absolute top-3 right-3 text-gray-500 hover:text-gray-400" onClick={() => dispatch({ modal: false })}>
                    <X />
                </button>
                <div className="grid grid-cols-3 gap-2 mt-4 mb-2">
                    {myStakedSui.map((perValidator, x) => {

                        const perValidatorInfo = validators && validators.find(v => v.stakingPoolId === perValidator.stakingPool)
                        const imageUrl = perValidatorInfo.imageUrl || "/sui-sui-logo.svg"

                        return (
                            <>
                                {perValidator.stakes.map((item, y) => {

                                    const amount = Number(`${(BigNumber(item.principal)).dividedBy(BigNumber(10 ** 9))}`)
                                    const isActive = selected && item && item.stakedSuiId === selected.stakedSuiId

                                    return (
                                        <div onClick={() => {
                                            dispatch({
                                                modal: false,
                                                amount: 0,
                                                selected: {
                                                    stakingPool: perValidator.stakingPool,
                                                    ...item
                                                }
                                            })
                                        }} className={`col-span-1  border-2 border-gray-700 ${isActive && "bg-gray-700"} p-2 rounded-md hover:border-blue-700 flex-1  hover:cursor-pointer flex`} key={`${x}-${y}`}>
                                            <div class="my-auto">
                                                <div class="w-1/2 mx-auto mt-1">
                                                    <img
                                                        class="h-full w-full object-contain object-center rounded-full"
                                                        src={imageUrl}
                                                        alt=""
                                                    />
                                                </div>
                                                <div className="p-2 px-1 pb-0 text-center">
                                                    <h3 class="text-sm font-medium leading-4 text-white">{perValidatorInfo.name}</h3>
                                                    <h3 class="text-sm p-1 mr-2 text-white leading-4">
                                                        {`${amount.toLocaleString()} SUI`}
                                                    </h3>
                                                    {/* {item.status.toLowerCase() === "active" ? (
                                                    <Badge>ready</Badge>
                                                ) : <>
                                                    <YellowBadge>pending</YellowBadge>
                                                </>} */}
                                                </div>
                                            </div>
                                        </div>
                                    )
                                })}
                            </>
                        )
                    })}
                </div>
            </div>
        </div>
    )
}


export default StakeStakedSuiToPT