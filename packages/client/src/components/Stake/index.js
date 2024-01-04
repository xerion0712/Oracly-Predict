

import { LegatoContext } from "@/hooks/useLegato"
import { ModalContext } from "@/hooks/useModal"
import { useWallet } from '@suiet/wallet-kit'
import Link from 'next/link'
import { CheckIcon, ChevronUpDownIcon, ChevronDownIcon, ArrowRightIcon } from "@heroicons/react/20/solid"
import { useCallback, useContext, useEffect, useState } from "react"
import { MODAL } from "@/hooks/useModal"
import useSui from "@/hooks/useSui"
import BigNumber from "bignumber.js"

import SuiToStakedSui from "./SuiToStakedSui"
import StakedSuiToPT from "./StakedSuiToPT"

import MARKET from "../../data/market.json"

const Stake = (props) => {

    const { suiPrice, summary } = props

    const { account, connected } = useWallet()
    const { fetchSuiSystem, fetchAllVault } = useSui()
    const { openModal } = useContext(ModalContext)
    const {
        updateValues,
        currentMarket,
        market,
        validators,
        avgApy,
        isTestnet,
        vaults,
        updateMarket
    } = useContext(LegatoContext)

    const onMarketSelect = useCallback(() => {

        const floorApy = vaults.filter(item => item.disabled === false).reduce((output, item) => {
            return item.vault_apy
        }, 0)

        openModal(MODAL.MARKET, {
            suiSystemApy: avgApy,
            floorApy: Number(`${(BigNumber(floorApy).dividedBy(BigNumber(10000000)))}`).toFixed(2)
        })
    }, [avgApy, vaults])

    useEffect(() => {

        if (connected && account && account.chains && account.chains[0] === "sui:testnet") {
            fetchSuiSystem("testnet").then(({ summary, validators, avgApy }) => {
                updateValues({ validators, avgApy, isTestnet: true, vaults: [] })
                fetchAllVault("testnet", summary).then((vaults) => updateValues({ vaults }))
            })
        } else {
            updateValues({ validators: props.validators, avgApy: props.avgApy, isTestnet: false, vaults: props.vaults })
        }

    }, [connected, account])

    useEffect(() => {

        if (localStorage.getItem("legatoDefaultMarket")) {
            const defaultMarket = localStorage.getItem("legatoDefaultMarket")
            MARKET[defaultMarket] ? updateMarket(defaultMarket) : localStorage.removeItem("legatoDefaultMarket")
        }

    },[])

    return (
        <div>

            <div className="max-w-xl ml-auto mr-auto">
                <div class="wrapper pt-10">
                    <div class="rounded-3xl p-px bg-gradient-to-b  from-blue-800 to-purple-800 ">
                        <div class="rounded-[calc(1.5rem-1px)] p-10 bg-gray-900">

                            {/* SELECT MARKET */}

                            <div class="flex gap-10 items-center ">
                                <p class="text-gray-300">
                                    Select Market
                                </p>
                                <div onClick={onMarketSelect} class="flex gap-4 items-center flex-1 p-2 hover:cursor-pointer rounded-md">
                                    <div class="relative">
                                        <img class="h-12 w-12 rounded-full" src={market.img} alt="" />
                                        {market.isPT && <img src="/pt-badge.png" class="bottom-0 right-7 absolute  w-7 h-4  " />}
                                    </div>
                                    <div>
                                        <h3 class="text-2xl font-medium text-white">{market.from}</h3>
                                        <span class="text-sm tracking-wide text-gray-400">{market.to}</span>
                                    </div>
                                    <div class="ml-auto ">
                                        <ChevronUpDownIcon className="h-6 w-6 text-gray-300" />
                                    </div>
                                </div>
                            </div>

                            {/* ACTION PANEL */}

                            <div className="mt-6">
                                {currentMarket === "SUI_TO_STAKED_SUI" && (
                                    <SuiToStakedSui
                                        validators={validators}
                                        avgApy={avgApy}
                                        suiPrice={suiPrice}
                                        isTestnet={isTestnet}
                                        summary={summary}
                                    />
                                )}

                                {currentMarket === "STAKED_SUI_TO_PT" && (
                                    <StakedSuiToPT
                                        isTestnet={isTestnet}
                                        suiPrice={suiPrice}
                                    />
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* DISCLAIMER */}
            <div className="max-w-lg ml-auto mr-auto">
                <p class="text-neutral-400 text-sm p-5 text-center">
                    {`The Legato version you're using is in its early stage. It's still in development and may have undiscovered issues.`}
                </p>
            </div>
        </div>
    )
}

export default Stake