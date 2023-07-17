import useLegato from "@/hooks/useLegato"
import { useCallback, useEffect, useState } from "react"
import Spinner from "./Spinner"
import { useWallet } from "@suiet/wallet-kit"


const MockToken = () => {

    const { faucet, getMockBalance } = useLegato()

    const wallet = useWallet()

    const { account } = wallet

    const [loading, setLoading] = useState(false)
    const [ balance, setBalance ] = useState("0")
    const [ tick, setTick ] = useState(0)

    const onMint = useCallback(async () => {
          setLoading(true)
        try { 
            await faucet()
            setTick(tick+1)
        } catch (e) {
            console.log(e)
        }
        setLoading(false)
    }, [faucet, tick])

    useEffect(() => {
        account && account.address && getMockBalance(account.address).then(setBalance)
    },[account, tick])

    return (
        <div class=" border border-gray-400 text-gray-100 px-4 py-3 ml-7 mr-7 rounded relative">
            <div class="grid grid-cols-10 gap-3 px-2 mt-4 mb-4 ">
                <div class="col-span-3 flex flex-col text-2xl font-bold">
                    Staked Sui
                </div>
                <div class="col-span-2 flex flex-col text-md">
                    <div class="mt-auto mb-auto">
                        Balance : {balance}
                    </div>
                </div>
                <div class="col-span-2 flex flex-col text-md">
                    <div class="mt-auto mb-auto">
                        APR : 4%
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
    )
}

export default MockToken