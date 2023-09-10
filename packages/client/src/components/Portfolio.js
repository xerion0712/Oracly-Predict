import { useState } from "react"


const Portfolio = () => {

    const [tab, setTab] = useState(1)

    return (
        <div>
            <div className="max-w-4xl mx-auto">
                <div class="wrapper pt-10">
                    <p class="text-neutral-400 text-sm p-5 text-center">
                        All your positions on Legato
                    </p>
                    <div class="rounded-xl p-px bg-gradient-to-b  from-blue-800 to-purple-800">
                        <div class="rounded-[calc(0.8rem-1px)] p-10 pl-5 pr-5 pt-3 bg-gray-900">
                            <div class="text-sm font-medium text-center  border-b  text-gray-400 border-gray-700">
                                <ul class="flex flex-wrap -mb-px">
                                    <li class="mr-2">
                                        <span onClick={() => setTab(1)} class={`inline-block cursor-pointer p-4 border-b-2 rounded-t-lg ${tab === 1 ? "active text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"} `}>
                                            PT & YT
                                        </span>
                                    </li>
                                    <li class="mr-2">
                                        <span onClick={() => setTab(2)} class={`inline-block  cursor-pointer p-4  border-b-2  rounded-t-lg ${tab === 2 ? "active  text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"}`} aria-current="page">
                                            Liquidity
                                        </span>
                                    </li>
                                </ul>
                            </div>

                            <div class="h-[200px] flex">
                                <div class="mx-auto font-medium mt-auto mb-auto">
                                    No active positions
                                </div>

                            </div>

                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default Portfolio