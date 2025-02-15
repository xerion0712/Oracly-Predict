import { useState } from "react"
import { ChevronDown } from "react-feather"

import SelectNetwork from "../../../modals/selectNetwork"

const NetworkSwitcher = ({ network, hrefs, pageName, title1, title2, info }: any) => {

    const [modal, setModal] = useState(false)

    return (
        <>
            <SelectNetwork
                visible={modal}
                close={() => setModal(false)}
                hrefs={hrefs}
            />

            <div className="heading mb-0 text-center  lg:text-left ">
                <h6 className="inline-block bg-secondary/10 px-2.5  py-2 !text-secondary">{pageName}</h6>
                <h4 className="!font-black uppercase">
                    {title1} <span className="text-secondary">{title2}</span>
                </h4>
            </div>
            <p className="mt-2.5 text-center text-sm sm:text-base lg:text-lg font-medium  lg:text-left ">
                {info}
            </p>

            <div className="my-4 mt-5">

                <div className="grid grid-cols-1 sm:grid-cols-3">
                    <div className="col-span-1">
                        <div onClick={() => setModal(true)} className="w-full cursor-pointer flex flex-row rounded-lg bg-[#141F32]  text-lg border border-gray/30   p-2   text-white  ">
                            <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={ network === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"   } alt="" />
                            <div className="mt-auto mb-auto ml-2">
                                {network.toUpperCase()}
                            </div>
                            <div className="ml-auto mt-auto mb-auto ">
                                <ChevronDown />
                            </div>
                        </div>
                    </div>
                </div>
            </div>

        </>
    )
}

export default NetworkSwitcher