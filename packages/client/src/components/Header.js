
import Image from 'next/image'
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

const Header = ({ landing }) => {

    const router = useRouter()

    const { pathname } = router

    if (landing) {
        return (
            <div class="grid grid-cols-2 gap-3 px-2 mt-4 mb-4 ">
                <div class="col-span-1 flex flex-col">
                    <div class="text-3xl w-full text-white font-bold flex flex-row">
                        <Image
                            src="/logo.png"
                            width={60}
                            height={60}
                            alt="Logo"
                        />
                    </div>
                </div>
                <div class="col-span-1 flex flex-col text-right">
                    <Link href="/stake">
                        <button className="px-8 py-3  m-2 mx-auto text-sm flex flex-row border rounded mr-0">
                            <ExternalLink size={18} className="mr-2" />
                            Launch App
                        </button>
                    </Link>
                </div>
            </div>
        )
    }

    return (
        <div class="grid grid-cols-3 gap-3 px-2 m-4 ">
            <div class="col-span-1 flex flex-col">
                <div class="text-3xl w-full text-white font-bold flex flex-row">
                    <Link href="/">
                        <Image
                            src="/logo.png"
                            width={60}
                            height={60}
                            alt="Logo"
                        />
                    </Link>

                </div>
            </div>
            <div class="col-span-1 flex">
                <div className='mx-auto mt-auto mb-auto text-sm'>
                    <div class="grid grid-cols-3 gap-10 px-2 m-4 ">
                        <Link className={`hover:underline ${pathname.includes("/trade") && "underline"}`} href="/trade">
                            Trade
                        </Link>
                        <Link className={`hover:underline ${pathname.includes("/stake") && "underline"}`} href="/stake">
                            Stake
                        </Link>
                        <Link className={`hover:underline ${pathname.includes("/faucet") && "underline"}`} href="/faucet">
                        Faucet
                        </Link>
                    </div>
                </div>
            </div>
            <div class="col-span-1 flex flex-col text-right">
                <ConnectButton>
                    Connect Wallet
                </ConnectButton>
            </div>
        </div>
    )
}

export default Header