import { useState, useCallback, useEffect, useContext } from "react"
import { ArrowRightIcon } from "@heroicons/react/20/solid"
import Selector from "../Selector"
import { YellowBadge, Badge } from "../Badge"
import Vault from "../../data/vault.json"
import MessageModal from "@/modals/Message"
import { useWallet } from "@suiet/wallet-kit"
import { LegatoContext } from "@/hooks/useLegato"
import BigNumber from "bignumber.js"
import { parseAmount } from "@/helpers"
import StakeStakedSuiToPT from "@/panels/StakeStakedSuiToPT"
import PTValidatorList from "@/modals/PTValidatorList"
import useSuiStake from "@/hooks/useSuiStake"

const PANEL = {
    NONE: "NONE",
    EXPIRED: "EXPIRED",
    STAKE: "STAKE",
    VALIDATOR_LIST: "VALIDATOR_LIST"
}

const StakedSuiToPT = ({ isTestnet, suiPrice }) => {

    const { vaults, getTotalPT } = useContext(LegatoContext)

    const { connected, account } = useWallet()
    const { getTotalStaked } = useSuiStake()
    const [selected, setSelected] = useState()
    const [totalStaked, setTotalStaked] = useState(0)
    const [pt, setPT] = useState([])

    const [modal, setModal] = useState(PANEL.NONE)

    const [tick, setTick] = useState(0)

    useEffect(() => {
        setDefaultItem()
    }, [vaults, isTestnet])

    useEffect(() => {

        connected && getTotalStaked(account.address, isTestnet).then(
            ({ totalStaked, totalPending }) => {
                const stakedAmount = (BigNumber(totalStaked).plus(BigNumber(totalPending))).dividedBy(10 ** 9)
                setTotalStaked(Number(stakedAmount))
            }
        )

        connected && getTotalPT(account.address, isTestnet).then(setPT)
    }, [connected, account, isTestnet, tick])

    const setDefaultItem = useCallback(() => {
        setSelected(vaults[0])
    }, [vaults])

    const increaseTick = useCallback(() => {
        setTick(tick + 1)
    }, [tick])

    const onNext = useCallback(() => {

        if (!selected) {
            return
        }

        if (selected.disabled === true) {
            setModal(PANEL.EXPIRED)
            return
        }

        setModal(PANEL.STAKE)

    }, [selected])

    const onShowValidatorList = useCallback(() => {
        selected && !selected.disabled && setModal(PANEL.VALIDATOR_LIST)
    }, [selected])

    // const selectedPoolTotalStaked = selected && selected.principal_balance ? Number(`${(BigNumber(selected.principal_balance)).dividedBy(BigNumber(10 ** 9))}`) : 0
    // const selectedPoolTotalStakedUsd = selectedPoolTotalStaked * suiPrice
    // const totalStakingPool = selected && selected.pools ? selected.pools.length : 0

    const apy = selected && selected.vault_apy ? Number(`${(BigNumber(selected.vault_apy)).dividedBy(BigNumber(10 ** 7))}`) : 0

    const stakedAmount = selected ? pt.filter(item => item.vault === selected.name).reduce((output, item) => {
        return output + Number(`${(BigNumber(item.balance)).dividedBy(BigNumber(10 ** 9))}`)
    }, 0) : 0

    const stakedAmountInUs = stakedAmount * suiPrice

    return (
        <div>

            <MessageModal
                visible={modal === PANEL.EXPIRED}
                close={() => setModal(PANEL.NONE)}
                info="The selected vault has already expired."
            />

            {selected && (
                <>
                    <PTValidatorList
                        visible={modal === PANEL.VALIDATOR_LIST}
                        close={() => setModal(PANEL.NONE)}
                        vault={selected}
                    />
                    <StakeStakedSuiToPT
                        visible={modal === PANEL.STAKE}
                        close={() => {
                            setModal(PANEL.NONE)
                            increaseTick()
                        }}
                        isTestnet={isTestnet}
                        vault={selected}
                        tick={tick}
                    />
                </>
            )}

            <Selector
                name="Vault to stake into"
                selected={selected}
                setSelected={setSelected}
                options={vaults}
            />
            <div className="grid grid-cols-2">
                <div className="col-span-1">
                    {isTestnet && <YellowBadge>Testnet</YellowBadge>}
                </div>
                <div className="col-span-1">
                    {/* <div onClick={onShowValidatorList} className="ml-auto cursor-pointer">
                        <Badge>
                            {`Supported Pools`}
                        </Badge>
                    </div>  */}
                    <div class="text-xs flex font-medium text-gray-300 justify-end flex-row mt-2">
                        <a onClick={onShowValidatorList} className="flex flex-row hover:underline cursor-pointer">
                            Supported Pools
                            <ArrowRightIcon className="h-4 w-4 ml-[1px]" />
                        </a>
                    </div>
                </div>
            </div>
            <div class="grid grid-cols-2 gap-2  mb-6 mt-6">
                <div>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Available to stake
                    </div>
                    <div className='flex flex-row text-lg'>
                        <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                        {(totalStaked.toLocaleString())}{` SUI`}
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Total Staked
                    </div>
                    <div className="text-2xl">
                        ${stakedAmountInUs.toLocaleString()}
                    </div>
                </div>
            </div>

            <div class="grid grid-cols-2 gap-2  mb-6 mt-6">
                <div>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Staked amount
                    </div>
                    <div className='flex flex-row text-lg'>
                        <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mr-2  mt-auto mb-auto flex-shrink-0 rounded-full" />
                        {parseAmount(stakedAmount)}{` PT`}
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Floor APY
                    </div>
                    <div className="text-2xl">
                        {apy.toFixed(2)}%
                    </div>
                </div>
            </div>
            <button onClick={onNext} className=" py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                Next
                <ArrowRightIcon className="h-5 w-5 ml-2" />
            </button>
        </div>
    )
}

export default StakedSuiToPT