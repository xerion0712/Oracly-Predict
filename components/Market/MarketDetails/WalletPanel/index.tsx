import { LegatoContext } from "@/hooks/useLegato"
import { useContext, useEffect, useState } from "react"
import { ChevronDown } from "react-feather"
import SelectNetwork from "@/modals/selectNetwork";
import { Tab, TabGroup, TabList, TabPanel, TabPanels } from '@headlessui/react'
import WalletConnect from "./WalletConnect"
import Claim from "./Claim"
import MyPositions from "./MyPositions"

const WalletPanel = () => {


    return (
        <>

            <TabGroup className="mt-2 h-full min-h-[220px] ">
                <TabList className="flex gap-3">
                    {["🪙 My Wallet", "⚡ My Positions", "💰 Claim Prizes"].map((name) => (
                        <Tab
                            key={name}
                            className="rounded-lg cursor-pointer py-2 px-6 text-base  text-white border border-gray/30  focus:outline-none data-[selected]:bg-[#141F32] data-[hover]:bg-[#141F32] data-[selected]:data-[hover]:bg-[#141F32] data-[focus]:outline-1 data-[focus]:outline-white"
                        >
                            {name}
                        </Tab>
                    ))}
                </TabList>
                <TabPanels className="mt-3 h-full  ">
                    <TabPanel className="    ">
                        <WalletConnect />
                    </TabPanel>
                    <TabPanel className=" ">
                        <MyPositions />
                    </TabPanel>
                    <TabPanel className=" ">
                        <Claim />
                    </TabPanel>

                </TabPanels>


            </TabGroup>
        </>
    )
}

export default WalletPanel