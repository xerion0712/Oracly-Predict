
import useDatabase from "@/hooks/useDatabase"
import { generateClient } from "aws-amplify/api";
import { Schema } from "@/amplify/data/resource";
import { createAIHooks } from "@aws-amplify/ui-react-ai";
import { useCallback, useEffect, useState } from "react";

import { Puff } from 'react-loading-icons'

const client = generateClient<Schema>({ authMode: "apiKey" });
const { useAIConversation, useAIGeneration } = createAIHooks(client);


const MarketDescription = ({ marketDescription, resource, dispatch }: any) => {

    const [state, suggestTitle] = useAIGeneration("MarketCreationAI")

    const { data, isLoading, hasError } = state

    const [errorMessage, setErrorMessage] = useState<any>()
    const [loading, setLoading] = useState<boolean>(false) 

    const { crawl } = useDatabase()

    const onSuggest = useCallback(async () => {

        setErrorMessage(undefined)

        if (!resource) {
            setErrorMessage("Please select a resource")
            return
        }

        setLoading(true)

        try {

            const context = await crawl(resource)

            const prompt = [
                "Suggest a DeFi prediction market title that will be resolved in 7 days",
                "similar to 'What will the price of BTC be on Feb 1, 2025?'. The current date is ",
                `${(new Date().toDateString())}.`,
                "Use the following context:",
                context
            ].join("")

            suggestTitle({ description: prompt })

        } catch (e: any) {
            console.log(e)
            setErrorMessage(`${e.message}`)
        }

        setLoading(false)

    }, [resource])

    useEffect(() => {
        if (data && data.result) {
            dispatch({ marketDescription: `${data.result}` })
        }
    }, [data])

    return (
        <div className="grid grid-cols-7 mt-4">
            <div className="col-span-2 text-white text-lg font-semibold flex">
                <div className="m-auto mr-4">
                    Description:
                </div>
            </div>
            <div className="col-span-3">
                <textarea
                    rows={3}
                    value={marketDescription}
                    onChange={(e: any) => {
                        dispatch({ marketDescription: e.target.value })
                    }}
                    placeholder="What will be the total cryptocurrency market cap on Feb 6, 2025?"
                    className="block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none"
                />
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
                {!hasError && <p className="text-sm py-2 pb-0 ">Define your market question or let AI suggest one.</p>}
                {hasError && <p className="text-sm py-2 pb-0 text-secondary">The number of requests exceeds the limit. Try again later.</p>}
            </div>
            <div className="col-span-2 flex px-4">
                {errorMessage && <p className="text-sm py-2 pb-0 text-center text-secondary">{errorMessage}</p>}
            </div>

        </div>
    )

}

export default MarketDescription