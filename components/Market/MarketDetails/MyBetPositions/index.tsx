import { useContext, useReducer, useEffect, useState, useCallback } from "react"
import { Puff } from 'react-loading-icons'
import { LegatoContext } from "@/hooks/useLegato";
import Link from "next/link";
import useDatabase from "@/hooks/useDatabase";
import { BadgePurple } from "@/components/Badge";
import { shortAddress } from "@/helpers";
import BaseModal from "@/modals/base";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";
import useAptos from "@/hooks/useAptos";

enum SortBy {
    All = "All",
    Active = "Active",
    Resolved = "Resolved"
}

const MyBetPositions = ({ marketData, onchainMarket, currentRound }: any) => {

    const { account, network } = useWallet()
    const address = account && account.address

    const { currentProfile }: any = useContext(LegatoContext)

    const { getMyPositions, updatePosition } = useDatabase()
    const { claim, refund } = useAptos()
    const [positions, setPositions] = useState<any>([])

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            sorted: SortBy.All,
            rounds: [],
            modal: undefined,
            loading: false,
            errorMessage: undefined,
            tick: 1
        })

    const { sorted, rounds, modal, loading, errorMessage, tick } = values

    useEffect(() => {
        currentProfile && marketData && getMyPositions(currentProfile.id, marketData.id).then(setPositions)
    }, [currentProfile, marketData, tick])

    useEffect(() => {
        positions && fetchRounds(positions)
    }, [positions])

    const fetchRounds = useCallback(async (positions: any) => {
        const roundIds = positions.reduce((output: any, item: any) => {
            if (output.indexOf(item.roundId) === -1) {
                output.push(item.roundId)
            }
            return output
        }, [])
        const rounds = await marketData.rounds()
        const thisRounds: any = rounds.data.filter((item: any) => roundIds.includes(item.onchainId))
        dispatch({
            rounds: thisRounds
        })
    }, [marketData])

    const totalAmount = positions.reduce((output: number, item: any) => {
        return output + item.betAmount
    }, 0)

    let filter = []

    if (sorted === SortBy.Active) {
        filter = positions.filter((item: any) => item.roundId === currentRound)
    } else if (sorted === SortBy.Resolved) {
        filter = positions.filter((item: any) => (currentRound - 1) > item.roundId)
    } else {
        filter = positions
    }

    const onClaim = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!modal) {
            return
        }

        dispatch({ loading: true })

        try {

            const positionId = modal.position.id
            const onchainId = modal.position.onchainId

            if (!modal.outcome.isDisputed) {
                await claim(onchainId)
            } else {
                await refund(onchainId)
            }

            await updatePosition(positionId)

            dispatch({ modal: undefined, tick: tick + 1 })

        } catch (e: any) {
            console.log(e)
            dispatch({ errorMessage: `${e}`, loading: false })
        }

        dispatch({ loading: false })

    }, [modal, tick])

    return (
        <div>
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
            {currentProfile && (
                <>

                    <BaseModal
                        visible={modal}
                        close={() => dispatch({ modal: undefined })}
                        title={"Position Details"}
                        maxWidth="max-w-xl"
                    >
                        {modal && (
                            <>
                                <div className="grid grid-cols-2 py-2 text-gray">
                                    <div className=" py-0.5  col-span-2 text-lg font-semibold  text-white flex flex-row">
                                        {modal?.outcome?.title}
                                    </div>

                                    {!modal?.outcome?.revealedTimestamp && (
                                        <>
                                            <div className=" py-0.5 col-span-2  text-sm  flex flex-row">
                                                <span className="font-bold mr-2">At:</span>
                                                <div className={`   flex flex-row  text-white text-sm `}>
                                                    {` ${(new Date(Number(modal?.outcome?.resolutionDate) * 1000)).toUTCString()}`}
                                                </div>
                                            </div>
                                            <div className="col-span-2 rounded-lg   h-[100px] mt-[10px] flex border border-gray/30">
                                                <div className="m-auto text-white font-semibold">
                                                    The result is not yet revealed
                                                </div>
                                            </div>
                                        </>
                                    )}

                                    {modal?.outcome?.revealedTimestamp && (
                                        <>
                                            <div className=" py-0.5 col-span-2  text-sm  flex flex-row">
                                                <span className="font-bold mr-2">Checked At:</span>
                                                <div className={`   flex flex-row  text-white text-sm `}>
                                                    {` ${(new Date(Number(modal?.outcome?.revealedTimestamp) * 1000)).toUTCString()}`}
                                                </div>
                                            </div>
                                            <div className="col-span-2 rounded-lg grid grid-cols-2 mt-[10px] p-4 py-2 border border-gray/30">
                                                <div className=" py-0.5 col-span-1  text-sm  flex flex-row">
                                                    <span className="font-bold mr-2">Result:</span>
                                                    <div className={`   flex flex-row  text-white text-sm `}>
                                                        {modal?.outcome?.isWon ? "✅" : "❌"}
                                                    </div>
                                                </div>
                                                <div className=" py-0.5 col-span-1  text-sm  flex flex-row">
                                                    <span className="font-bold mr-2">Disputed:</span>
                                                    <div className={`   flex flex-row  text-white text-sm `}>
                                                        {modal?.outcome?.isDisputed ? "✅" : "❌"}
                                                    </div>
                                                </div>
                                                <div className=" py-0.5 col-span-2  text-sm  flex flex-row">
                                                    <div className="text-white my-1">
                                                        {modal?.outcome?.result}
                                                    </div>
                                                </div>
                                            </div>

                                            <div className="flex mt-4 flex-col col-span-2">
                                                {address && (
                                                    <button onClick={onClaim} disabled={loading || (!modal?.outcome?.isWon && !modal?.outcome?.isDisputed)} type="button" className={`btn mx-auto w-full bg-white hover:bg-white hover:text-black rounded-md ${(!modal?.outcome?.isWon && !modal?.outcome?.isDisputed) && " hover:scale-100 opacity-60 "}`}>
                                                        {loading
                                                            ?
                                                            <Puff
                                                                stroke="#000"
                                                                className="w-5 h-5 mx-auto"
                                                            />
                                                            :
                                                            <>
                                                                {modal?.outcome?.isDisputed ? "Refund" : "Claim"}
                                                            </>}
                                                    </button>
                                                )}

                                                {!address && (
                                                    <WalletSelector />
                                                )}



                                            </div>

                                            {errorMessage && (
                                                <div className='text-gray-400 col-span-2 mt-2 text-sm font-medium  text-center w-full '>
                                                    <div className='p-2 pb-0 text-secondary'>
                                                        {errorMessage}
                                                    </div>
                                                </div>
                                            )}
                                            {!errorMessage && (
                                                <div className='text-gray-400 col-span-2 mt-2 text-sm font-medium  text-center w-full '>
                                                    <div className='p-2 pb-0 text-secondary'>
                                                        Ensure your wallet is {shortAddress(modal?.position?.walletAddress)}
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

                                        </>
                                    )}



                                    {/* <div className=" py-0.5 text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Current Odds:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {`${outcome.weight ? `${minOdds.toLocaleString()}-${`${maxOdds !== -1 ? maxOdds.toLocaleString() :"10"}`}` : "N/A"}`}
                                            </div>
                                        </div>
                                        <div className=" py-0.5 text-sm  flex flex-row">
                                            <span className="font-bold mr-2">Round Pool:</span>
                                            <div className={`   flex flex-row  text-white text-sm `}>
                                                {`${totalPool} USDC`}
                                            </div>
                                        </div>  */}
                                </div>
                            </>
                        )}
                    </BaseModal>

                    {/* <div className='flex-grow flex flex-col'>
                        <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                            <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                                ⚡ My Positions
                            </h2>
                            <div className='px-2 pb-4'>
                                <table className="w-full">
                                    <tbody>
                                        {positions.map((item: any, index: number) => {
                                            return (
                                                <tr key={index} className="border-b">
                                                    <PositionRow
                                                        item={item}
                                                    />
                                                </tr>
                                            )
                                        }) }
                                    </tbody>
                                </table>
                            </div>
                        </div> 
                    </div>  */}

                    <div className="flex flex-col my-2">

                        <div
                            className="flex flex-row justify-between my-2 text-white ml-4 mx-4"
                        >
                            <div className="mx-auto uppercase text-2xl font-bold text-white  text-center px-4">
                                ⚡ All Positions
                            </div>
                        </div>

                        <div className="grid grid-cols-3 my-1 mb-0">
                            <div className="flex flex-row">
                                <div className="text-white my-auto text-sm mr-2 font-semibold">
                                    Filters
                                </div>
                                <select value={sorted} onChange={(e: any) => {
                                    dispatch({ sorted: e.target.value })
                                }} className="  p-2 px-3 py-1 cursor-pointer my-auto rounded-lg text-sm bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none">
                                    <option value={SortBy.All}>All</option>
                                    <option value={SortBy.Active}>Active</option>
                                    <option value={SortBy.Resolved}>Resolved</option>
                                    {/* <option value={SortBy.Won}>Won</option> */}
                                </select>
                            </div>
                            <div className="text-center flex">
                                {/* {currentRound === current && (
                                    <div className="text-white text-sm my-auto mx-auto font-semibold">
                                        🟢 Accepting bets for the next {endIn}
                                    </div>
                                )}
                                {currentRound > current && (
                                    <>
                                        {(currentRound - current === 1) ? (
                                            <div className="text-white text-sm my-auto mx-auto font-semibold">
                                                🟡 Determining winning outcomes
                                            </div>
                                        ) : (
                                            <div className="text-white text-sm my-auto mx-auto font-semibold">
                                                🔵 All outcomes have been revealed and verified
                                            </div>
                                        )}
                                    </>
                                )} */}

                            </div>
                            <div className="text-white my-auto text-sm ml-auto font-semibold">
                                💰 Total Bet Size: {totalAmount.toLocaleString()} USDC
                            </div>
                        </div>

                    </div>

                    <div className="my-4 grid grid-cols-3 gap-3">
                        {filter.sort((a: any, b: any) => {
                            return (a.roundId) - (b.roundId)
                        }).map((position: any, index: number) => {

                            return (
                                <div key={index}>
                                    <PositionCard
                                        position={position}
                                        rounds={rounds}
                                        market={onchainMarket}
                                        openModal={(modal: any) => dispatch({ modal })}
                                    />
                                </div>
                            )
                        })}
                    </div>

                </>
            )}

        </div>
    )
}

const PositionCard = ({ position, rounds, market, openModal }: any) => {

    const [data, setData] = useState<any>(undefined)
    const { getOutcomeById } = useDatabase()
    const { checkPayoutAmount } = useAptos()

    useEffect(() => {
        position && getOutcomeById(position.predictedOutcome).then(setData)
    }, [position])

    const currentRound = rounds.find((item: any) => item.onchainId === position.roundId)

    const startPeriod = (Number(market.createdTime) * 1000) + (position.roundId * (Number(market.interval) * 1000))
    const endPeriod = startPeriod + (Number(market.interval) * 1000)

    const isEnded = (new Date()).valueOf() > endPeriod
    const isActive = startPeriod > (new Date()).valueOf()

    useEffect(() => {
        currentRound && currentRound.resolvedTimestamp && checkPayoutAmount(position.onchainId)
    }, [currentRound, position])


    return (
        <div
            onClick={() => {
                data && openModal({
                    round: currentRound,
                    position: position,
                    outcome: data
                })
            }}
            className=" h-[150px] p-4 px-2 border-2 flex flex-col cursor-pointer border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg" >
            <div className="flex flex-row">
                <div className="px-2">
                    <p className="text-white font-semibold line-clamp-2">
                        {data?.title}
                    </p>
                </div>
            </div>
            <div className="px-2 text-sm flex font-semibold my-1">
                Round {position.roundId}: {(new Date(startPeriod)).toLocaleDateString()}-{(new Date(endPeriod)).toLocaleDateString()}{isEnded && " "}
                <span className=" ml-auto  ">{`Bet: ${position.betAmount.toLocaleString()} USDC`}</span>
            </div>
            <div className="flex px-2 flex-row my-1 mt-auto  justify-between">
                <div className="text-white   ">
                    {isActive && "🟢 Active"}
                    {(!isActive && !isEnded) && "🔵 Outcome Pending"}
                    {(data && isEnded) && <>
                        {(data.isWon || data.isDisputed) ? "🟡 Resolved – Claimable" : "🔴 Resolved – Lost"}
                    </>}
                </div>

                <div className=" flex flex-row">
                    {position.isClaimed && (
                        <div className="text-secondary font-semibold text-sm mt-auto">
                            claimed
                        </div>
                    )}
                </div>

            </div>
            {/* <div className="text-sm text-secondary text-center font-semibold">
                { shortAddress( position.walletAddress)}
            </div> */}
        </div>
    )
}

const PositionRow = ({ item }: any) => {

    const [data, setData] = useState<any>(undefined)
    const { getOutcomeById } = useDatabase()

    useEffect(() => {
        item && getOutcomeById(item.predictedOutcome).then(setData)
    }, [item])

    return (
        <>
            <td className="py-2 pr-2 text-white ">
                <BadgePurple>
                    Round {item.roundId}
                </BadgePurple>
            </td>
            <td className="py-2 pr-2 text-white ">
                {data?.title}
            </td>
            {/* <td className="py-2 pr-2  ">
                <div className="flex flex-row "> 
                    <img src="https://s2.coinmarketcap.com/static/img/coins/64x64/3408.png" className="h-5 w-5 my-auto mx-1.5" />
                    <h2 className="my-auto text-white font-semibold">
                        {item.betAmount.toLocaleString()} USDC
                    </h2>
                </div>

            </td> */}
            <td className="py-2 pr-2  ">
                <div className="flex flex-row ">
                    ❌
                    <h2 className="my-auto ml-2 text-white/60 font-semibold">
                        {item.betAmount.toLocaleString()} USDC
                    </h2>
                </div>

            </td>
            <td className="py-2 pr-2 text-white   ">
                <button disabled={true} type="button" className="btn rounded-lg   bg-white py-1.5 text-sm px-4  hover:text-black hover:bg-white flex flex-row">
                    Claim
                </button>
            </td>
        </>
    )
}

export default MyBetPositions