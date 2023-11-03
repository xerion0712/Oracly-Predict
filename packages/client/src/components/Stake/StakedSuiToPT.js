import { useState } from "react"
import { ArrowRightIcon } from "@heroicons/react/20/solid"
import Selector from "../Selector"
import Vault from "../../data/vault.json"


const StakedSuiToPT = () => {

    const [selected, setSelected] = useState(Vault[0])

    return (
        <div>
            <Selector
                name="Vault to stake into"
                selected={selected}
                setSelected={setSelected}
                options={Vault}
            />
            <div class="grid grid-cols-2 gap-2  mb-6 mt-6">
                <div>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Available to stake
                    </div>
                    <div className='flex flex-row text-lg'>
                        <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                        {/* {items.length} (~{myBalance.toLocaleString()} Sui) */}
                        1 (~1 Sui)
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Total Staked
                    </div>
                    <div className="text-2xl">
                        {/* ${(totalSupply * 0.45).toLocaleString()} */}
                        $1,234
                    </div>
                </div>
            </div>

            <div class="grid grid-cols-2 gap-2  mb-6 mt-6">
                <div>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Staked amount
                    </div>
                    <div className='flex flex-row text-lg'>
                        <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mr-2  mt-auto mb-auto flex-shrink-0 rounded-full" />
                        {/* {totalSupply.toLocaleString()} */}
                        100.34
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        APY
                    </div>
                    <div className="text-2xl">
                        {/* {apr.toLocaleString()}% */}
                        4.02%
                    </div>
                </div>
            </div>
            <button   className=" py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                Next
                <ArrowRightIcon className="h-5 w-5 ml-2" />
            </button>
        </div>
    )
}

export default StakedSuiToPT