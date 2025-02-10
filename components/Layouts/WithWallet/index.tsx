import { ReactNode, useEffect, useState } from 'react';
import { useRouter } from "next/router"
import { ChevronRight, ChevronDown } from 'react-feather';
import Link from 'next/link';
import WalletSui from './WalletSui';
import WalletAptos from './WalletAptos';
import SelectNetwork from "@/modals/selectNetwork";

interface IWithWalletPanel {
    children: ReactNode
    pageName: string
    title1: string
    title2: string
    info: string
    href: string
    showWallet?: boolean
}

const WithWalletPanel = ({ children, pageName, title1, title2, info, href, showWallet = true }: IWithWalletPanel) => {

    const [modal, setModal] = useState(false)

    const router = useRouter()

    let network = ""

    if (router.pathname.includes("sui")) {
        network = "sui"
    } else if (router.pathname.includes("aptos")) {
        network = "aptos"
    }

    return (
        <>

            <SelectNetwork
                visible={modal}
                close={() => setModal(false)}
                hrefs={[`${href}/sui`, `${href}/aptos`]}
            />

            <div className="w-full px-1.5 grid grid-cols-1 lg:grid-cols-2">
                <div className='col-span-1 '>

                    <div className="heading mb-0 text-center  lg:text-left ">
                        <h6 className="inline-block bg-secondary/10 px-2.5  py-2 !text-secondary">{pageName}</h6>
                        <h4 className="!font-black uppercase">
                            {title1} <span className="text-secondary">{title2}</span>
                        </h4>
                    </div>
                    <p className="mt-2.5 text-center text-sm sm:text-base lg:text-lg font-medium  lg:text-left ">
                        {info}
                    </p>

                    <div className="mb-2 mt-4">

                        <div className="grid grid-cols-1 sm:grid-cols-5">
                            <div className="col-span-2">
                                <div onClick={() => setModal(true)} className="w-full cursor-pointer  flex flex-row rounded-lg bg-[#141F32]  text-lg border border-gray/30   p-2   text-white  ">
                                    <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={network === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"} alt="" />
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

                    {network === "sui" && <WalletSui showWallet={showWallet} />}
                    {network === "aptos" && <WalletAptos showWallet={showWallet} />}

                    {router.pathname.includes("vault") && (
                        <div className="py-2 font-normal text-base  text-secondary ">
                            No login is required to stake or unstake your assets on the vault
                        </div>
                    )}

                </div>
                <div className='col-span-1  '>
                    {children}
                </div>
            </div>
        </>
    )
}

export default WithWalletPanel