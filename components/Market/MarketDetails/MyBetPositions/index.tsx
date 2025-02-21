import { useContext, useReducer, useEffect, useState, useCallback } from "react"
import { Puff } from 'react-loading-icons'
import { LegatoContext } from "@/hooks/useLegato";
import Link from "next/link";
import useDatabase from "@/hooks/useDatabase";


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
                <table className="w-full mt-4 ">
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
                                    <td className="py-2  ">{index+1}.</td>
                                    <td className="py-2  ">{item.roundId}</td>
                                    <td className="py-2  ">{item.predictedOutcome}</td>
                                    <td className="py-2  font-bold text-purple-400">{item.betAmount}  USDC</td>
                                </tr>
                            )
                        })

                        }
                    </tbody>
                </table>
            ) }

        </div>
    )
}

export default MyBetPositions