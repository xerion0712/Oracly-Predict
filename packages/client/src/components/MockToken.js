import useLegato from "@/hooks/useLegato"
import { useCallback, useEffect, useState } from "react"
import Spinner from "./Spinner"
import { useWallet } from "@suiet/wallet-kit"


const MockToken = () => {

    const { faucet, getMockBalance } = useLegato()

    const wallet = useWallet()

    const { account } = wallet

    const [loading, setLoading] = useState(false)
    const [balance, setBalance] = useState("0")
    const [tick, setTick] = useState(0)

    const onMint = useCallback(async () => {
        setLoading(true)
        try {
            await faucet()
            setTick(tick + 1)
        } catch (e) {
            console.log(e)
        }
        setLoading(false)
    }, [faucet, tick])

    useEffect(() => {
        account && account.address && getMockBalance(account.address).then(setBalance)
    }, [account, tick])

    return (
        <div className="max-w-3xl mx-auto mt-8">
            <p class="text-neutral-400 text-sm p-5 pb-3 text-center">
                Looking for mock tokens to test?
            </p>
            <div class=" border border-gray-400 text-gray-100 px-4 py-3 ml-7 mr-7 rounded-lg relative">
                <div class="grid grid-cols-12 gap-3 px-2 mt-4 mb-4 ">
                    <div class="col-span-3 flex flex-row  font-medium">
                        <img class="h-5 w-5 rounded-full mt-auto mb-auto mr-1" src="./sui-sui-logo.svg" alt="" />
                        <div class="mt-auto mb-auto">
                            Staked SUI
                        </div>
                    </div>
                    <div class="col-span-3 flex flex-col text-md">
                        <div class="mt-auto mb-auto">
                            Balance : {balance}
                        </div>
                    </div>
                    <div class="col-span-3 flex flex-col text-md">
                        <div class="mt-auto mb-auto">
                            APR : 4.35%
                        </div>
                    </div>
                    <div class="col-span-3 flex flex-col text-xl font-bold">

                        <button disabled={loading} onClick={onMint} className="p-2 pl-10 pr-10 text-sm border flex flex-row rounded mx-auto mr-2">
                            {loading && <Spinner />}
                            Mint
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default MockToken