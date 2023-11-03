import { useState } from "react"
import { ArrowRightIcon } from "@heroicons/react/20/solid"
import Selector from "../Selector"
import Vault from "../../data/vault.json"
import ValidatorDetails from "@/panels/ValidatorDetails"


const SuiToStakedSui = ({
    avgApy,
    validators,
    suiPrice
}) => {

    const parsedValidator = validators.map((item, index) => ({
        index,
        ...item,
        name: `${item.name}`,
        image: item.imageUrl,
        value: `APY: ${item.apy.toFixed(2)}%`,
        suiPrice
    }))

    const [selected, setSelected] = useState(parsedValidator[0])
    // details panel
    const [panel, setPanel] = useState(false)

    const onSelectIndex = (index) => {
        if (index >= 0 && validators.length > index) setSelected(parsedValidator[index])
    }

    return (
        <div>
            <ValidatorDetails
                visible={panel}
                close={() => setPanel(false)}
                data={selected}
                select={onSelectIndex}
            />
            <Selector
                name="Validator to stake into"
                selected={selected}
                setSelected={setSelected}
                options={parsedValidator}
            />
            <div class="text-xs flex font-medium text-gray-300 justify-end flex-row mt-2">
                <a onClick={() => setPanel(true)} className="flex flex-row hover:underline cursor-pointer">
                    Details
                    <ArrowRightIcon className="h-4 w-4 ml-[1px]" />
                </a>

            </div>
            <div class="grid grid-cols-2 gap-2  mb-6 mt-4">
                <div>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Available to stake
                    </div>
                    <div className='flex flex-row text-lg'>
                        <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                        {0} Sui
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Total Staked
                    </div>
                    <div className="text-2xl">
                        ${0}
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
                        {0}
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Avg. APY
                    </div>
                    <div className="text-2xl">
                        {avgApy.toFixed(2)}%
                    </div>
                </div>
            </div>
            <button className=" py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                Next
                <ArrowRightIcon className="h-5 w-5 ml-2" />
            </button>
        </div>
    )
}

export default SuiToStakedSui