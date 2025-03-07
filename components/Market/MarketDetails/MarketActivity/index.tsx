import React, { useState, useEffect } from 'react';
import { ChevronDown, ChevronUp, Clock, ArrowUpRight, ArrowDownRight } from "react-feather"

import { shortAddress } from "../../../../helpers"
import useDatabase from '@/hooks/useDatabase';

const MarketActivity = () => {

    const [isExpanded, setIsExpanded] = useState(true);

    const { getRecentActivities } = useDatabase()

    const [activities, setActivities] = useState<any>([])

    useEffect(() => {
        getRecentActivities().then(setActivities)
    }, [])

    // Helper function to format time relative to now
    const formatRelativeTime = (timestamp: number) => {
        const now = Math.floor(new Date().valueOf() / 1000);
        const diffInSeconds = now - timestamp

        if (diffInSeconds < 60) return `${diffInSeconds}s ago`;
        if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
        if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
        return `${Math.floor(diffInSeconds / 86400)}d ago`;
    };

    // Helper to get transaction icon
    const getTransactionIcon = (type: any) => {
        switch (type) {
            case 'bet':
                return <ArrowUpRight className="w-4 h-4 text-green-500" />;
            case 'claim':
                return <ArrowDownRight className="w-4 h-4 text-purple-500" />;
            // case 'liquidity':
            //     return <Wallet className="w-4 h-4 text-blue-500" />;
            case 'outcome':
                return <Clock className="w-4 h-4 text-orange-500" />;
            default:
                return <Clock className="w-4 h-4 text-gray-500" />;
        }
    };

    // Helper to get transaction type display text
    const getTransactionTypeText = (type: any) => {
        switch (type) {
            case 'bet': return 'Placed Bet';
            case 'claim': return 'Claimed Prize';
            case 'liquidity': return 'Added Liquidity';
            case 'outcome': return 'Proposed Outcome';
            default: return 'Transaction';
        }
    };


    return (
        <div className="w-full mt-[20px] sm:mt-[40px]  overflow-hidden">
            {/* Header */}
            <div
                className="flex flex-col px-0 py-3 text-white  "
            >
                <h2 className="text-2xl font-semibold ">Recent Market Activities</h2>
                <div className="flex flex-row mt-1 ">
                    <div className='text-gray text-lg font-semibold mr-1 '>
                        Smart Contract Address:
                    </div>
                    <a href="https://explorer.aptoslabs.com/account/0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775?network=testnet" target="_blank" className="text-lg  text-secondary">
                        {shortAddress("0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775", 10, -8)}
                    </a>
                </div>
            </div>

            {/* Activity List */}
            {isExpanded && (
                <div className="px-0 py-2  ">
                    {activities.length > 0 ? (
                        <ul className="divide-y-2 divide-gray/20">
                            {activities.map((activity: any, index: number) => (
                                <li
                                    key={index}
                                    className={`py-3 text-white  transition-colors ${activity.isUserTx ? 'bg-blue-50' : ''}`}
                                >
                                    <div className="flex items-center justify-between">


                                        <div className={`flex flex-row bg-secondary/10 rounded-lg text-secondary   py-0.5 px-4  font-normal border border-transparent `}>
                                            <div className="flex-shrink-0 my-auto">
                                                {getTransactionIcon(activity.activity)}
                                            </div>
                                            <div className="flex-1 ml-1 my-auto min-w-0">
                                                <p className="text-sm font-semibold text-gray-900 truncate">
                                                    {getTransactionTypeText(activity.activity)}
                                                    {activity.activity === "bet" && (
                                                        <span className={`text-sm ml-1  ${activity.type === 'claim' ? 'text-green-600 font-medium' : 'text-gray-700'}`}>
                                                            {activity.betAmount} USDC
                                                        </span>
                                                    )}
                                                </p>
                                            </div>
                                        </div>
                                        {activity.activity === "outcome" && (
                                            <p className="text-base text-gray-500 line-clamp-1">
                                                {activity.title}
                                            </p>
                                        )}
                                        {activity.activity === "bet" && <OutcomeText outcomeId={activity.predictedOutcome} />}
                                        <div className="flex items-end flex-row">
                                            <p className="text-sm my-auto text-gray-500">
                                                {formatRelativeTime(Math.floor(new Date(activity.createdAt).valueOf() / 1000))}
                                            </p>
                                        </div>
                                    </div>
                                </li>
                            ))}
                        </ul>
                    ) : (
                        <div className="py-6 text-center text-gray-500">
                            No activity yet in this market
                        </div>
                    )}
                </div>
            )}

        </div>
    )
}

const OutcomeText = ({ outcomeId }: any) => {

    const { getOutcomeById } = useDatabase()
    const [text, setText ] = useState("")

    useEffect(() => {
        outcomeId && getOutcomeById(outcomeId).then(
            ({ title }: any) => {
                setText(title)
            }
        )
    },[outcomeId])

    return (
        <p className="text-base text-gray-500 line-clamp-1">
            {text}
        </p>
    )
}

export default MarketActivity