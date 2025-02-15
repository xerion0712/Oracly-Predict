import VaultTable from "./VaultTable"
import VaultList from "../../data/vault.json"
import { useContext, useState } from "react"
import { LegatoContext } from "@/hooks/useLegato"
import { ChevronDown } from "react-feather"
import SelectNetwork from "@/modals/selectNetwork"


const VaultListContainer = () => {

    const [modal, setModal] = useState(false)

    // const { currentNetwork } = useContext(LegatoContext)


    return (
        <>

            {/* <SelectNetwork
                visible={modal}
                close={() => setModal(false)}
            /> */}

            <div className="heading mb-0 text-center lg:text-left ">
                <h6 className="inline-block bg-secondary/10 px-2.5 py-2 !text-secondary">vault</h6>
                <h4 className="!font-black">
                    LIQUIDITY <span className="text-secondary">VAULT</span>
                </h4>
            </div>
            <p className="mt-2.5 text-center text-lg font-medium  lg:text-left ">
                lock-in assets for counter bets and maximize returns with network rewards
            </p>

            <div className="space-y-3 sm:space-y-4 py-4">

                {/* <div className="grid grid-cols-1 sm:grid-cols-5  mb-6">
                    <div className="col-span-1">
                        <div onClick={() => setModal(true)} className="w-full cursor-pointer flex flex-row rounded-lg bg-[#141F32]  text-lg border border-gray/30   p-2   text-white  ">
                            <img className="h-5 w-5 mt-auto mb-auto ml-2 rounded-full" src={currentNetwork === "sui" ? "/assets/images/sui-sui-logo.svg" : "/assets/images/aptos-logo.png"} alt="" />
                            <div className="mt-auto mb-auto ml-2">
                                {currentNetwork.toUpperCase()}
                            </div>
                            <div className="ml-auto mt-auto mb-auto ">
                                <ChevronDown />
                            </div>
                        </div>
                    </div>
                </div> */}

                {/* {currentNetwork === "aptos" && (<VaultTable
                    name={"APTOS"}
                    icon={"/assets/images/aptos-logo.png"}
                    vaultList={VaultList[1].vaults}
                />)

                }

                {currentNetwork === "sui" && (
                    <VaultTable
                        name={"SUI"}
                        icon={"/assets/images/sui-sui-logo.svg"}
                        vaultList={VaultList[0].vaults}
                    />
                )} */}

                <VaultTable
                    name={"APTOS"}
                    icon={"/assets/images/aptos-logo.png"}
                    vaultList={VaultList[1].vaults}
                />
                <VaultTable
                    name={"SUI"}
                    icon={"/assets/images/sui-sui-logo.svg"}
                    vaultList={VaultList[0].vaults}
                />



            </div>

        </>
    )
}

export default VaultListContainer