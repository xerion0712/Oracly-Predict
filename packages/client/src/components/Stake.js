import useLegato from "@/hooks/useLegato"
import { slugify } from "../helpers"
import { useWallet } from "@suiet/wallet-kit"
import { useState, useCallback, useEffect } from "react"
import Spinner from "./Spinner"

const Card = ({ matured = false, title, date, total, loading, onStake, balance }) => {
    return (
        <div className="col-span-1 border-2 p-3">
            <div className="text-sm">
                {matured === true ? <span class="bg-yellow-100 text-yellow-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-yellow-900 dark:text-yellow-300">Matured</span> : <span class="bg-green-100 text-green-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-green-900 dark:text-green-300">Available</span>}

            </div>
            <h2 class="text-xl mb-2 mt-2 font-bold">
                {title}
            </h2>
            <div class="grid grid-cols-2 gap-2 ml-4 mr-4 mt-2">
                <div>
                    <div className="text-sm">
                        Maturity Date
                    </div>
                    <div>
                        {date}
                    </div>
                </div>
                {/* <div>
                    <div className="text-sm">
                        Total Locked
                    </div>
                    <div>
                        {total} sSUI
                    </div>
                </div> */}
                <div>
                    <div className="text-sm">
                        Balance
                    </div>
                    <div>
                    {Number(balance).toFixed(2)}
                    </div>
                </div> 
            </div>
            <div className="flex flex-col p-4 mt-2">
                {matured === true && <button className="p-2 pl-10 pr-10 text-sm border flex flex-row w-full justify-center">
                    Redeem
                </button>}
                {matured === false && <button disabled={loading} onClick={onStake} className="p-2 pl-10 pr-10 text-sm border flex flex-row w-full justify-center">
                    {loading && <Spinner />}
                    Stake
                </button>}
                {/* <p className="mt-4 text-sm">Balance : {balance} {slugify(title)}</p> */}
            </div>
        </div>
    )
}

const Stake = () => {

    const { getAllCoins, getAllVaultTokens, stake } = useLegato()

    const wallet = useWallet()

    const { account } = wallet

    const [loading, setLoading] = useState(false)
    const [coins, setCoins] = useState([])
    const [ balance, setBalance] = useState(0)
    const [tick, setTick] = useState(0)

    useEffect(() => {
        account && account.address && getAllCoins(account.address).then(setCoins)
        account && account.address && getAllVaultTokens(account.address).then(
            (items) => { 
                setBalance(items.length)
            }
        )
    }, [account, tick])

    const onStake = useCallback(async () => {

        setLoading(true)

        try {

            if (coins.length === 0) {
                alert("No available coins!") 
            } else {
                await stake(coins[0])
                setTick(tick + 1)
            }
           
        } catch (e) {
            console.log(e)
        }

        setLoading(false)

    }, [tick, stake, coins])

    return (
        <div>
            <div className="text-center max-w-2xl ml-auto mr-auto">
                <h2 class="text-3xl mb-2 font-bold">
                    Staked SUI
                </h2>
                <p class="text-neutral-500">
                    Lock your staked SUI and sell them at a future price inclusive of the yield or hold and redeem them after the maturity date
                </p>
            </div>
            <div className="text-center mt-6 ml-auto mr-auto">
                <div class="grid grid-cols-3 gap-2">
                    <Card
                        matured={true}
                        title="Staked SUI 6-23"
                        date="30/6/23"
                        total="4"
                        balance={0}
                    />
                    <Card
                        matured={false}
                        title="Staked SUI 12-23"
                        date="31/12/23"
                        total={balance.toLocaleString()}
                        loading={loading}
                        onStake={onStake}
                        balance={balance.toLocaleString()}
                    />
                </div>
            </div>
        </div>
    )
}

export default Stake