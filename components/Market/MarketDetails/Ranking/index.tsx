import { Tab, TabGroup, TabList, TabPanel, TabPanels } from '@headlessui/react'
import WalletBalance from '../WalletBalance'
import useDatabase from '@/hooks/useDatabase'
import { useState, useEffect } from 'react'

const Ranking = ({ currentRound, marketData }: any) => {

    const { getOutcomes } = useDatabase()

    const [outcomes, setOutcomes] = useState([])

    useEffect(() => {
        currentRound > 0 && marketData ? getOutcomes(marketData.id, currentRound).then(setOutcomes) : setOutcomes([])
    }, [marketData, currentRound])

    return (
        <div className='p-2 pt-0 flex flex-grow flex-col space-y-3'>
            {/* <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                    🔥 Top Outcomes
                </h2>

            </div>

            <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                    🏆 Total Staked
                </h2>

            </div> */}

            <div className='flex-grow flex flex-col'>
                <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                    <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                        {/* 📓 Guide */}
                        🔥 Top Outcomes
                    </h2>
                    <div className='px-2 pb-4'>
                          <table className="w-full">
                        {/* <thead>
                            <tr className="text-left  ">
                            <th className="py-2  ">#</th> 
                                <th className="py-2  ">Outcome</th>  
                            </tr>
                        </thead> */}
                        <tbody>
                            {outcomes.filter((item:any) => item.totalBetAmount).sort(function (a: any, b: any) {
                        return Number(b.totalBetAmount) - Number(a.totalBetAmount)
                    }).map((item: any, index: number) => {
                        // const odds = `${(item.odds / 100).toFixed(0)}%`
                        // const allocation = totalBetsAmount*(item.odds/10000)

                        if (index > 2) {
                            return
                        }

                        return (
                            <tr key={index} className="border-b">
                                <td className="py-2 pr-2 text-white ">{index+1}.</td>
                                <td className="py-2 line-clamp-1 text-white overflow-hidden">{item.title}</td>
                                {/* <td width="15%" className="py-2  ">{item.totalBetAmount}</td> */}
                                {/* <td className="py-2  ">{odds}</td>
                                <td className="py-2  font-bold text-purple-400">{allocation.toLocaleString()} SUI</td> */}
                            </tr>
                        )
                    })

                    }
                        </tbody>
                    </table>
                    </div>
                  
                </div>
                <WalletBalance />
            </div>


        </div>
    )
}

export default Ranking