
import Image from 'next/image'
import { useCallback, useEffect, useState, Fragment } from 'react'
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

import { Listbox, Transition } from '@headlessui/react'
import { CheckIcon, ChevronUpDownIcon, ChevronDownIcon, ArrowRightIcon } from "@heroicons/react/20/solid"
import { shortAddress } from '@/helpers'


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
                        <div className='flex flex-row'>
                            {wallet && wallet.connected ? (
                                <div className='pt-1'>

                                    <Listbox >
                                        {({ open }) => (
                                            <>
                                                <div className="relative ">
                                                    <Listbox.Button className=" relative hover:cursor-pointer w-full cursor-default rounded-md  py-2 px-4 pr-8 text-left font-medium shadow-sm sm:text-sm sm:leading-6  bg-gray-700 placeholder-gray-400 text-white   ">
                                                        <span className="flex items-center">
                                                            <span className="mr-3 block truncate">
                                                                {shortAddress(wallet.account.address)}
                                                            </span>

                                                        </span>
                                                        <span className="pointer-events-none absolute inset-y-0 right-0 ml-3 flex items-center pr-2">
                                                            <ChevronDownIcon className="h-5 w-5 text-gray-400" aria-hidden="true" />
                                                        </span>
                                                    </Listbox.Button>
                                                    <Transition
                                                        show={open}
                                                        as={Fragment}
                                                        leave="transition ease-in duration-100"
                                                        leaveFrom="opacity-100"
                                                        leaveTo="opacity-0"
                                                    >
                                                        <Listbox.Options className="absolute z-10 mt-1 max-h-56 w-full overflow-auto rounded-md bg-gray-700 placeholder-gray-400 text-white py-2 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm">
                                                             
                                                            {/* <div className='mx-4 text-xs text-gray-300'>
                                                                Switch To
                                                            </div>

                                                            {accounts.map((acc, index) => {
                                                                return (
                                                                    <div key={index}>
                                                                        <Listbox.Option
                                                                            // onClick={() => wallet.select(acc)}
                                                                            className="px-4 mt-1 py-1 w-full font-medium overflow-auto"
                                                                        >
                                                                            {shortAddress(acc.address)}
                                                                        </Listbox.Option>
                                                                    </div>
                                                                )
                                                            })

                                                            } */}

                                                            {/* <div className='mx-3 mt-2 mr-8 text-xs border-[1px] border-gray-500 text-gray-500'>
                                                                 
                                                            </div> */}

                                                            <Listbox.Option
                                                                onClick={() => wallet.disconnect()}
                                                                className="px-4 cursor-pointer py-1 w-full font-medium overflow-auto text-center"
                                                            >
                                                                Disconnect
                                                            </Listbox.Option>
                                                        </Listbox.Options>
                                                    </Transition>
                                                </div>
                                            </>
                                        )}
                                    </Listbox>

                                </div>
                            ) :
                                <>
                                    <ConnectButton>
                                        Connect Wallet
                                    </ConnectButton>
                                </>

                            }

                        </div>

                    </div>
                </div>
            </nav>
        </>
    )
}


export default Header