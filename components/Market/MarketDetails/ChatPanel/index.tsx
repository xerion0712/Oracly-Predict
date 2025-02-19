

const ChatPanel = () => {
    return (
        <>
            {/* <div className="bg-black bg-gradient-to-b flex flex-col  from-white/[0.03]  to-transparent  p-4 rounded-lg  overflow-hidden  border  border-gray/30  ">
               
                <div className="flex items-center justify-between mb-4 pl-3">
                    <h2 className="text-xl my-auto uppercase text-white font-semibold">Chat with Round Manager</h2>
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
            </div> */}

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