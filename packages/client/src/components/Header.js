
import Image from 'next/image'
import { useEffect, useState } from 'react'
import { ExternalLink } from 'react-feather'
import Link from 'next/link'
import { useRouter } from 'next/router'
import {
    ConnectButton,
    useAccountBalance,
    useWallet,
    SuiChainId,
    ErrorCode,
    formatSUI
} from "@suiet/wallet-kit";
import useLegato from '@/hooks/useLegato'


const Header = () => {

    const router = useRouter()
    const wallet = useWallet();

    const { correctedChain } = useLegato()

    const { pathname } = router

    return (
        <>
            <nav
                class="flex items-center justify-between flex-wrap  shadow">
                <div class="flex justify-between lg:w-auto w-full lg:border-b-0 pl-6 pr-2 border-solid border-b-2 border-gray-300 pb-5 lg:pb-0">
                    <div class="flex items-center flex-shrink-0 text-gray-800 mr-16">
                        <Link href="https://legato.finance">
                            <Image
                                src="/legato-logo.png"
                                width={150}
                                height={36}
                                alt="Logo"
                            />
                        </Link>
                    </div>
                </div>
                <div class="menu w-full  flex-grow lg:flex lg:items-center lg:w-auto lg:px-3 px-8">
                    <div class="text-md font-bold text-blue-700 lg:flex-grow">
                        <div class="container flex items-center justify-center p-6 mx-auto text-gray-600 capitalize dark:text-gray-300">
                            <Link className={`border-b-2 ${pathname === ("/") ? "text-gray-200 border-blue-700" : "border-transparent hover:text-gray-200 hover:border-blue-700"} mx-1.5 sm:mx-6`} href="/">
                                Stake
                            </Link>
                            <Link className={`border-b-2 ${pathname.includes("/trade") ? "text-gray-200 border-blue-700" : "border-transparent hover:text-gray-200 hover:border-blue-700"} mx-1.5 sm:mx-6`} href="/trade">
                                Trade
                            </Link>
                            <Link className={`border-b-2 ${pathname.includes("/portfolio") ? "text-gray-200 border-blue-700" : "border-transparent hover:text-gray-200 hover:border-blue-700"} mx-1.5 sm:mx-6`} href="/portfolio">
                                Portfolio
                            </Link>
                        </div>
                    </div>
                    <div class="flex ">
                        <ConnectButton>
                            Connect Wallet
                        </ConnectButton>
                    </div>
                </div>
            </nav>
            {/* <div class="flex h-40 w-full flex-row items-center justify-center">
  <button class="animate-border inline-block rounded-md bg-white bg-gradient-to-r from-red-500 via-purple-500 to-blue-500 bg-[length:400%_400%] p-1">
    <span class="block rounded-md bg-slate-900 px-5 py-3 font-bold text-white"> algochurn.com </span>
  </button>
</div> */}
            {/* {wallet && wallet.connected && !correctedChain && (
                <div class=" border border-gray-400 text-gray-100 px-4 py-3 ml-7 mr-7 rounded relative" role="alert">
                    <strong class="font-bold">Incorrect chain!</strong>{` `}
                    <span class="block sm:inline">Support Testnet only</span>
                </div>
            )} */}
        </>
    )
}


export default Header