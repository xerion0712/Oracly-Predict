import { useState } from "react"
import { ArrowRightIcon } from "@heroicons/react/20/solid"
import Selector from "../Selector"
import Vault from "../../data/vault.json"
import MessageModal from "@/modals/Message"


const StakedSuiToPT = () => {

    const [selected, setSelected] = useState(Vault[0])
    const [modal, setModal ] = useState(false)


    return (
        <div>

            <MessageModal
                visible={modal}
                close={() => setModal(false)}
                info="The selected vault has already expired."
            />

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
                        0
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        Total Staked
                    </div>
                    <div className="text-2xl"> 
                        $0
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
                        0
                    </div>
                </div>
                <div className='text-right'>
                    <div className="block text-sm font-medium leading-6 text-gray-300">
                        APY
                    </div>
                    <div className="text-2xl">
                        4%
                    </div>
                </div>
            </div>
            <button onClick={() => setModal(true)} className=" py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                Next
                <ArrowRightIcon className="h-5 w-5 ml-2" />
            </button>
        </div>
    )
}

export default StakedSuiToPT