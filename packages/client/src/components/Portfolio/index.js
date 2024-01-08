import { Fragment, useEffect, useState } from 'react'

import MARKET from "../../data/market.json"
import StakedSuiTable from './StakedSuiTable'
import { useWallet } from '@suiet/wallet-kit'
import { CloudOff } from 'react-feather'
import PTTable from './PTTable'

const Portfolio = () => {

    const [tab, setTab] = useState("ALL")

    const wallet = useWallet()

    const { account, connected } = wallet

    const marketList = Object.keys(MARKET).map((key) => {
        if (tab === MARKET[key]) currentKey = key
        return {
            key,
            active: tab === key,
            ...MARKET[key]
        }
    })

    const isTestnet = connected && account && account.chains && account.chains[0] === "sui:testnet" ? true : false

    return (
        <div class="wrapper pt-10">
            <div class={` bg-gray-900 p-6 w-full flex flex-col mx-auto max-w-4xl border min-h-[225px] border-gray-700 text-white rounded-xl`}>

                <div className='grid grid-cols-9 gap-2'>

                    <div onClick={() => setTab("ALL")} class={`col-span-2 ${tab === "ALL" && "bg-gray-700"} flex gap-3 items-center border-2 border-gray-700  hover:border-blue-700 flex-1 p-2 px-4 mb-2 hover:cursor-pointer rounded-md`}>
                        <div class="relative">
                            <img class="h-8 w-8 rounded-full" src={"./asset-icon.png"} alt="" />
                        </div>
                        <div>
                            <h3 class={`text-md font-medium text-white`}>All</h3>
                        </div>
                    </div>

                    {marketList.map((item, index) => {
                        return (
                            <div key={index} onClick={() => setTab(item.key)} class={`col-span-2 ${item.active && "bg-gray-700"} flex gap-3 items-center border-2 border-gray-700  hover:border-blue-700 flex-1 p-2 px-4 mb-2 hover:cursor-pointer rounded-md`}>
                                <div class="relative">
                                    <img class="h-8 w-8 rounded-full" src={item.img} alt="" />
                                    {item.isPT && <img src="/pt-badge.png" class="bottom-0 right-5 absolute  w-7 h-4  " />}
                                </div>
                                <div>
                                    <h3 class={`text-md font-medium text-white`}>{item.to}</h3>
                                </div>
                            </div>
                        )
                    })}
                </div>

                <div className='py-3'>

                    <div class="relative overflow-x-auto">
                        <table class="w-full text-sm text-left  text-gray-400">
                            <thead class="text-xs  uppercase    border-b    border-gray-700   text-gray-400">
                                <tr>
                                    <th scope="col" class="px-6 py-3">
                                        Stakee name
                                    </th>
                                    <th scope="col" class="px-6 py-3">
                                        Category
                                    </th>
                                    <th scope="col" class="px-6 py-3">
                                        Amount
                                    </th>
                                    <th scope="col" class="px-6 py-3">
                                        Est. Rewards
                                    </th>
                                    <th scope="col" class="px-6 py-3">
                                       
                                    </th>
                                </tr>
                            </thead>
                            <tbody>

                                {(tab === "SUI_TO_STAKED_SUI" || tab === "ALL") && <StakedSuiTable account={account} isTestnet={isTestnet} />}

                                

                            </tbody>
                        </table>
                        {!connected && (
                            <div className=' flex flex-grow pb-4'>
                                <div className='border text-gray-400 text-sm font-medium m-auto rounded-md mt-4 border-gray-700  px-2 py-4 text-center w-full '>
                                    <CloudOff
                                        size={32}
                                        className='ml-auto mr-auto'
                                    />
                                    <div className='p-2 pb-0'>
                                        Connect wallet to continue
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>


                    {/* {connected
                        ?
                        <>
                            {tab === "SUI_TO_STAKED_SUI" && <StakedSuiTable
                                assetKey={tab}
                                account={account}
                                isTestnet={isTestnet}
                            />}
                            {tab === "STAKED_SUI_TO_PT" && <PTTable
                                assetKey={tab}
                            />}
                        </>
                        :
                        <div className='flex flex-grow pb-4'>
                            <div className='border text-gray-300 text-sm font-medium m-auto rounded-md border-gray-300  px-2 py-4 text-center w-full max-w-xs  '>
                                <CloudOff
                                    size={32}
                                    className='ml-auto mr-auto'
                                />
                                <div className='p-2 pb-0'>
                                    Connect wallet to continue
                                </div>
                            </div>
                        </div>
                    } */}
                </div>

            </div>

        </div>
    )
}

// const PortfolioOLD = ({
//     validators
// }) => {

//     const [tab, setTab] = useState("SUI_TO_STAKED_SUI")

//     const wallet = useWallet()

//     const { account, connected } = wallet

//     let currentKey

//     const marketList = Object.keys(MARKET).map((key) => {
//         if (tab === MARKET[key]) currentKey = key
//         return {
//             key,
//             active: tab === key,
//             ...MARKET[key]
//         }
//     })

//     const isTestnet = connected && account && account.chains && account.chains[0] === "sui:testnet" ? true : false

//     return (
//         <div>
//             <div className="max-w-4xl mx-auto">
//                 <div class="wrapper pt-10">
//                     <div class="rounded-xl p-px bg-gradient-to-b  from-blue-800 to-purple-800">
//                         <div class="rounded-[calc(0.8rem-1px)] p-10 pl-5 pr-5 pt-3 bg-gray-900">
//                             <div class="grid grid-cols-7 gap-2 my-4 h-[350px]">
//                                 <div className="col-span-2 py-1 pr-1">

//                                     <div class="text-gray-300 text-sm pb-2 px-1">
//                                         Available To Show (2)
//                                     </div>

//                                     {marketList.map((item, index) => {
//                                         return (
//                                             <div key={index} onClick={() => setTab(item.key)} class={` ${item.active && "bg-gray-700"} flex gap-3 items-center border-2 border-gray-700  hover:border-blue-700 flex-1 p-2 mb-2 hover:cursor-pointer py-3 px-5  rounded-md`}>
//                                                 <div class="relative">
//                                                     <img class="h-8 w-8 rounded-full" src={item.img} alt="" />
//                                                     {item.isPT && <img src="/pt-badge.png" class="bottom-0 right-5 absolute  w-7 h-4  " />}
//                                                 </div>
//                                                 <div>
//                                                     <h3 class={`text-lg font-medium text-white`}>{item.to}</h3>
//                                                 </div>
//                                             </div>
//                                         )
//                                     })}
//                                 </div>
//                                 <div className="col-span-5  p-1 border-l-2 border-gray-700 px-2 md:pl-4 flex">
//                                     {connected
//                                         ?
//                                         <>
//                                             {tab === "SUI_TO_STAKED_SUI" && <StakedSuiTable
//                                                 assetKey={tab}
//                                                 account={account}
//                                                 isTestnet={isTestnet}
//                                             />}
//                                             {tab === "STAKED_SUI_TO_PT" && <PTTable
//                                                 assetKey={tab}
//                                             />}
//                                         </>
//                                         :
//                                         <div className='flex flex-grow pb-4'>
//                                             <div className='border text-gray-300 text-sm font-medium m-auto rounded-md border-gray-300  px-2 py-4 text-center w-full max-w-xs  '>
//                                                 <CloudOff
//                                                     size={32}
//                                                     className='ml-auto mr-auto'
//                                                 />
//                                                 <div className='p-2 pb-0'>
//                                                     Connect wallet to continue
//                                                 </div>
//                                             </div>
//                                         </div>
//                                     }
//                                 </div>
//                             </div>

//                         </div>
//                     </div>
//                 </div>
//             </div>
//         </div>
//     )
// }



export default Portfolio