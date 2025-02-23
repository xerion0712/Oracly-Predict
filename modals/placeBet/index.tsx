import { useContext, useReducer, useEffect, useState, useCallback } from "react"
import BaseModal from "../base"
import { Puff } from 'react-loading-icons'
import { LegatoContext } from "@/hooks/useLegato";
import { Authenticator, useTheme, View, Heading, Image, Text, Button, ThemeProvider, Theme } from '@aws-amplify/ui-react'
import Link from "next/link";
import useDatabase from "@/hooks/useDatabase";
import { OptionBadge } from "../../components/Badge"
import ListGroup from '@/components/ListGroup';
import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { SpinningCircles } from 'react-loading-icons'
import useAptos from "@/hooks/useAptos";


const PlaceBetModal = ({ visible, close, bet }: any) => {

    const { placeBet } = useAptos()
    const { addPosition, increaseOutcomeBetAmount } = useDatabase()

    const { balance, loadBalance } = useContext(LegatoContext)

    const { getOutcomes } = useDatabase()
    const { account, network } = useWallet()
    const address = account && account.address

    const { currentProfile }: any = useContext(LegatoContext)
    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            amount: 0,
            errorMessage: undefined,
            loading: false,
            outcome: undefined,
            outcomes: []
        }
    )

    const { outcome, amount, loading, errorMessage, outcomes } = values

    useEffect(() => {
        dispatch({ outcome: undefined, outcomes: [] })
        bet && getOutcomes(bet.marketId, bet.roundId).then(
            (outcomes) => {
                const entry = outcomes.find((item: any) => item.onchainId === bet.outcomeId)
                dispatch({
                    outcome: entry,
                    outcomes
                })
            }
        )
    }, [bet])

    const onAmountChange = (amount: number) => {
        dispatch({
            amount
        })
    }

    const onBet = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!bet) {
            return
        }

        if (!amount || amount < 0.1) {
            dispatch({ errorMessage: "Invalid amount" })
            return
        }

        dispatch({ loading: true })

        try {

            const onchainMarketId = 1
            const roundId = bet.roundId
            const outcomeId = bet.outcomeId

            await placeBet(onchainMarketId, roundId, outcomeId, amount)

            const userId = currentProfile.id
            const marketId = bet.marketId
            const walletAddress = address

            await addPosition({ marketId, userId, roundId, outcomeId, amount, walletAddress })
            await increaseOutcomeBetAmount({ marketId, roundId, outcomeId, amount })

            dispatch({ amount: 0 })
            close()

            setTimeout(() => {
                address && loadBalance(address)
            }, 2000)

        } catch (e: any) {
            console.log(e)
            dispatch({ errorMessage: `${e.message}`, loading: false })
        }

        dispatch({ loading: false })

    }, [amount, bet, address, currentProfile])

    const totalPool = outcomes.reduce((output: number, item: any) => {
        if (item && item.totalBetAmount) {
            output = output + item.totalBetAmount
        }
        return output
    }, 0)

    let minPayout = 0
    let maxPayout = 0
    let minOdds = 0
    let maxOdds = 0

    if (amount > 0 && outcome && outcomes) {
        const totalPoolAfter = totalPool + amount

        // Assumes all outcomes won
        const totalShares = outcomes.reduce((output: number, item: any) => {
            if (item && item.totalBetAmount) {
                output = output + (item.totalBetAmount * (item.weight))
            }
            if (item.onchainId === outcome.onchainId) {
                output = output + (amount * (item.weight))
            }
            return output
        }, 0)
        const outcomeShares = (outcome.totalBetAmount + amount) * (outcome.weight)
        const ratio = outcomeShares / totalShares
        
        minPayout = ((ratio) * totalPoolAfter) * (amount / (outcome.totalBetAmount + amount))

        // when only selected outcome won
        maxPayout = totalPoolAfter * (amount / (outcome.totalBetAmount + amount))
    }

    if (outcome && outcomes) {
        const totalPoolAfter = totalPool + 1

        // Assumes all outcomes won
        const totalShares = outcomes.reduce((output: number, item: any) => {
            if (item && item.totalBetAmount) {
                output = output + (item.totalBetAmount * (item.weight))
            }
            if (item.onchainId === outcome.onchainId) {
                output = output + (1 * (item.weight))
            }
            return output
        }, 0)
        const outcomeShares = (outcome.totalBetAmount + 1) * (outcome.weight)
        const ratio = outcomeShares / totalShares

        minOdds = ((ratio) * totalPoolAfter) * (1 / (outcome.totalBetAmount + 1))
        maxOdds = (totalPoolAfter) * (1 / (outcome.totalBetAmount + 1))
    }

    return (
        <BaseModal visible={visible} close={close} title={"Place Your Bet"} maxWidth="max-w-xl">

            {currentProfile && (
                <View>
                    <Authenticator>

                        {!outcome && (
                            <div className="flex flex-col h-[100px] justify-center items-center">
                                <SpinningCircles className="h-7 w-7" />
                            </div>
                        )}

                        {outcome && (
                            <>
                                <div className='p-2 border-gray/20   mt-[15px] border-[1px] rounded-md bg-[url(/assets/images/consulting/business-img.png)] bg-cover bg-center bg-no-repeat '>
                                    <div className="grid grid-cols-2 p-2 text-gray">
                                        <div className=" py-0.5  col-span-2 text-lg font-semibold  text-white flex flex-row">
                                            {outcome.title}
                                        </div>
                                        <div className=" py-0.5 col-span-2  text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Resolution Date:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {` ${(new Date(Number(outcome.resolutionDate) * 1000)).toUTCString()}`}
                                            </div>
                                        </div>

                                        <div className=" py-0.5 text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Current Odds:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {`${outcome.weight ? `${minOdds.toLocaleString()}/${maxOdds.toLocaleString()}` : "N/A"}`}
                                            </div>
                                        </div>
                                        <div className=" py-0.5 text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Round Pool:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {`${totalPool} USDC`}
                                            </div>
                                        </div>
                                        {/* <div className=" py-0.5 text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Deadline:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                 
                                            </div>
                                        </div> */}
                                    </div>
                                </div>
                                <div className='p-2 px-0   rounded-md '>
                                    <div className='py-3'>
                                        <div className="block leading-6 mb-2">Enter bet amount</div>
                                        <div className="grid grid-cols-7">
                                            <div className="col-span-5">
                                                <input value={amount} onChange={(e) => {
                                                    onAmountChange(Number(e.target.value))
                                                }} type="number" id="input-asset" className={`block w-full p-4 py-3  rounded-l-lg text-lg bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none`} />
                                            </div>

                                            <div className="col-span-2">
                                                <div className="cursor-default flex border border-l-0 border-gray/30 bg-gray/30  rounded-r-lg h-full">
                                                    <div className="m-auto flex flex-row text-white font-normal">
                                                        <img className="h-5 w-5 mt-0.5 rounded-full" src={"https://s2.coinmarketcap.com/static/img/coins/64x64/3408.png"} alt="" />
                                                        <div className="mt-auto mb-auto ml-1.5">
                                                            USDC
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                        <div className="text-xs flex flex-row my-2">
                                            <div className="font-medium ">
                                                Available: {Number(balance).toFixed(3)}{` USDC`}
                                            </div>
                                            <div className="ml-auto flex flex-row ">
                                                <OptionBadge onClick={() => onAmountChange(1)} className="cursor-pointer hover:bg-gray hover:text-black">
                                                    1{` USDC`}
                                                </OptionBadge>
                                                <OptionBadge onClick={() => onAmountChange((Math.floor(Number(balance) * 500) / 1000))} className="cursor-pointer hover:bg-gray hover:text-black">
                                                    50%
                                                </OptionBadge>
                                                <OptionBadge onClick={() => onAmountChange((balance > 100 ? 100 : Math.floor(Number(balance) * 1000) / 1000))} className="cursor-pointer hover:bg-gray hover:text-black">
                                                    Max
                                                </OptionBadge>
                                            </div>
                                        </div>
                                        <div className="px-1 mt-4">
                                            <ListGroup
                                                items={[
                                                    ["Potential payout", `${(minPayout).toLocaleString()}-${(maxPayout.toLocaleString())} USDC`],
                                                    // ["Estimate payout date", `N/A`],
                                                    ["Winning fee", "10%"],
                                                ]}
                                            />
                                        </div>
                                        <div className="flex mt-4">
                                            {address && (
                                                <button onClick={onBet} disabled={loading} type="button" className="btn mx-auto w-full bg-white hover:bg-white hover:text-black rounded-md">
                                                    {loading
                                                        ?
                                                        <Puff
                                                            stroke="#000"
                                                            className="w-5 h-5 mx-auto"
                                                        />
                                                        :
                                                        <>
                                                            Place Bet
                                                        </>}
                                                </button>
                                            )}

                                            {!address && (
                                                <WalletSelector />
                                            )}

                                        </div>

                                        {errorMessage && (
                                            <div className='text-gray-400 mt-2 text-sm font-medium  text-center w-full '>
                                                <div className='p-2 pb-0 text-secondary'>
                                                    {errorMessage}
                                                </div>
                                            </div>
                                        )}
                                        <style>
                                            {

                                                `
                                        .wallet-button {
                                            width: 100%;
                                            z-index: 1;
                                            border-width: 0px;
                                        } 
                                        `
                                            }
                                        </style>

                                    </div>
                                </div>
                            </>
                        )}

                    </Authenticator>
                </View>
            )}
            {!currentProfile && (
                <div className="h-[150px] flex flex-col">
                    <Link href="/auth/profile" className="m-auto">
                        <button type="button" className="btn m-auto mb-0 bg-white text-sm flex rounded-lg px-8 py-3 hover:scale-100  flex-row hover:text-black hover:bg-white ">
                            Sign In
                        </button>
                        <p className="text-center m-auto mt-2 text-gray">You need to sign in to continue</p>
                    </Link>
                </div>
            )}

        </BaseModal>
    )
}

export default PlaceBetModal