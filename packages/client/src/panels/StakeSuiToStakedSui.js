import { AmountInput } from "@/components/Input"
import BasePanel from "./Base"
import { OptionBadge } from "@/components/Badge"
import { useCallback, useState } from "react"
import { useWallet } from '@suiet/wallet-kit'
import { secondsToHHMMSS } from "@/helpers"
import { useInterval } from "@/hooks/useInterval"
import Spinner from "@/components/Spinner"
import useSuiStake from "@/hooks/useSuiStake"

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

const StakeSuiToStakedSuiPanel = ({
    visible,
    close,
    validator,
    balance,
    openValidator,
    summary
}) => {

    const { connected } = useWallet()
    const { stake } = useSuiStake()

    const [amount, setAmount] = useState(0)
    const [errorMessage, setErrorMessage] = useState()
    const [loading, setLoading] = useState(false)

    const [countdown, setCountdown] = useState(`0h 0m 0s`)
    const epoch = summary ? summary.epoch : 0

    const handleChange = (e) => {
        setAmount(Number(e.target.value))
    }

    const nextEpoch = new Date((new Date(Number(summary.epochStartTimestampMs))).valueOf() + Number(summary.epochDurationMs))
    const nextTwoEpoch = new Date((new Date(Number(summary.epochStartTimestampMs))).valueOf() + (Number(summary.epochDurationMs) * 2))

    const onStake = useCallback(async () => {

        if (!(Number(amount) > 0)) {
            return
        }

        setLoading(true)
        setErrorMessage()

        try {

            if (1 > amount) {
                throw new Error("Min. requirement to stake is 1 SUI")
            }

            await stake(validator.suiAddress, amount)

            close()

        } catch (e) {
            console.log(e)
            setErrorMessage(e.message)
        }

        setLoading(false)

    }, [validator, amount])

    useInterval(
        () => {

            const current = new Date()

            const diffTime = Math.abs(nextEpoch - current);
            const totals = Math.floor(diffTime / 1000)

            const { hours, minutes, seconds } = secondsToHHMMSS(totals)

            setCountdown(`${hours}h ${minutes}m ${seconds}s`)
        },
        1000,
    )

    const disabled = !connected || loading

    if (!validator) {
        return
    }

    const profit = amount > 0 ? amount * (validator.apy / 100) : 0

    return (
        <BasePanel
            visible={visible}
            close={close}
        >
            <h2 class="text-2xl mb-2 mt-2 font-bold">
                Stake SUI Tokens
            </h2>
            <hr class="my-12 h-0.5 border-t-0 bg-neutral-100 mt-2 mb-2 opacity-50" />
            <p class="  text-sm text-gray-300  mt-2">
            Legato provides an interface to stake on validators on the network to receive Stake SUI objects. We don't have any relationship with any validators and don't receive commissions from them.
            </p>
            <div className="border rounded-lg mt-4   p-4 border-gray-400">
                <div className="flex items-center">
                    <img src={validator.imageUrl} alt="" className="h-6 w-6  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                    <span onClick={openValidator} className="ml-1 block text-white font-medium text-right hover:underline cursor-pointer">
                        {validator.name}
                    </span>
                    <div class="ml-auto text-gray-300 text-sm font-medium">
                        <a className="hover:underline" href={validator.projectUrl} target="_blank">
                            {validator.projectUrl}
                        </a>

                    </div>
                </div>
            </div>
            <div className="border rounded-lg mt-4 p-4 border-gray-400">
                <div className="block leading-6 mb-2 text-gray-300 ">Amount to stake</div>
                <AmountInput
                    icon="./sui-sui-logo.svg"
                    tokenName="SUI"
                    value={amount}
                    onChange={handleChange}
                />
                <div className="text-xs flex flex-row text-gray-300 border-gray-400  ">
                    <div className="font-medium ">
                        Available: {Number(balance).toFixed(3)} SUI
                    </div>
                    <div className="ml-auto  flex flex-row ">
                        <OptionBadge onClick={() => balance && Number(balance) > 1 ? setAmount(1) : 0} className="cursor-pointer hover:underline">
                            1 SUI
                        </OptionBadge>
                        <OptionBadge onClick={() => setAmount((Math.floor(Number(balance) * 500) / 1000))} className="cursor-pointer hover:underline">
                            50%
                        </OptionBadge>
                        <OptionBadge onClick={() => setAmount((Math.floor(Number(balance) * 1000) / 1000))} className="cursor-pointer hover:underline">
                            Max
                        </OptionBadge>
                    </div>
                </div>
            </div>

            <div className="border rounded-lg mt-4 p-4 border-gray-400">
                <div class="mt-2 flex flex-row">
                    <div class="text-gray-300 text-sm font-medium">You will receive</div>
                    {/* <span class="ml-auto bg-blue-100 text-blue-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-blue-900 dark:text-blue-300">
                        1 Staked SUI = {(1).toLocaleString()} PT
                    </span> */}
                    <span class="ml-auto bg-blue-100 text-blue-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-blue-900 dark:text-blue-300">
                        Next epoch in {countdown}
                    </span>
                </div>
                <hr class="h-px my-4 border-0  bg-gray-600" />
                <div class="grid grid-cols-2 gap-2 mt-2 mb-2">
                    <div>
                        <h2 className="text-3xl font-medium">
                            Staked SUI
                        </h2>
                        <div class="text-gray-300 text-sm font-medium">
                            Non-Fungible
                        </div>
                    </div>
                    <div className="flex">
                        <div className="text-3xl font-medium mx-auto mt-3 mb-auto mr-2">
                            {(amount).toLocaleString()}
                        </div>
                    </div>
                </div>
                <InfoRow
                    name={"Epoch at the moment"}
                    value={`${epoch}`}
                />
                <InfoRow
                    name={"Easiest date to unstake"}
                    value={`${nextTwoEpoch.toLocaleString()}`}
                />
                <InfoRow
                    name={"Current APY"}
                    value={`${validator.apy ? validator.apy.toFixed(2) : 0}%`}
                />

                {/* <InfoRow
                    name={"Est. Profit after 1 year"}
                    value={`${profit < 1 ? profit.toFixed(6) : profit.toFixed(2)} SUI`}
                /> */}

                <hr class="h-px my-4 border-0 bg-gray-600" />
                <button disabled={disabled} onClick={onStake} className={`py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700 ${disabled && "opacity-60"}`}>
                    {loading && <Spinner />}
                    Stake
                </button>
                {errorMessage && (
                    <div className="text-xs font-medium p-2 text-center text-yellow-300">
                        {errorMessage}
                    </div>
                )}
            </div>

        </BasePanel>
    )
}

export default StakeSuiToStakedSuiPanel