
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Puff } from 'react-loading-icons'
import { useState, useReducer, useEffect, useCallback, useContext } from 'react'
import InputStake from "@/components/InputStake";
import InputUnstake from "@/components/InputUnstake";
import ListGroup from "@/components/ListGroup";

enum Tab {
    Deposit = "deposit",
    Withdraw = "withdraw"
}

const StakePanel = () => {

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            activeTab: Tab.Deposit,
            depositAmount: 0,
            aptAvailable: 0,
            lpAvailable: 0,
            tick: 1,
            errorMessage: undefined,
            loading: false
        }
    )

    const { activeTab, depositAmount, errorMessage, loading, tick, aptAvailable, lpAvailable } = values

    const onDepositChange = (depositAmount: number) => {
        dispatch({
            depositAmount
        })
    }

    const onMint = useCallback(async () => {

    }, [])

    const onRedeem = useCallback(async () => {

    }, [])

    const estimateOutput = 0
    const estimateOutput2 = 0
    const estimateAmount = 0
    const expected = new Date()

    return (
        <>
            <div className='p-2 px-0 mt-2 lg:mt-0 h-[500px]'>
                <div className={`rounded-lg bg-black mt-2 `}>

                    {/* NAV */}

                    <div className='grid grid-cols-2 text-center text-base sm:text-lg overflow-hidden font-bold  leading-7'>
                        <div className={`cursor-pointer py-4 ${activeTab === Tab.Deposit ? "text-white" : "bg-[#141F32] rounded-tl-lg"}`} onClick={() => dispatch({ activeTab: Tab.Deposit, depositAmount: 0, errorMessage: undefined })}>
                            Stake
                        </div>
                        <div className={`cursor-pointer py-4 ${activeTab === Tab.Withdraw ? "text-white" : "bg-[#141F32] rounded-tr-lg"}`} onClick={() => dispatch({ activeTab: Tab.Withdraw, depositAmount: 0, errorMessage: undefined })}>
                            Unstake
                        </div>
                    </div>

                    <div className='p-4'>
                        {activeTab === Tab.Deposit && (
                            <div className='py-3'>

                                <InputStake
                                    value={depositAmount}
                                    onChange={onDepositChange}
                                    symbol="apt"
                                    available={aptAvailable}
                                />



                                <div className="px-1 mt-4 sm:mt-6">
                                    <ListGroup
                                        items={[
                                            ["You will receive", `${estimateOutput.toFixed(6)} LP`],
                                            ["Projected rewards", `${estimateAmount.toLocaleString()} APT per month`]
                                        ]}
                                    />
                                </div>
                                <div className="flex mt-6">
                                    <button onClick={onMint} disabled={loading} type="button" className="btn mx-auto w-full bg-white rounded-md hover:bg-white hover:text-black">
                                        {loading
                                            ?
                                            <Puff
                                                stroke="#000"
                                                className="w-5 h-5 mx-auto"
                                            />
                                            :
                                            <>
                                                Deposit
                                            </>}
                                    </button>
                                </div>
                                {errorMessage && (
                                    <div className='text-gray-400 mt-2 text-sm font-medium  text-center w-full '>
                                        <div className='p-2 pb-0 text-secondary'>
                                            {errorMessage}
                                        </div>
                                    </div>
                                )}

                            </div>
                        )}
                        {activeTab === Tab.Withdraw && (
                            <div className='py-3'>

                                <InputUnstake
                                    value={depositAmount}
                                    onChange={onDepositChange}
                                    symbol="apt"
                                    balance={lpAvailable}
                                />

                                <div className="px-1 mt-4 sm:mt-6">
                                    <ListGroup
                                        items={[
                                            ["You will receive", `${estimateOutput2.toFixed(6)} APT`],
                                            ["Expected withdrawal completion", (expected.toDateString())]
                                        ]}
                                    />
                                </div>

                                <div className="flex mt-6">
                                    <button onClick={onRedeem} disabled={loading} type="button" className="btn mx-auto w-full rounded-md bg-white hover:bg-white hover:text-black">
                                        {loading
                                            ?
                                            <Puff
                                                stroke="#000"
                                                className="w-5 h-5 mx-auto"
                                            />
                                            :
                                            <>
                                                Proceed
                                            </>}
                                    </button>
                                </div>
                                {errorMessage && (
                                    <div className='text-gray-400 mt-2 text-sm font-medium  text-center w-full '>
                                        <div className='p-2 pb-0 text-secondary'>
                                            {errorMessage}
                                        </div>
                                    </div>
                                )}

                            </div>
                        )}
                    </div>

                </div>
            </div>
        </>
    )
}

export default StakePanel