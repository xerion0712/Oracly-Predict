
import Image from 'next/image'
import { useCallback, useEffect, useState } from 'react'
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

    const { pathname } = router

    return (
        <>
            <nav
                class="grid grid-cols-5 gap-2 ">
                <div className='col-span-2 md:col-span-1 pt-2 pl-2 md:pl-6 md:pt-5'>
                    <Link href="https://legato.finance">
                        <Image
                            src="/legato-logo.png"
                            width={150}
                            height={36}
                            alt="Logo"
                        />
                    </Link>
                </div>
                <div className='col-span-3'>
                    <div class="text-sm md:text-base font-bold text-blue-700 lg:flex-grow">
                        <div class="container flex items-center justify-end md:justify-center p-4 pr-2 md:p-6 mx-auto  capitalize  text-gray-300">
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
                </div>
                <div className='col-span-5 md:col-span-1 flex'>
                    <div className='ml-auto mr-auto pt-0 md:mr-0 md:pr-6 md:pt-3'>
                        <ConnectButton>
                            Connect Wallet
                        </ConnectButton>
                    </div>
                </div>
            </nav>
        </>
    )
}

export default Header