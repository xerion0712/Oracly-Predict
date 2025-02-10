import { useState, useCallback, useEffect, useReducer, useContext } from "react"
import { generateClient } from "aws-amplify/api";
import { Schema } from "@/amplify/data/resource";
import { createAIHooks } from "@aws-amplify/ui-react-ai";
import { Puff } from 'react-loading-icons'
import useDatabase from "@/hooks/useDatabase";

const client = generateClient<Schema>({ authMode: "apiKey" });
const { useAIConversation, useAIGeneration } = createAIHooks(client);

const MarketOutcomes = ({ dispatch, resource, marketDescription, marketOutcomeA, marketOutcomeB, marketOutcomeC, marketOutcomeD, totalOutcomes }: any) => {

    const [state, suggestOutcomes] = useAIGeneration("OutcomeSegmentationAI")

    const { data, isLoading, hasError } = state

    const { crawl } = useDatabase()


    const [loading, setLoading] = useState<boolean>(false)
    const [errorMessage, setErrorMessage] = useState<any>()

    const onSuggest = useCallback(async () => {

        setErrorMessage(undefined)

        if (!resource) {
            setErrorMessage("Please select a resource")
            return
        }

        if (!marketDescription || marketDescription.length < 10) {
            setErrorMessage("Invalid description")
            return
        }

        setLoading(true)

        try {

            const context = await crawl(resource)

            const prompt = [
                `Given the question '${marketDescription}',`,
                `suggest ${totalOutcomes} outcomes based on available data, price trends `,
                "and any relevant factors from the provided context:",
                context
            ].join("")

            suggestOutcomes({ description: prompt })

        } catch (e: any) {
            console.log(e)
            setErrorMessage(`${e.message}`)
        }

        setLoading(false)

    }, [totalOutcomes, resource, marketDescription])

    useEffect(() => {

        if (data && data.outcomes) {

            dispatch({
                marketOutcomeA: data.outcomes[0] || undefined,
                marketOutcomeB: data.outcomes[1] || undefined,
                marketOutcomeC: data.outcomes[2] || undefined,
                marketOutcomeD: data.outcomes[3] || undefined,
            })

        }

    }, [data])

    return (
        <>
            <div className="grid grid-cols-7 mt-4">
                <div className="col-span-2 text-white text-lg font-semibold flex">
                    <div className="m-auto mr-4">
                        Number of Outcomes:
                    </div>
                </div>
                <div className="col-span-3">
                    <div className="grid grid-cols-3 gap-2">
                        {[2, 3, 4].map((value) => {
                            return (
                                <div className="col-span-1">
                                    <div onClick={() => {
                                        dispatch({
                                            totalOutcomes: value
                                        })
                                    }} className="bg-[#141F32] p-1 rounded-lg flex  border border-gray/30 cursor-pointer">
                                        <input type="radio" checked={totalOutcomes === value} name="disabled-radio" className="w-4 h-4 mr-0.5 my-auto ml-auto text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600" />
                                        <label className="ms-2 text-lg mr-auto font-semibold text-gray-400 dark:text-gray-500">
                                            {value === 2 && "A, B"}
                                            {value === 3 && "A, B, C"}
                                            {value === 4 && "A, B, C, D"}
                                        </label>
                                    </div>
                                </div>
                            )
                        })}
                    </div>
                </div>
                <div className="col-span-2 flex px-2">
                    <button onClick={onSuggest} disabled={loading || isLoading} type="button" className="btn ml-2 my-auto  rounded-lg w-[180px] bg-white py-2.5 px-8  hover:text-black hover:bg-white flex flex-row">
                        {(loading || isLoading)
                            ?
                            <Puff
                                stroke="#000"
                                className="w-5 h-5 mx-auto"
                            />
                            :
                            <div className="mx-auto">
                                AI Suggest
                            </div>}
                    </button>
                </div>
                <div className="col-span-2 ">

                </div>
                <div className="col-span-3">
                    {/* <p className="text-sm py-2 pb-0 ">Manually provide outcome options or let AI suggest them based on the data above.</p> */}
                    {!hasError && <p className="text-sm py-2 pb-0 ">Manually provide outcome options or let AI suggest them based on the data above.</p>}
                    {hasError && <p className="text-sm py-2 pb-0 text-secondary">The number of requests exceeds the limit. Try again later.</p>}
                </div>
                <div className="col-span-2 flex px-4">
                    {errorMessage && <p className="text-sm py-2 pb-0 text-center text-secondary">{errorMessage}</p>}
                </div>
            </div>

            <EachOutcome
                dispatch={dispatch}
                letter={"A"}
                outcome={marketOutcomeA}
                placeholder={"< $40K"}
                disabled={false}
            />
            <EachOutcome
                dispatch={dispatch}
                letter={"B"}
                outcome={marketOutcomeB}
                placeholder={"$40K - $50K"}
                disabled={false}
            />
            <EachOutcome
                dispatch={dispatch}
                letter={totalOutcomes > 2 ? "C" : "-"}
                outcome={marketOutcomeC}
                placeholder={"$50K - $60K"}
                disabled={totalOutcomes > 2 ? false : true}
            />
            <EachOutcome
                dispatch={dispatch}
                letter={totalOutcomes > 3 ? "D" : "-"}
                outcome={marketOutcomeD}
                placeholder={"> $60K"}
                disabled={totalOutcomes > 3 ? false : true}
            />

            <div className="grid grid-cols-7">

                <div className="col-span-2 ">

                </div>
                <div className="col-span-3">
                    <p className="text-sm py-2 pb-0 ">Please review your outcome options carefully to ensure they cover all possible scenarios.</p>
                </div>
            </div>

        </>
    )
}


const EachOutcome = ({ dispatch, outcome, letter, placeholder, disabled }: any) => {

    return (
        <div className="grid grid-cols-7 mt-4">
            <div className="col-span-2 text-white text-lg font-semibold flex">
                <div className="m-auto mr-4 flex flex-row">
                    Outcome <div className="ml-1 text-center w-[20px]">{letter}</div>:
                </div>
            </div>
            <div className="col-span-3">
                <div className="grid grid-cols-5 gap-3">
                    <div className="col-span-5">
                        <input
                            type="text"
                            disabled={disabled}
                            value={outcome}
                            placeholder={placeholder}
                            onChange={(e: any) => {
                                dispatch({ [`marketOutcome${letter}`]: e.target.value })
                            }}
                            className={`block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none ${disabled && "opacity-40"}`}
                        />
                    </div>
                    {/* <div className="col-span-1">
                        <input
                            type="number"
                            disabled={disabled}
                            value={probability}
                            onChange={(e: any) => {
                                dispatch({ [`probabilityOutcome${letter}`]: Number(e.target.value) })
                            }}
                            min={0}
                            max={1}
                            step={0.05}
                            className={`block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none ${disabled && "opacity-40"}`}
                        />
                    </div> */}
                </div>

            </div>
            <div className="col-span-1">

            </div>
            <div className="col-span-2 ">

            </div>
        </div>
    )
}

export default MarketOutcomes