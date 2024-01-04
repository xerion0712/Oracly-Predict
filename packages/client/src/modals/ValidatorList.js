import { useContext } from "react"
import BaseModal from "./Base"
import { LegatoContext } from "@/hooks/useLegato"
import { TrendingUp, Lock } from "react-feather"

const ValidatorList = ({ visible, close, selected, select, isTestnet, validators }) => {

    return (
        <BaseModal
            title={`All Validator (${validators.length})`}
            visible={visible}
            close={close}
            maxWidth="max-w-4xl"
        >
            Choose the validator where you want to stake your SUI:

            <div className="grid grid-cols-5 gap-2 max-h-[350px] mt-4 mb-2 overflow-y-auto">
                {validators.map((item, index) => {

                    const imageUrl = item.imageUrl || "/sui-sui-logo.svg"
                    const isActive = selected.name === item.name ? true : false


                    return <div key={index} onClick={() => select(item.index)} className={`${isActive && "bg-gray-700"}  border-2 border-gray-700 p-2 rounded-md hover:border-blue-700 flex-1  hover:cursor-pointer flex`}>
                        <div class="my-auto">
                            <div class="w-1/2 mx-auto mt-1">
                                <img
                                    class="h-full w-full object-contain object-center rounded-full"
                                    src={imageUrl}
                                    alt=""
                                />
                            </div>
                            <div className="p-2 px-1 pb-0 text-center">
                                <h3 class="text-sm font-medium leading-4 text-white">{item.name}</h3>
                                <div className="grid grid-cols-2 py-2 mt-auto grow-1 ">
                                    <div className="col-span-1">
                                        <div className="my-auto ml-auto flex flex-row text-gray-400">
                                            <Lock
                                                size={16}
                                            />
                                            <span class="text-sm tracking-wide ml-1 leading-4 text-gray-400">
                                                {item.value}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="col-span-1 flex">
                                        <div className="my-auto ml-auto flex flex-row">
                                            <TrendingUp
                                                size={16}
                                            />
                                            <h3 class="text-sm ml-1 text-white leading-4">
                                                {item.apy.toFixed(2)}%</h3>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                    </div>
                })}
            </div>
        </BaseModal>
    )
}

export default ValidatorList