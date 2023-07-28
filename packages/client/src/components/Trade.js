import useLegato from "@/hooks/useLegato"
import { useWallet } from "@suiet/wallet-kit"
import { useState, useCallback, useEffect } from "react"
import Spinner from "./Spinner"
import ListingModal from "./ListingModal"
import { shortAddress } from "@/helpers"


const Order = ({
    owner,
    objectId,
    price,
    buy,
    increaseTick
}) => {

    const [loading, setLoading ] = useState(false)

    const onBuy = useCallback(async () => {

        setLoading(true)

        try {

            await buy(objectId, price)
            increaseTick()

        } catch (e) {
            console.log(e)
        }

        setLoading(false)

    },[objectId, buy, price])

    return (
        <div class=" border mt-4 mb-4 border-gray-400 text-gray-100 px-4 py-3 ml-7 mr-7 rounded relative">
            <div class="grid grid-cols-10 gap-3 px-2 mt-4 mb-4 ">
                <div class="col-span-3 flex flex-col text-md">
                <div class="mt-auto mb-auto">
                        Asset :<br/> Staked SUI 12-23
                    </div>
                </div>
                <div class="col-span-2 flex flex-col text-md">
                    <div class="mt-auto mb-auto">
                        Owner :<br/> {shortAddress(owner)}
                    </div>
                </div>
                <div class="col-span-2 flex flex-col text-md">
                    <div class="mt-auto mb-auto">
                        Price :<br/> {(Number(price) / 1000000).toLocaleString()} SUI
                    </div>
                </div>
                <div class="col-span-3 flex flex-col text-xl font-bold">
                    <button disabled={loading} onClick={onBuy} className="p-2 pl-10 pr-10 text-sm border flex flex-row rounded mt-auto mb-auto justify-center">
                        {loading && <Spinner />}
                        Buy
                    </button>
                </div>
            </div>
        </div>
    )
}

const Trade = () => {

    const { getAllVaultTokens, createOrder, getAllOrders, buy } = useLegato()

    const wallet = useWallet()

    const { account } = wallet

    const [loading, setLoading] = useState(false)
    const [tokens, setTokens] = useState([])
    const [tick, setTick] = useState(0)
    const [modal, setModal] = useState()
    const [price, setPrice] = useState(1)
    const [orders, setOrders] = useState([])

    useEffect(() => {
        account && account.address && getAllVaultTokens(account.address).then(
            (items) => {
                setTokens(items)
            }
        )
    }, [account, tick])

    useEffect(() => {
        getAllOrders().then(setOrders)
    },[tick])

    const increaseTick = useCallback(() => {
        setTick(tick+1)
    },[tick])

    const onCreateOrder = useCallback(async () => {

        if (tokens.length === 0) {
            alert("No any vault token!")
            return
        }

        setLoading(true)

        try {
            await createOrder(tokens[0], Number(price * 1000000))
            setModal(false)
            setTick(tick+1)
        } catch (e) {
            console.log(e)
        }

        setLoading(false)

    }, [tokens, price, createOrder, tick])

    return (
        <div>
            {modal && <ListingModal onCreateOrder={onCreateOrder} closeModal={() => setModal(false)} loading={loading} price={price} setPrice={setPrice} />}

            <div className="text-center max-w-2xl ml-auto mr-auto">
                <h2 class="text-3xl mb-2 font-bold">
                    Trade
                </h2>
                <p class="text-neutral-500">
                    Buy and sell your vault tokens for SUI native tokens with the on-chain orderbook exchange
                </p>
            </div>
            <div className="max-w-4xl mt-6 ml-auto mr-auto">
                <button onClick={() => setModal(true)} className="p-2 pl-8 pr-8 text-sm border flex flex-row rounded mx-auto mr-auto ml-auto">
                    List Item
                </button>
            </div>
            <div className="text-center mt-6 max-w-2xl ml-auto mr-auto">
                <h2 class="text-xl mb-2 font-bold">
                    Active Orders
                </h2>
            </div>
            <div className="max-w-3xl mt-4 ml-auto mr-auto">
                { orders.map((item, index) => {
                    return (
                        <div key={index}>
                            <Order
                                owner={item.owner}
                                price={item.ask}
                                objectId={item['object_id']}
                                buy={buy}
                                increaseTick={increaseTick}
                            />
                        </div>
                    )
                })

                }
            </div>


        </div>
    )
}

export default Trade