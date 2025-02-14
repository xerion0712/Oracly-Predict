/* eslint-disable max-len */
import { useContext, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { ChevronDown, ChevronRight, Menu, User } from 'react-feather';
import { LegatoContext } from '@/hooks/useLegato';
import { getCurrentUser, signIn } from 'aws-amplify/auth';
import { shortAddress } from '@/helpers';


const Header = (props: any) => {

    const [user, setUser] = useState<any>(undefined)
    const { loadDefault, currentNetwork, loadProfile } = useContext(LegatoContext)

    const router = useRouter();

    const [showMenu, setShowMenu] = useState(false);

    const toggleMenu = () => {
        if (window.innerWidth < 1024) {
            setShowMenu(!showMenu);
        } else {
            setShowMenu(false);
        }
    };

    useEffect(() => {
        loadDefault()
    }, [])

    useEffect(() => {
        (async () => {
            try {
                const { username, userId, signInDetails } = await getCurrentUser();
                setUser({
                    username,
                    userId,
                    ...signInDetails
                })
            } catch (e) {
                setUser(undefined)
            }
        })()
    }, [])

    useEffect(() => { 
        if (user && user.loginId) {
            loadProfile(user.loginId)
        }
    }, [user])

    return (
        <header className={`sticky top-0 z-50 ${router.pathname === "/" && "dark:bg-gradient-to-r dark:from-[#B476E5]/10 dark:to-[#47BDFF]/10"} duration-300 ${props.className}`}>
            <div className="container">
                <div className="flex items-center justify-between py-5 lg:py-0">
                    <Link href="/">
                        <img src="/assets/images/logo-legato-3.png" alt="legato" className=" w-[200px] sm:w-[240px] " />
                    </Link>
                    <div className="flex items-center sm:w-full">
                        <div onClick={() => toggleMenu()} className={`overlay fixed inset-0 z-[51] bg-black/60 lg:hidden ${showMenu ? '' : 'hidden'}`}></div>
                        <div className={`menus  ${showMenu ? 'overflow-y-auto ltr:!right-0 rtl:!left-0' : 'hidden lg:flex'}`}>
                            <div className="border-b border-gray/10 ltr:text-right rtl:text-left lg:hidden">
                                <button onClick={() => toggleMenu()} type="button" className="p-4">
                                    <svg
                                        xmlns="http://www.w3.org/2000/svg"
                                        fill="none"
                                        viewBox="0 0 24 24"
                                        strokeWidth="1.5"
                                        stroke="currentColor"
                                        className="h-6 w-6 text-black dark:text-white"
                                    >
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                                    </svg>
                                </button>
                            </div>
                            <ul onClick={() => toggleMenu()} className=' flex justify-between max-w-[300px] w-full mx-auto '>
                                <li className=' '>
                                    <Link href="/" className={router.pathname === '/' ? 'active' : ''}>
                                        Home
                                    </Link>
                                </li>
                                <li>
                                    <Link href={`/markets/${currentNetwork}`} className={router.pathname === '/markets' || router.pathname.includes('/markets') ? 'active' : ''}>
                                        Explore
                                    </Link>
                                </li>
                                <li>
                                    <Link href={`/vault/${currentNetwork}`} className={router.pathname === '/vault' || router.pathname.includes('vault') ? 'active' : ''}>
                                        Vault
                                    </Link>
                                </li> 
                            </ul>
                            <div className='flex flex-row ml-auto'>

                                <Link href="/auth/profile" className="m-auto">

                                    {!user && (
                                        <button type="button" className="btn rounded-lg  bg-white py-3.5 w-[120px] hover:text-black hover:bg-white ">
                                            sign in
                                        </button>
                                    )}

                                    {user && (
                                        <div className='text-white hover:text-secondary'>
                                            {shortAddress(user.loginId, 6, -10)}
                                        </div>
                                    )}

                                </Link>
                                {/* <button type="button" className="btn ml-0 gradient_anim_btn text-sm sm:text-base flex  px-6 py-3 sm:py-4 sm:px-8 flex-row ">
                                            <div className='my-auto'>
                                                Get Started{` `}
                                            </div>
                                            <ArrowRight size={18} className='mt-[3px] ml-1' />
                                        </button> */}
                            </div>
                        </div>
                        {/* <ul className="flex items-center gap-5  pr-5  lg:pl-5lg:pr-0 ">
                            <li>
                                <button type="button" className="btn mx-auto bg-white py-3.5  hover:text-black hover:bg-white ">
                                    Connect
                                </button>
                            </li> 
                        </ul> */}
                        <button
                            type="button"
                            className="flex h-10 w-10 items-center justify-center rounded-full bg-white lg:hidden"
                            onClick={() => toggleMenu()}
                        >
                            <Menu />
                        </button>
                    </div>
                </div>
            </div>
        </header>
    )
}

export default Header