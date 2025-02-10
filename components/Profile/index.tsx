
import { signOut } from "aws-amplify/auth"
import { useRouter } from 'next/router'
import { useState, useEffect, useContext } from "react"
import { getCurrentUser, signIn } from 'aws-amplify/auth';
import useDatabase from "@/hooks/useDatabase";
import { BadgePurple } from "../Badge";
import Overview from "./Overview";
import Link from "next/link";
import { LegatoContext } from "@/hooks/useLegato";

enum Menu {
    PROFILE,
    WALLET,
    POSITION,
    MARKET
}

const ProfileContainer = () => {
    
    const [tab, setTab] = useState<Menu>(Menu.PROFILE)

    const router = useRouter()

    const { currentProfile } = useContext(LegatoContext)

    const handleSignOut = async () => {
        try {
            await signOut()
            router.push("/")
        } catch (error) {
            console.log('error signing out: ', error);
        }
    }

    return (
        <div>
            <div className="w-full px-1.5 grid grid-cols-1 lg:grid-cols-3">

                <div className='col-span-1 grid grid-cols-5 '>
                    <div className='col-span-4 flex flex-col'>
                        <div onClick={() => setTab(Menu.PROFILE)} className={`py-2.5 px-2 cursor-pointer border-0 border-b-2 border-gray/20 ${tab === Menu.PROFILE && "font-semibold  text-secondary"}`}>
                            Overview
                        </div>
                        <div onClick={() => setTab(Menu.WALLET)} className={`py-2.5 px-2 cursor-pointer border-0 border-b-2 border-gray/20  ${tab === Menu.WALLET && "font-semibold  text-secondary"}`}>
                            Connected Wallets
                        </div>
                        <Link href="/auth/my-positions">
                            <div className={`py-2.5 px-2 cursor-pointer border-0 border-b-2 border-gray/20  ${tab === Menu.POSITION && "font-semibold  text-secondary"}`}>
                                My Positions
                            </div>
                        </Link>
                        <Link href="/auth/my-markets">
                            <div className={`py-2.5 px-2 cursor-pointer  ${tab === Menu.MARKET && "font-semibold  text-secondary"}`}>
                                My Markets
                            </div>
                        </Link>
                        <div className="py-2 pt-2.5">
                            <button onClick={handleSignOut} type="button" className="btn mx-auto bg-white py-3.5 w-full rounded-lg my-2">
                                Sign out
                            </button>
                        </div>
                    </div>

                </div>
                <div className='col-span-2 p-4'>
                    {tab === Menu.PROFILE && (
                        <Overview profile={currentProfile} />
                    )}
                    {tab === Menu.WALLET && (
                        <div className="bg-black/90 rounded-lg p-6">
                            <h2 className="text-xl font-semibold text-white mb-4">Connected Wallets</h2>
                            {/* Wallet content will be implemented later */}
                        </div>
                    )}
                    {tab === Menu.POSITION && (
                        <div className="bg-black/90 rounded-lg p-6">
                            <h2 className="text-xl font-semibold text-white mb-4">Your Positions</h2>
                            {/* Positions content will be implemented later */}
                        </div>
                    )}
                </div>

            </div>

        </div>
    )
}

export default ProfileContainer