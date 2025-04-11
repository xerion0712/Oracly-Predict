import { useCallback, useContext, useEffect, useReducer, useState, useRef } from 'react';
import useAI from "../../../../hooks/useAI"
import { SpinningCircles } from 'react-loading-icons'
import ReactMarkdown from 'react-markdown';
import rehypeHighlight from 'rehype-highlight';
import { Send } from "react-feather"
import NewOutcomeModal from '@/modals/newOutcome/new';


// TEMP

const ChatPanelMoveAgentKit = ({
    currentRound,
    marketData,
    onchainMarket,
    openBetModal
}: any) => {

    const { query, query2 } = useAI()

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            text: "",
            loading: false,
            messages: [],
            outcomes: []
        }
    )

    const { text, loading, messages, outcomes } = values

    useEffect(() => {
        onchainMarket && marketData && prepareMessages(currentRound, marketData, onchainMarket)
    }, [currentRound, marketData, onchainMarket])

    const prepareMessages = useCallback(async (currentRound: number, marketData: any, onchainMarket: any) => {

        // const resource = await marketData.resource()

        // if (resource && resource.data) {

        //     const source = resource.data.name
        //     const context = await crawl(resource.data)

        //     const startPeriod = (Number(onchainMarket.createdTime) * 1000) + (onchainMarket.round * (Number(onchainMarket.interval) * 1000))
        //     const endPeriod = startPeriod + (Number(onchainMarket.interval) * 1000)
        //     const period = `${new Date(startPeriod).toDateString()} - ${new Date(endPeriod).toDateString()}`

        //     const agent = new Agent()
        //     const systemPrompt = agent.getSystemPrompt(currentRound, source, parseTables(context), period)

        //     const outcomes = await getOutcomes(marketData.id, currentRound)
        //     const outcomePrompt = agent.getOutcomePrompt(outcomes)

        //     dispatch({
        //         messages: [systemPrompt, outcomePrompt]
        //     })
        // }

        dispatch({
            messages: []
        })

    }, [])

    const onSend = useCallback(async () => {

        if (!text || text.length < 2) {
            return
        }

        const userPrompt = {
            role: 'user',
            content: text
        }

        dispatch({
            loading: true,
            messages: [...messages, userPrompt],
            text: ""
        })

        try {

            // check whether need to add outcomes or not
            const sendingMessages = [...messages, userPrompt]

            const addOutcomeResult = await query([
                {
                    role: "system",
                    content: "You are a helpful AI assistant that checks incoming messages and adds new outcomes to the Legato DeFi prediction market or place bets. When proposing new outcomes, please include the protocol name at the end of the sentence."
                },
                ...sendingMessages
            ])

            console.log("addOutcomeResult: ", addOutcomeResult)

            if (addOutcomeResult.tool_calls) {
                // Add outcomes
                console.log("add outcomes...")

                const outcomes = addOutcomeResult.tool_calls.filter((tool: any) => tool.function.name === "create_outcome").map((tool: any) => {
                    return JSON.parse(tool.function.arguments)
                })

                if (outcomes.length > 0) {
                    dispatch({
                        outcomes: [...outcomes],
                        messages: [...messages, userPrompt, {
                            role: "assistant",
                            content: "A confirmation popup will appear."
                        }]
                    })
                }

                const bets = addOutcomeResult.tool_calls.filter((tool: any) => tool.function.name === "place_bet").map((tool: any) => {
                    return JSON.parse(tool.function.arguments)
                })

                if (bets.length > 0) {
                    dispatch({
                        messages: [...messages, userPrompt, {
                            role: "assistant",
                            content: "A confirmation popup will appear."
                        }]
                    })
                    const currentBet = bets[0]
                    openBetModal({
                        marketId: marketData.id,
                        roundId: currentBet.roundId,
                        outcomeId: currentBet.outcomeId,
                    })
                }

            } else {
                // Proceed with Move Agent Kit
                console.log("Proceed with Move Agent Kit")

                const startPeriod = (Number(onchainMarket.createdTime) * 1000) + (onchainMarket.round * (Number(onchainMarket.interval) * 1000))
                const endPeriod = startPeriod + (Number(onchainMarket.interval) * 1000)
                const period = `${new Date(startPeriod).toDateString()} - ${new Date(endPeriod).toDateString()}`

                const output: any = await query2([...messages, userPrompt], currentRound, period)
                const result = output[output.length - 1]

                console.log("result: ", result)

                if (result.content) {
                    dispatch({
                        messages: [...messages, userPrompt, {
                            role: "assistant",
                            content: result.content
                        }]
                    })
                }
            }

        } catch (e) {
            console.log(e)
        }

        dispatch({
            loading: false
        })

    }, [text, messages, marketData, currentRound, onchainMarket])

    const chatContainerRef: any = useRef(null);

    useEffect(() => {
        const scrollToBottom = () => {
            if (chatContainerRef.current) {
                chatContainerRef.current.scrollTop = chatContainerRef.current.scrollHeight;
            }
        };

        scrollToBottom();

        // Observe changes to the chat container's content (e.g., new messages)
        const observer = new MutationObserver(scrollToBottom);
        if (chatContainerRef.current) {
            observer.observe(chatContainerRef.current, { childList: true, subtree: true });
        }

    }, []);

    const updateMessages = useCallback(async () => { 
        console.log("update messages...") 
    }, [messages, currentRound, marketData])

    console.log("messages : ", messages)

    return (
        <>
            <NewOutcomeModal
                visible={outcomes.length > 0}
                close={() => dispatch({ outcomes: [] })}
                outcomes={outcomes}
                marketData={marketData}
                currentRound={currentRound}
                updateMessages={updateMessages}
            />

            <div className={`  bg-white dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent  rounded-t-xl  px-2 sm:px-5  border border-transparent `} >
                <div className="flex items-center justify-between my-2 ">
                    <h2 className="text-lg my-auto   text-white font-semibold">💬 Chat</h2>
                    <div className="my-auto flex flex-row  ">
                        <div className="relative mt-auto mb-auto">
                            <div className="w-3 h-3 bg-secondary rounded-full"></div>
                            {onchainMarket && (
                                <>
                                    <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-ping"></div>
                                    <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-pulse"></div>
                                </>
                            )}
                        </div>
                        <div className="font-semibold text-secondary my-auto mx-2.5 ">
                            {onchainMarket ? "Active" : "Inactive"}
                        </div>
                    </div>
                </div>
            </div>
            <div className="bg-gray-dark  px-2 py-4 rounded-b-xl flex">

                <div className='  flex flex-col w-full'>

                    <div className="flex-grow overflow-y-auto h-[320px] space-y-2 px-2.5" ref={chatContainerRef}>

                        {(messages.length === 0) && (
                            <div className=" flex flex-row  bg-secondary/10 mb-3 rounded-lg text-secondary  text py-2 px-4  font-normal   ">
                                💡 {` `}Start by saying 'Hello' or ask about the source data, like 'What are yield rates on Joule?'
                            </div>
                        )}

                        {messages.map((item: any, index: number) => {

                            if (item.role === "system") {
                                return
                            }

                            if (item.role === "assistant" && !item.content) {
                                return
                            }

                            return (
                                <div key={index}>
                                    {item.role === "user" && (
                                        <div className="flex justify-end">
                                            <div className="bg-secondary/10 text-secondary  text-sm p-3 rounded-lg max-w-lg">
                                                {item.content}
                                            </div>
                                        </div>
                                    )}
                                    {item.role === "assistant" && (
                                        <div className="flex text-white justify-start">
                                            <div className="text-sm p-3 ">
                                                <ReactMarkdown rehypePlugins={[rehypeHighlight]}>
                                                    {item.content}
                                                </ReactMarkdown>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            )
                        })}

                        {loading && (
                            <div className="flex text-lg justify-start">
                                <div className="bg-gray-dark text-sm p-3 rounded-lg flex flex-row">
                                    <SpinningCircles className='h-5 w-5 mr-1.5' />
                                    Please wait while your request is being processed
                                </div>
                            </div>
                        )}
                    </div>

                    <div className="flex items-center mt-4 bg-gray-800 p-2 rounded-lg">
                        <input
                            value={text}
                            type="text"
                            onChange={(e) => dispatch({ text: e.target.value })}
                            placeholder="Ask AI-Agent..."
                            className="block w-full p-2 px-4 rounded-l-lg text-base bg-[#141F32] border border-gray/30 border-r-0 placeholder-gray text-white focus:outline-none"
                        />
                        <div className="cursor-default flex border border-l-0 border-gray/30 bg-[#141F32] px-2 rounded-r-lg h-full">
                            <button onClick={onSend} disabled={loading} className={`m-auto flex flex-row bg-secondary/10 rounded-lg text-secondary   py-0.5 px-4  font-normal border border-transparent `}>
                                <span className='my-auto font-semibold'>Send</span>{` `}<Send size={20} className='my-auto ml-2' />
                            </button>
                        </div>
                    </div>
                </div>

            </div>
            <style>
                {`
                    h1 {
                        font-size: 24px;
                        font-weight: 600;
                        margin-top: 5px;
                        margin-bottom: 5px;
                    }
                    h2 {
                        font-size: 18px;
                        font-weight: 600;
                        margin-top: 5px;
                        margin-bottom: 5px;
                    }
                    h3 {
                        font-size: 16px;
                        font-weight: 600;
                        margin-top: 5px;
                        margin-bottom: 5px;
                    }
        `}
            </style>

        </>
    )
}

export default ChatPanelMoveAgentKit