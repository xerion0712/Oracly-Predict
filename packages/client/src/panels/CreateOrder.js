import BasePanel from "./Base"
import { useEffect, useState } from "react"
import Spinner from "../components/Spinner"
import { shortAddress } from "@/helpers"

import { Buy, Sell } from "../components/Trade"

const CreateOrder = ({ visible, close, tick, setTick }) => {

    const [tab, setTab] = useState(2)

    return (
        <BasePanel
            visible={visible}
            close={close}
        >
            <h2 class="text-2xl mb-2 mt-2 font-bold">
                Create New Order
            </h2>
            <hr class="my-12 h-0.5 border-t-0 bg-neutral-100 mt-2 mb-2 opacity-50" />
            <div class="col-span-5 flex flex-col   border-gray-600">
                <div class="font-medium text-center  border-b  text-gray-400 border-gray-700 mb-4 ">
                    <ul class="flex flex-wrap -mb-px">
                        <li class="  w-1/2">
                            <span onClick={() => setTab(1)} class={`w-full inline-block cursor-pointer p-4 border-b-2 rounded-t-lg ${tab === 1 ? "active text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"} `}>
                                Buy
                            </span>
                        </li>
                        <li class="  w-1/2">
                            <span onClick={() => setTab(2)} class={`w-full inline-block  cursor-pointer p-4  border-b-2  rounded-t-lg ${tab === 2 ? "active  text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"}`} aria-current="page">
                                Sell
                            </span>
                        </li>
                    </ul>
                </div>
                {tab === 1 && <Buy />}
                {tab === 2 && <Sell tick={tick} setTick={setTick} />}
            </div>
        </BasePanel>
    )
}


export default CreateOrder