import { useCallback, useEffect, useState, useReducer } from "react"
import { ArrowRightIcon } from "@heroicons/react/20/solid"
import Selector, { FixedSelector } from "../Selector"
import Vault from "../../data/vault.json"
import ValidatorDetails from "@/panels/ValidatorDetails"
import BigNumber from "bignumber.js"
import { Badge, YellowBadge } from "../Badge"
import { useAccountBalance } from '@suiet/wallet-kit'
import StakeSuiToStakedSuiPanel from "@/panels/StakeSuiToStakedSui"
import useSuiStake from "@/hooks/useSuiStake"
import { useWallet } from '@suiet/wallet-kit'
import { parseAmount } from "@/helpers"
import { useInterval } from "@/hooks/useInterval"
import ValidatorList from "@/modals/ValidatorList"

const PANEL = {
    NONE: "NONE",
    VALIDATOR_LIST: "VALIDATOR_LIST",
    STAKE: "STAKE",
    VALIDATOR_DETAILS: "VALIDATOR_DETAILS"
}

const SuiToStakedSui = ({
    summary,
    avgApy,
    validators,
    suiPrice,
    isTestnet
}) => {

    const parsedValidator = validators.map((item, index) => ({
        index,
        ...item,
        name: item.name,
        image: item.imageUrl,
        value: !isTestnet ? `$${(Number(`${(BigNumber(item.stakingPoolSuiBalance).dividedBy(BigNumber(1000000000)).toFixed(2))}`) * suiPrice / 1000000).toFixed(0)}M` : `${(Number(`${(BigNumber(item.stakingPoolSuiBalance).dividedBy(BigNumber(1000000000)).toFixed(2))}`) / 1000000).toFixed(1)}M`,
        suiPrice
    }));

    const { connected, account } = useWallet()
    const { getTotalStaked } = useSuiStake()
    const { balance } = useAccountBalance()

    const balanceStr = balance ? `${BigNumber(balance).div(10 ** 9)}` : 0

    const [values, dispatch] = useReducer(
        (curVal, newVal) => ({ ...curVal, ...newVal }),
        {
            tick: 0,
            stakedAmount: 0,
            totalStaked: 0,
            selected: undefined,
            panel: PANEL.NONE
        }
    )

    const { tick, stakedAmount, totalStaked, selected, panel } = values

    const onSelectIndex = useCallback((index) => {
        if (index >= 0 && validators.length > index) setSelected(parsedValidator[index])
    }, [validators, parsedValidator])

    useEffect(() => {
        connected && getTotalStaked(account.address, isTestnet).then(
            ({ suiPrice, totalStaked, totalPending }) => {

                const stakedAmount = (BigNumber(totalStaked).plus(BigNumber(totalPending))).dividedBy(10 ** 9)
                const stakedAmountInUS = stakedAmount.multipliedBy(suiPrice)

                dispatch({
                    stakedAmount: Number(`${stakedAmount}`),
                    totalStaked: Number(`${stakedAmountInUS}`)
                })
            }
        )
    }, [connected, account, isTestnet, tick])

    const increaseTick = useCallback(() => {
        dispatch({ tick: tick + 1 })
    }, [tick])

    const setDefaultItem = useCallback(() => {
        dispatch({ selected: parsedValidator[0] })
    }, [parsedValidator])

    useEffect(() => {
        setDefaultItem()
    }, [isTestnet])

    useInterval(
        () => {
            if (!selected) {
                setDefaultItem()
            }
            // TODO: maybe check status
        },
        1000,
    )

    const setSelected = (item) => {
        dispatch({ selected: item })
    }

    const setPanel = (panel) => {
        dispatch({ panel })
    }

    const onShowValidator = useCallback(() => {
        selected && dispatch({ panel: PANEL.VALIDATOR_LIST })
    }, [selected])

    return (
        <div>
            <ValidatorDetails
                visible={panel === PANEL.VALIDATOR_DETAILS}
                close={() => dispatch({panel : PANEL.NONE})}
                data={selected}
                select={onSelectIndex}
                avgApy={avgApy}
                isTestnet={isTestnet}
            />
            {selected && (
                <>
                    <ValidatorList
                        visible={panel === PANEL.VALIDATOR_LIST}
                        close={() => dispatch({ panel: PANEL.NONE })}
                        selected={selected}
                        select={onSelectIndex}
                        isTestnet={isTestnet}
                        validators={parsedValidator}
                    />
                    <StakeSuiToStakedSuiPanel
                        visible={panel === PANEL.STAKE}
                        close={() => dispatch({ panel: PANEL.NONE })}
                        validator={selected}
                        balance={balanceStr}
                        openValidator={() => dispatch({ panel: PANEL.VALIDATOR_DETAILS })}
                        summary={summary}
                        increaseTick={increaseTick}
                    />
                </>
            )}
            <FixedSelector
                name="Validator to stake into"
                selected={selected}
                select={onShowValidator}
            />
            <div className="grid grid-cols-2">
                <div className="col-span-1">
                    {isTestnet && <YellowBadge>Testnet</YellowBadge>}
                </div> 
                <div className="col-span-1">
                    <div class="text-xs flex font-medium text-gray-300 justify-end flex-row mt-2">
                        <a onClick={() => setPanel(PANEL.VALIDATOR_DETAILS)} className="flex flex-row hover:underline cursor-pointer">
                            Details
                            <ArrowRightIcon className="h-4 w-4 ml-[1px]" />
                        </a>
                    </div>
                </div>
            </div>

            <div class="grid grid-cols-2 gap-2  mb-6 mt-4">
                <div>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Available to stake
                    </div>
                    <div className='flex flex-row text-lg'>
                        <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                        {balanceStr ? Number(balanceStr).toFixed(3) : 0} SUI
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Total Staked
                    </div>
                    <div className="text-2xl">
                        ${(totalStaked.toLocaleString())}
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
                        {parseAmount(stakedAmount)}{` SUI`}
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Current APY
                    </div>
                    <div className="text-2xl">
                        {selected && selected.apy.toFixed(2)}%
                    </div>
                </div>
            </div>
            <button onClick={() => setPanel(PANEL.STAKE)} className=" py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                Next
                <ArrowRightIcon className="h-5 w-5 ml-2" />
            </button>
        </div>
    )
}

export default SuiToStakedSui