import { useContext, useReducer, useEffect, useState, useCallback } from "react"
import { Puff } from 'react-loading-icons'
import { LegatoContext } from "@/hooks/useLegato";
import Link from "next/link";
import useDatabase from "@/hooks/useDatabase";
import { BadgePurple } from "@/components/Badge";


const MyBetPositions = ({ marketData }: any) => {

    const { currentProfile }: any = useContext(LegatoContext)

    const { getMyPositions } = useDatabase()
    const [positions, setPositions] = useState<any>([])

    useEffect(() => {
        currentProfile && marketData && getMyPositions(currentProfile.id, marketData.id).then(setPositions)
    }, [currentProfile, marketData])

    console.log(positions)

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

                    <div className='flex-grow flex flex-col'>
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
                                        })

                                        }
                                    </tbody>
                                </table>
                            </div>
                        </div>

                    </div>

                    {/* <table className="w-full mt-4 ">
                        <thead className="text-white">
                            <tr className="text-left  ">
                                <th className="py-2  ">#</th>
                                <th className="py-2  ">Round</th>
                                <th className="py-2  ">Chosen Outcome</th>
                                <th className="py-2  ">Bet Amount</th>
                            </tr>
                        </thead>
                        <tbody>
                            {positions.map((item: any, index: number) => {

                                return (
                                    <tr key={index} className="border-b">
                                        <td className="py-2  ">{index + 1}.</td>
                                        <td className="py-2  ">{item.roundId}</td>
                                        <td className="py-2  ">{item.predictedOutcome}</td>
                                        <td className="py-2  font-bold text-purple-400">{item.betAmount}  USDC</td>
                                    </tr>
                                )
                            })

                            }
                        </tbody>
                    </table> */}
                </>
            )}

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