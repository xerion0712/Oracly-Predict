import { AIConversation } from '@aws-amplify/ui-react-ai';
import { LegatoContext } from "@/hooks/useLegato";
import { useCallback, useContext, useEffect, useReducer, useState, useRef } from 'react';
import Link from "next/link"
import { Send } from "react-feather"
import { SpinningCircles } from 'react-loading-icons'
import ReactMarkdown from 'react-markdown';
import rehypeHighlight from 'rehype-highlight';
import Alert from "../../../Alert"
import useDatabase from '@/hooks/useDatabase';
import Agent from "../../../../amplify/lib/agent"
import { parseTables } from "../../../../helpers"
// import useAtoma from '@/hooks/useAtoma';
import useOpenAI from '@/hooks/useOpenAI';
import NewOutcomeModal from '@/modals/newOutcome/new';

const ChatPanel = ({
    currentRound,
    marketData,
    onchainMarket
}: any) => {


    const [isConnected, setConnected] = useState<boolean>(true)
    const { getOutcomes, crawl } = useDatabase()
    const { query } = useOpenAI()

    const { currentProfile }: any = useContext(LegatoContext)

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

        const resource = await marketData.resource()

        if (resource && resource.data) {

            const source = resource.data.name
            const context = await crawl(resource.data)

            const startPeriod = (Number(onchainMarket.createdTime) * 1000) + (onchainMarket.round * (Number(onchainMarket.interval) * 1000))
            const endPeriod = startPeriod + (Number(onchainMarket.interval) * 1000)
            const period = `${new Date(startPeriod).toDateString()} - ${new Date(endPeriod).toDateString()}`

            const agent = new Agent()
            const systemPrompt = agent.getSystemPrompt(currentRound, source, parseTables(context), period)

            const outcomes = await getOutcomes(marketData.id, currentRound)
            const outcomePrompt = agent.getOutcomePrompt(outcomes)

            dispatch({
                messages: [systemPrompt, outcomePrompt]
            })
        }
    }, [])

    const updateMessages = useCallback(async () => {

        if (messages[1]) {
            const agent = new Agent()
            const outcomes = await getOutcomes(marketData.id, currentRound)
            const outcomePrompt = agent.getOutcomePrompt(outcomes)
            messages[1] = outcomePrompt
            
            dispatch({
                messages
            })
        }

    }, [messages, currentRound, marketData])

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

            const result = await query([...messages, userPrompt])

            // const result: any = {
            //     "role": "assistant",
            //     "content": null,
            //     "tool_calls": [
            //         {
            //             "id": "call_xaZ8ASYIlShsdHcNhldIxD9p",
            //             "type": "function",
            //             "function": {
            //                 "name": "create_outcome",
            //                 "arguments": "{\"title\": \"Bitcoin (BTC) to exceed $100,000 by March 4, 2025\", \"resolutionDate\": \"2025-03-04\"}"
            //             }
            //         },
            //         {
            //             "id": "call_cJB1mrUI7EWxMJ2nUTqwa75A",
            //             "type": "function",
            //             "function": {
            //                 "name": "create_outcome",
            //                 "arguments": "{\"title\": \"Ethereum (ETH) to rise above $3,000 by March 4, 2025\", \"resolutionDate\": \"2025-03-04\"}"
            //             }
            //         },
            //         {
            //             "id": "call_7Ak9LZCmhil4ulYxoVrjM8Kx",
            //             "type": "function",
            //             "function": {
            //                 "name": "create_outcome",
            //                 "arguments": "{\"title\": \"XRP to reach $3 by March 4, 2025\", \"resolutionDate\": \"2025-03-04\"}"
            //             }
            //         }
            //     ],
            //     "refusal": null
            // }

            if (result.content) {
                dispatch({
                    messages: [...messages, userPrompt, {
                        role: "assistant",
                        content: result.content
                    }]
                })
            } else if (result.tool_calls) {
                const outcomes = result.tool_calls.map((tool: any) => {
                    return JSON.parse(tool.function.arguments)
                })

                dispatch({
                    outcomes: [...outcomes],
                    messages: [...messages, userPrompt, {
                        role: "assistant",
                        content: "A confirmation popup will appear."
                    }]
                })

            }



        } catch (e) {
            console.log(e)
        }

        dispatch({
            loading: false
        })

    }, [text, messages])

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
                            {messages.length !== 0 && (
                                <>
                                    <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-ping"></div>
                                    <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-pulse"></div>
                                </>
                            )}
                        </div>
                        <div className="font-semibold text-secondary my-auto mx-2.5 ">
                            {messages.length !== 0 ? "Active" : "Inactive"}
                        </div>
                    </div>
                </div>
            </div>
            <div className="bg-gray-dark  px-2 py-4 rounded-b-xl flex">

                <div className='  flex flex-col w-full'>

                    <div className="flex-grow overflow-y-auto h-[320px] space-y-2 px-2.5" ref={chatContainerRef}>

                        {(messages.length !== 0) && (
                            <div className=" flex flex-row  bg-secondary/10 mb-3 rounded-lg text-secondary  text py-2 px-4  font-normal   ">
                                💡 {` `}Start by saying 'Hello' or ask about the source data, like 'What is the BTC price?'
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

// const ChatInner = ({ id }: any) => {

//     const { useAIConversation, useAIGeneration } = createAIHooks(client)


//     const [
//         xxx,
//         handleSendMessage,
//     ] = useAIConversation('chat');

//     const {
//         data: { messages },
//         isLoading,
//     } = xxx

//     console.log(xxx)

//     return (
//         <AIConversation
//             messages={messages}
//             isLoading={isLoading}
//             handleSendMessage={handleSendMessage}
//         />
//     )
// }

const ChatPanelOLD = () => {
    return (
        <>
            <div className={`  bg-white dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent  rounded-t-xl  px-2 sm:px-5  border border-transparent `} >
                <div className="flex items-center justify-between my-2 ">
                    <h2 className="text-lg my-auto   text-white font-semibold">🤖 Chat</h2>
                    <div className="my-auto flex flex-row  ">
                        <div className="relative mt-auto mb-auto">
                            <div className="w-3 h-3 bg-secondary rounded-full"></div>
                            <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-ping"></div>
                            <div className="w-3 h-3 bg-secondary rounded-full absolute top-0 left-0 animate-pulse"></div>
                        </div>
                        <div className="font-semibold text-secondary my-auto mx-2.5 ">
                            Active
                        </div>
                    </div>
                </div>
            </div>

            <div className="bg-gray-dark  px-2 py-4 rounded-b-xl ">


                <div className="h-[250px] overflow-y-auto bg-transparent p-3 rounded-lg space-y-2">
                    <div className="flex justify-start">
                        <div className="bg-gray-dark text-sm p-3 rounded-lg max-w-xs">
                            🔍 Analyzing market trends...
                        </div>
                    </div>
                    <div className="flex justify-end">
                        <div className="bg-secondary/10 text-secondary text-sm p-3 rounded-lg max-w-xs">
                            What’s the best outcome to bet on?
                        </div>
                    </div>
                    <div className="flex justify-start">
                        <div className="bg-gray-dark text-sm p-3 rounded-lg max-w-xs">
                            ✅ BTC has a **75% probability** to stay between **$95K - $98K**.
                        </div>
                    </div>
                </div>

                {/* Input Box */}
                <div className="flex items-center mt-4 bg-gray-800 p-2 rounded-lg">
                    <input
                        type="text"
                        placeholder="Ask AI-Agent..."
                        className="w-full p-2 bg-transparent border-none text-white placeholder-gray-400 outline-none"
                    />
                    <button className="ml-2 p-2 bg-blue-500 rounded-lg hover:bg-blue-600">
                        ➤
                    </button>
                </div>


            </div>
        </>
    )
}

export default ChatPanel