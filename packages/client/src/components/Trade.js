
import { Fragment, useEffect, useState, useCallback } from 'react'
import { PlusIcon, ChevronUpDownIcon } from "@heroicons/react/20/solid"
import { Listbox, Transition } from '@headlessui/react'
import { useWallet } from "@suiet/wallet-kit"
import { VAULT } from "../constants"
import YT from "./YT"
import useLegato from '@/hooks/useLegato'
import Spinner from './Spinner'
import CreateOrder from '@/panels/CreateOrder'

import { shortAddress } from "@/helpers"

function classNames(...classes) {
    return classes.filter(Boolean).join(' ')
}

// const AmountInput = () => {
//     return (
//         <div class="flex mb-2">

//             <div class="w-2/5 flex-shrink-0 cursor-default z-10 inline-flex items-center py-2.5 px-4 text-sm font-medium text-center border   border-gray-700 text-white  focus:ring-4 focus:outline-none   bg-gray-600   focus:ring-gray-800" type="button">
//                 <div className='flex flex-row'>
//                     <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
//                     Staked SUI
//                 </div>
//             </div>
//             <div class="relative w-3/5">
//                 <input type="number" value={0} id="large-input" class="block w-full p-4 border  sm:text-md  bg-gray-700 border-gray-600 placeholder-gray-400 text-white focus:outline-none focus:border-blue-500" />
//             </div>
//         </div>
//     )
// }

export const Sell = ({ tick, setTick }) => {

    const [selected, setSelected] = useState(VAULT[0])

    const { getPTBalance, getAllVaultTokens, createOrder } = useLegato()

    const wallet = useWallet()
    const { account } = wallet

    const [bal, setBal] = useState(0)
    const [coins, setCoins] = useState([])
    const [price, setPrice] = useState(0.095)

    const [discount, setDiscount] = useState(0)
    const [loading, setLoading] = useState(false)
    const [amount, setAmount] = useState(0.1)

    useEffect(() => {
        account && account.address && getPTBalance(account.address).then(
            (output) => {
                setBal(output)
            }
        )
        account && account.address && getAllVaultTokens(account.address).then(setCoins)
    }, [account, tick])

    useEffect(() => {
        if (Number(price) > 0 && amount > 0) {
            const base = Number(price)
            const out = 100 - (base * 100) / Number(amount)
            setDiscount(out)
        }
    }, [price, amount])

    const onCreateOrder = useCallback(async () => {

        setLoading(true)

        try {
            await createOrder(Number(amount), Number(price))
            setTick(tick + 1)
        } catch (e) {
            console.log(e)
        }

        setLoading(false)

    }, [amount, price, createOrder, tick])

    return (
        <div>
            <div className="block mt-4 text-sm font-medium leading-6 text-gray-300">
                <div class="grid grid-cols-2 gap-3">
                    <div class="col-span-1 flex flex-row">
                        Balance
                    </div>
                    <div class="col-span-1 flex flex-row">
                        <span class="ml-auto">
                            {bal.toLocaleString()}{` ${selected.symbol}`}
                        </span>
                    </div>
                </div>
            </div>
            <div className="block mt-4 text-sm font-medium leading-6 text-gray-300">
                PT token to sell
            </div>
            <Listbox value={selected} onChange={setSelected}>
                {({ open }) => (
                    <>
                        <div className="relative mt-2">
                            <Listbox.Button className="relative hover:cursor-pointer w-full cursor-default rounded-md  py-3 pl-3 pr-10 text-left  shadow-sm sm:text-sm sm:leading-6  bg-gray-700 placeholder-gray-400 text-white   ">
                                <span className="flex items-center">
                                    <span className="mr-3 block truncate">{selected.name}</span>
                                    <span className="ml-auto text-white font-medium text-xs text-right">{selected.symbol}</span>
                                    <span className="ml-2 block font-medium w-5 text-right">0</span>
                                </span>
                                <span className="pointer-events-none absolute inset-y-0 right-0 ml-3 flex items-center pr-2">
                                    <ChevronUpDownIcon className="h-5 w-5 text-gray-400" aria-hidden="true" />
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
                                    {VAULT.map((vault) => (
                                        <Listbox.Option
                                            key={vault.id}
                                            className={({ active }) =>
                                                classNames(
                                                    active ? 'bg-blue-600 text-white' : 'text-gray-900',
                                                    'relative cursor-default select-none py-2 pl-3 pr-9'
                                                )
                                            }
                                            value={vault}
                                        >
                                            {({ selected, active }) => (
                                                <>
                                                    <div className="flex items-center">
                                                        <span
                                                            className={classNames(selected ? 'font-semibold' : 'font-normal', 'ml-3 block text-white truncate')}
                                                        >
                                                            {vault.name}
                                                        </span>
                                                        <span className="ml-auto   text-white font-medium text-xs text-right">{vault.symbol}</span>
                                                        <span className="ml-2 block text-white font-medium w-5 text-right">0</span>
                                                    </div>
                                                </>
                                            )}
                                        </Listbox.Option>
                                    ))}
                                </Listbox.Options>
                            </Transition>
                        </div>
                    </>
                )}
            </Listbox>
            <div className="block text-sm font-medium leading-6 mt-2 text-gray-300">
                Amount
            </div>
            <div class="relative mt-1">
                <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
                    <span class=" text-xs text-gray-300" >
                        {selected.symbol}
                    </span>
                </div>
                <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number" id="amount" class="[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none block w-full py-3  text-sm pl-[120px] border rounded-lg      bg-gray-700  border-gray-600  placeholder-gray-400  text-white  focus:ring-blue-500  focus:border-blue-500" />
                <button onClick={() => setAmount(Number(bal))} class="text-white absolute right-1.5 bottom-1.5  font-medium rounded-lg text-sm px-4 py-2  bg-blue-600  hover:bg-blue-700  focus:ring-blue-800">Max</button>
            </div>
            <div class="grid grid-cols-2 gap-3 mt-1   ">
                <div class="col-span-1 flex flex-col">
                    <div className="block text-sm font-medium leading-6 mt-2 text-gray-300">
                        Price
                    </div>
                    <div class="relative mt-1">
                        <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
                            <img class="h-5 w-5 rounded-full" src="./sui-sui-logo.svg" alt="" />
                        </div>
                        <input value={price} onChange={(e) => {
                            let val = e.target.value
                            setPrice(e.target.value)
                        }} type="number" id="price" class=" block w-full py-3  text-sm pl-[45px] border rounded-lg bg-gray-700  border-gray-600  placeholder-gray-400  text-white  focus:ring-blue-500  focus:border-blue-500" />
                    </div>
                </div>
                <div class="col-span-1 flex flex-col">
                    <div className="block text-sm font-medium leading-6 mt-2 text-gray-300">
                        Discount
                    </div>
                    <div class="relative mt-1">
                        <input value={discount.toLocaleString()} type="number" id="price" class="[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none block w-full py-3  text-sm pl-[20px] border rounded-lg bg-gray-700  border-gray-600  placeholder-gray-400  text-white  focus:ring-blue-500  focus:border-blue-500" />
                        <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                            <span class=" text-sm text-gray-300" >
                                %
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <hr class="my-5 h-[1px] border-t-0 bg-neutral-100  opacity-50" />
            <button onClick={onCreateOrder} disabled={loading} className="  py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                {loading && <Spinner />}
                Create Order
                <PlusIcon className="h-5 w-5 ml-2" />
            </button>
        </div>
    )
}


export const Buy = () => {

    const [selected, setSelected] = useState(VAULT[0])

    return (
        <div>
            <div className="block mt-4 text-sm font-medium leading-6 text-gray-300">
                <div class="grid grid-cols-2 gap-3">
                    <div class="col-span-1 flex flex-row">

                        Balance
                    </div>
                    <div class="col-span-1 flex flex-row">
                        <span class="ml-auto">
                            0{` SUI`}
                        </span>
                    </div>
                </div>
                <div className="block mt-4 text-sm font-medium leading-6 text-gray-300">
                    PT token to buy
                </div>
                <Listbox value={selected} onChange={setSelected}>
                    {({ open }) => (
                        <>
                            <div className="relative mt-2">
                                <Listbox.Button className="relative hover:cursor-pointer w-full cursor-default rounded-md  py-3 pl-3 pr-10 text-left  shadow-sm sm:text-sm sm:leading-6  bg-gray-700 placeholder-gray-400 text-white   ">
                                    <span className="flex items-center">
                                        <span className="mr-3 block truncate">{selected.name}</span>
                                        <span className="ml-auto text-white font-medium text-xs text-right">{selected.symbol}</span>
                                        <span className="ml-2 block font-medium w-5 text-right">0</span>
                                    </span>
                                    <span className="pointer-events-none absolute inset-y-0 right-0 ml-3 flex items-center pr-2">
                                        <ChevronUpDownIcon className="h-5 w-5 text-gray-400" aria-hidden="true" />
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
                                        {VAULT.map((vault) => (
                                            <Listbox.Option
                                                key={vault.id}
                                                className={({ active }) =>
                                                    classNames(
                                                        active ? 'bg-blue-600 text-white' : 'text-gray-900',
                                                        'relative cursor-default select-none py-2 pl-3 pr-9'
                                                    )
                                                }
                                                value={vault}
                                            >
                                                {({ selected, active }) => (
                                                    <>
                                                        <div className="flex items-center">
                                                            <span
                                                                className={classNames(selected ? 'font-semibold' : 'font-normal', 'ml-3 block text-white truncate')}
                                                            >
                                                                {vault.name}
                                                            </span>
                                                            <span className="ml-auto   text-white font-medium text-xs text-right">{vault.symbol}</span>
                                                            <span className="ml-2 block text-white font-medium w-5 text-right">0</span>
                                                        </div>
                                                    </>
                                                )}
                                            </Listbox.Option>
                                        ))}
                                    </Listbox.Options>
                                </Transition>
                            </div>
                        </>
                    )}
                </Listbox>
                <div className="block text-sm font-medium leading-6 mt-2 text-gray-300">
                    Amount
                </div>
                <div class="relative mt-1">
                    <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
                        <span class=" text-xs text-gray-300" >
                            {selected.symbol}
                        </span>
                    </div>
                    <input value={0} type="number" id="amount" class="[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none block w-full py-3  text-sm pl-[120px] border rounded-lg      bg-gray-700  border-gray-600  placeholder-gray-400  text-white  focus:ring-blue-500  focus:border-blue-500" />

                </div>
                <div class="grid grid-cols-2 gap-3 mt-1   ">
                    <div class="col-span-1 flex flex-col">
                        <div className="block text-sm font-medium leading-6 mt-2 text-gray-300">
                            Price
                        </div>
                        <div class="relative mt-1">
                            <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
                                <img class="h-5 w-5 rounded-full" src="./sui-sui-logo.svg" alt="" />
                            </div>
                            <input value={0} type="number" id="price" class=" block w-full py-3  text-sm pl-[45px] border rounded-lg bg-gray-700  border-gray-600  placeholder-gray-400  text-white  focus:ring-blue-500  focus:border-blue-500" />
                        </div>
                    </div>
                    <div class="col-span-1 flex flex-col">
                        <div className="block text-sm font-medium leading-6 mt-2 text-gray-300">
                            Discount
                        </div>
                        <div class="relative mt-1">
                            <input value={0} type="number" id="price" class="[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none block w-full py-3  text-sm pl-[20px] border rounded-lg bg-gray-700  border-gray-600  placeholder-gray-400  text-white  focus:ring-blue-500  focus:border-blue-500" />
                            <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                                <span class=" text-sm text-gray-300" >
                                    %
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>


            <hr class="my-5 h-[1px] border-t-0 bg-neutral-100  opacity-50" />
            <button onClick={() => alert("Creating a buy order is not available")} className="  py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                Add Now
            </button>
        </div>
    )
}

const Trade = () => {

    const [tab, setTab] = useState(1)

    return (
        <div>
            <div className="container mx-auto">
                <div class="wrapper">
                    <p class="text-neutral-400 text-sm p-5 text-center">
                        Where you can trade PT and YT with ease
                    </p>
                    <div class="grid grid-cols-10 gap-3 px-2">
                        <div class="col-span-2">

                            <div class="border p-5 m-1 bg-gray-900 border-gray-600">
                                <p class="text-gray-300 text-sm">
                                    Select Market
                                </p>
                                <div class="flex gap-4 items-center flex-1 p-2 mt-1 hover:cursor-pointer ">
                                    <img class="h-12 w-12 rounded-full" src="./sui-sui-logo.svg" alt="" />
                                    <div>
                                        <h3 class="text-2xl font-medium text-white">SUI</h3>
                                        <span class="text-sm tracking-wide text-gray-400">Staked SUI</span>
                                    </div>
                                    <div class="ml-auto mr-0">
                                        <ChevronUpDownIcon className="h-6 w-6 text-gray-300" />
                                    </div>
                                </div>
                                <ul
                                    class="mr-4 flex list-none flex-col flex-wrap pl-0">
                                    <li class="flex-grow  ">
                                        <span onClick={() => setTab(1)} class={`w-full inline-block cursor-pointer p-4 border-b-2 rounded-t-lg ${tab === 1 ? "active text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"} `}>
                                            Principal Token (PT)
                                        </span>
                                    </li>
                                    <li class="flex-grow  ">
                                        <span onClick={() => setTab(2)} class={`w-full inline-block cursor-pointer p-4 border-b-2 rounded-t-lg ${tab === 2 ? "active text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"} `}>
                                            Yield Token (YT)
                                        </span>
                                    </li>
                                </ul>
                            </div>


                        </div>
                        <div class="col-span-8">
                            {tab === 1 && <PT />}
                            {tab === 2 && <YT />}
                        </div>

                    </div>


                </div>
            </div>
        </div>
    )
}



const Order = ({
    item,
    buy,
    increaseTick
}) => {

    const [loading, setLoading] = useState(false)

    const onBuy = useCallback(async () => {

        setLoading(true)

        try {
            const { order_id } = item
            await buy(order_id)
            increaseTick()

        } catch (e) {
            console.log(e)
        }

        setLoading(false)

    }, [item])


    return (
        <div class="text-sm border-b  border-gray-400 text-gray-100   py-3  rounded relative">
            <div class="grid grid-cols-10 gap-3 px-2   ">
                <div class="col-span-4 flex flex-col text-md">
                    <div class="mt-auto mb-auto">
                        0.1 {VAULT[0].symbol}
                    </div>
                </div>
                {/* <div class="col-span-2 flex flex-col text-md">
                    <div class="mt-auto mb-auto ">
                        By : {shortAddress(owner)}
                    </div>
                </div> */}
                <div class="col-span-3 flex flex-col text-md">
                    <div class="mt-auto mb-auto">
                        Price : {(Number(item.price) / 1000000000).toLocaleString()} PT/SUI
                    </div>
                </div>
                <div class="col-span-3 flex flex-col text-xl font-bold">
                    <button disabled={loading} onClick={onBuy} className="p-2 pl-10 pr-10 text-sm border flex flex-row rounded mt-auto mb-auto justify-center">
                        {loading && <Spinner />}
                        Fill
                    </button>
                </div>
            </div>
        </div>
    )
}

const PT_OLD = () => {

    const [tab, setTab] = useState(2)

    const { getPTBalance, getAllVaultTokens, createOrder, buy, getAllOrders } = useLegato()

    const [orders, setOrders] = useState([])

    const [tick, setTick] = useState(0)

    const increaseTick = useCallback(() => {
        setTick(tick + 1)
    }, [tick])

    useEffect(() => {
        getAllOrders().then(setOrders)
    }, [tick])

    return (
        <div class="border p-5 m-1 bg-gray-900 border-gray-600">
            <div class="grid grid-cols-12 gap-3 px-2">
                <div class="col-span-5 flex flex-col border-r pr-3 border-gray-600">
                    <div class="font-medium text-center  border-b  text-gray-400 border-gray-700 mb-4 ">
                        <ul class="flex flex-wrap -mb-px">
                            <li class="  w-1/2">
                                <span onClick={() => setTab(1)} class={`w-full inline-block cursor-pointer p-4 border-b-2 rounded-t-lg ${tab === 1 ? "active text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"} `}>
                                    Buy
                                </span>
                            </li>
                            <li class="  w-1/2">
                                <span onClick={() => setTab(2)} class={`w-full inline-block  cursor-pointer p-4  border-b-2  rounded-t-lg ${tab === 2 ? "active  text-white  border-blue-700" : "border-transparent  hover:border-gray-300  hover:text-gray-300"}`} aria-current="page">
                                    Sell
                                </span>
                            </li>
                        </ul>
                    </div>
                    {tab === 1 && <Buy />}
                    {tab === 2 && <Sell tick={tick} setTick={setTick} />}
                </div>
                <div class="col-span-7 flex flex-col text-md">
                    <p class="text-gray-300 text-sm text-center mt-2 mb-2">
                        Orderbook
                    </p>
                    {orders.map((item, index) => {
                        return (
                            <div key={index}>
                                <Order
                                    owner={item.owner}
                                    price={item.ask}
                                    item={item}
                                    buy={buy}
                                    increaseTick={increaseTick}
                                />
                            </div>
                        )
                    })

                    }
                </div>
            </div>
        </div>
    )
}


const PT = () => {

    const { getAllOrders, buy } = useLegato()

    const [orders, setOrders] = useState([])
    const [tick, setTick] = useState(0)
    const [createOrderPanel, setCreateOrderPanel] = useState(false)


    const increaseTick = useCallback(() => {
        setTick(tick + 1)
    }, [tick])

    useEffect(() => {
        getAllOrders().then(setOrders)
    }, [tick])

    return (
        <div>
            <CreateOrder
                visible={createOrderPanel}
                close={() => setCreateOrderPanel(false)}
                tick={tick}
                setTick={setTick}
            />
            <div class="max-w-xl border p-5 m-1 bg-gray-900 border-gray-600">
                <p class="text-gray-300  text-center mt-2 mb-2">
                    Orderbook
                </p>
                {orders.map((item, index) => {
                    return (
                        <div key={index}>
                            <Order
                                item={item}
                                buy={buy}
                                increaseTick={increaseTick}
                            />
                        </div>
                    )
                })}
                <div class="max-w-xl ml-auto mr-auto">
                    <hr class="my-5 h-[1px] border-t-0 bg-neutral-100  opacity-50" />
                    <button onClick={() => setCreateOrderPanel(true)} className="  py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                        Create Order
                        <PlusIcon className="h-5 w-5 ml-2" />
                    </button>
                </div>
            </div>
        </div>

    )
}

export default Trade