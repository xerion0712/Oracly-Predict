
import Overview from "./Overview"
import System from "./System"
import WalletPanel from "./WalletPanel"
import AllOutcomes from "./AllOutcomes"
import Alert from "../../../components/Alert"
import ChatPanel from "./ChatPanel"
import { Tab, TabGroup, TabList, TabPanel, TabPanels } from '@headlessui/react'
import Ranking from "./Ranking"
import FaucetModal from "../../../modals/faucet"
import { useState } from "react"


const MarketDetails = () => {

    const [modal, setModal ] = useState(false)


    return (
        <>

            <FaucetModal
                visible={modal}
                close={() => setModal(false)}
            />

            <div className=" grid grid-cols-1 sm:grid-cols-5 gap-3">

                <div className="col-span-5 mb-2">
                    <Alert>
                        <div className="text-xs sm:text-base">
                            This new version is currently live at Aptos Testnet and uses Mock USDC, which you can get from the <span onClick={() => setModal(true)} className="underline cursor-pointer" >Faucet</span>
                        </div>
                    </Alert>
                </div>

                <div className="col-span-3 flex flex-col ">

                    <Overview />



                    <TabGroup className="mt-2.5 h-full   ">
                        <TabList className="flex gap-3">
                            {["🤖 Chat", "🎯 Available Outcomes", "⚡ My Positions"].map((name) => (
                                <Tab
                                    key={name}
                                    className="rounded-lg cursor-pointer py-2 px-6 text-base  text-white border border-gray/30  focus:outline-none data-[selected]:bg-[#141F32] data-[hover]:bg-[#141F32] data-[selected]:data-[hover]:bg-[#141F32] data-[focus]:outline-1 data-[focus]:outline-white"
                                >
                                    {name}
                                </Tab>
                            ))}
                        </TabList>
                        <div className="h-1" />
                        <TabPanels className="mt-3 h-full min-h-[400px]  ">
                            <TabPanel className="    ">
                                <ChatPanel />
                            </TabPanel>
                            <TabPanel className=" ">
                                BBB
                            </TabPanel>
                            <TabPanel className=" ">
                                CCC
                            </TabPanel>

                        </TabPanels>
                    </TabGroup>
                </div>

                <div className="col-span-2 flex flex-col h-full  ">
 
                    <Ranking />

                </div>


                <div className="col-span-5 ">
                    {/* <div className='p-2 sm:p-4 group grid grid-cols-5 mx-auto py-4 sm:py-6 w-full max-w-3xl cursor-pointer   border-gray/20  mt-[15px] border-[1px] rounded-lg bg-[url(/assets/images/consulting/business-img.png)] bg-cover bg-center bg-no-repeat '>
                        <div className="flex flex-col col-span-4 pl-4">
                            <h2 className="text-left  font-semibold text-white text-2xl mb-1">
                                Want to Create Your <span className="text-secondary">Own Market?</span>
                            </h2>
                            <p className="text-sm sm:text-base text-muted text-left  ">
                                Create your custom market in a few steps with AI assistance and and earn shared fees with Legato
                            </p>
                        </div>
                        <div className="col-span-1 flex pt-4">
                            <div className="text-secondary p-2 uppercase font-semibold text-sm flex flex-row m-auto">
                                <span className="mr-1 hidden sm:block">Create Now </span>
                            </div>
                        </div> 
                    </div> */}

                </div>


            </div>
        </>
    )
}

export default MarketDetails