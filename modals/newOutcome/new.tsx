import { useContext, useReducer, useEffect, useState, useCallback } from "react"
import BaseModal from "../base"
import { Puff } from 'react-loading-icons'

import useDatabase from "../../hooks/useDatabase";

const NewOutcomeModal = ({ visible, close, outcomes, marketData, currentRound, updateMessages }: any) => {

    const { addOutcome } = useDatabase()

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            current: 0,
            errorMessage: undefined,
            loading: false
        }
    )

    const { current, errorMessage, loading } = values

    useEffect(() => {
        outcomes.length > 0 && dispatch({ current: 0, errorMessage: undefined })
    }, [outcomes])

    const onAdd = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!marketData || !marketData.id) {
            dispatch({ errorMessage: "Invalid market entry" })
            return
        }

        if (!currentRound) {
            dispatch({ errorMessage: "Invalid current round" })
            return
        }

        dispatch({ loading: true })

        try {

            const marketId = marketData.id
            const roundId = currentRound
            const outcome = outcomes[current]

            await addOutcome({
                marketId,
                roundId,
                title: outcome.title,
                resolutionDate: outcome.resolutionDate
            })

            await updateMessages()

        } catch (e: any) {
            console.log(e)
            dispatch({ errorMessage: `${e.message}`, loading: false })
        }

        dispatch({ loading: false })

        if (current === outcomes.length - 1) {
            dispatch({ current: 0, errorMessage: undefined })
            close()
            return
        }

        dispatch({ current: current + 1 })

    }, [current, outcomes, marketData, currentRound])

    const onNext = useCallback(async () => {

        if (current === (outcomes.length - 1)) {
            close()
            return
        }

        dispatch({ current: current + 1 })

    }, [current])

    return (
        <BaseModal
            visible={visible}
            close={close}
            title={`Add New Outcomes (${outcomes.length})`}
            maxWidth="max-w-xl"
        >

            {outcomes.map((outcome: any, index: number) => {

                if (current !== index) {
                    return
                }

                return (
                    <div key={index} className="flex flex-col">
                        <div className="flex flex-col text-center p-4 ">
                            <div className="text-white mx-auto text-xl font-semibold ">
                                {outcome.title}
                            </div>
                            <div className="py-2  text-base font-semibold text-gray">
                                Resolution date: <span className="text-white"> {outcome.resolutionDate}</span>
                            </div>
                        </div>
                    </div>
                )
            })}

            <div className="grid grid-cols-2 gap-3">
                <button onClick={onAdd} disabled={loading} type="button" className="btn py-3 mx-auto w-full bg-white hover:bg-white hover:text-black rounded-md">
                    {loading
                        ?
                        <Puff
                            stroke="#000"
                            className="w-5 h-5 mx-auto"
                        />
                        :
                        <>
                            ✅ Add
                        </>}
                </button>
                <button onClick={onNext} disabled={loading} type="button" className="btn py-3 mx-auto w-full bg-white hover:bg-white hover:text-black rounded-md">
                    ❌ Not Add
                </button>

            </div>

            {errorMessage && (
                <div className='text-gray-400 mt-2 text-sm font-medium  text-center w-full '>
                    <div className='p-2 pb-0 text-secondary'>
                        {errorMessage}
                    </div>
                </div>
            )}

        </BaseModal>
    )

}

export default NewOutcomeModal