import { Tab, TabGroup, TabList, TabPanel, TabPanels } from '@headlessui/react'
import WalletBalance from '../WalletBalance'

const Ranking = () => {
    return (
        <div className='p-2 pt-0 flex flex-grow flex-col space-y-3'> 
            {/* <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                    🔥 Top Outcomes
                </h2>

            </div>

            <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                    🏆 Total Staked
                </h2>

            </div> */}

            <div className='flex-grow flex flex-col'>
                <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                    <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                        {/* 📓 Guide */}
                        🔥 Top Outcomes
                    </h2>  
                </div>
                <WalletBalance/>
            </div>


        </div>
    )
}

export default Ranking