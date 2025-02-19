import { Tab, TabGroup, TabList, TabPanel, TabPanels } from '@headlessui/react'
import WalletBalance from '../WalletBalance'

const Ranking = () => {
    return (
        <div className='p-2 pt-0 flex flex-grow flex-col space-y-3'>
            {/* <TabGroup className="mt-2 h-full flex flex-col ">
                <TabList className="flex gap-3">
                    {["Top Outcomes", "Total Staked", "Guide"].map((name) => (
                        <Tab
                            key={name}
                            className="rounded-lg cursor-pointer py-2 px-4 text-base  text-white border border-gray/30  focus:outline-none data-[selected]:bg-[#141F32] data-[hover]:bg-[#141F32] data-[selected]:data-[hover]:bg-[#141F32] data-[focus]:outline-1 data-[focus]:outline-white"
                        >
                            {name}
                        </Tab>
                    ))}
                </TabList>
                <div className="h-[15px]" />
                <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                    <TabPanel className="    ">
                        <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                            🔥 Top Outcomes
                        </h2>
                    </TabPanel>
                    <TabPanel className="    ">
                        <h2 className='text-base my-2 lg:text-lg tracking-tight text-center  font-semibold text-white'>
                            🏆 Total Staked
                        </h2>
                    </TabPanel>
                    <TabPanel className="    ">
                        <h2 className='text-base my-2 lg:text-lg tracking-tight  text-center font-semibold text-white'>
                            📓 Guide
                        </h2>
                    </TabPanel>
                </div>
            </TabGroup> */}
            <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                    🔥 Top Outcomes
                </h2>

            </div>

            <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                    🏆 Total Staked
                </h2>

            </div>

            <div className='flex-grow flex flex-col'>
                <div className={`flex-grow flex flex-col border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg`} >
                    <h2 className='text-base my-2 lg:text-lg text-center tracking-tight   font-semibold text-white'>
                        📓 Guide
                    </h2>  
                </div>
                <WalletBalance/>
            </div>


        </div>
    )
}

export default Ranking