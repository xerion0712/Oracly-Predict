import { useContext } from "react"
import BaseModal from "./base"
import { useRouter } from 'next/router' 
import { LegatoContext } from "@/hooks/useLegato"

const SelectNetwork = ({ visible, close, hrefs }: any) => {

    const { setNetwork } = useContext(LegatoContext)

    const router = useRouter()
 
    // let network = ""

    // if (router.pathname.includes("sui")) {
    //     network = "sui"
    // } else if (router.pathname.includes("aptos")) {
    //     network = "aptos"
    // }

    const handleClick = (href: string) => {
        close()
        router.push(href)
    }

    const savePage = (network: string) => {
        setNetwork(network)
        localStorage.setItem("legatoDefaultNetwork", network)
        close()
    }

    return (
        <BaseModal
            title="Choose Network"
            visible={visible}
            close={close}
            maxWidth={"max-w-lg"}
        >
            <div className="grid grid-cols-2 gap-2.5 mt-4 mb-2">
                <div onClick={() => {
                    savePage("sui")
                    hrefs && handleClick(hrefs[0])
                    // if (network !== "sui") {
                    //     clearBalances()
                    // }
                }} className={`col-span-1 p-2 rounded-lg border bg-black/60  flex-1 border-gray/30 cursor-pointer flex`}>
                    <div className="my-auto">
                        <div className="w-1/3 mx-auto mt-1 p-2">
                            <img
                                className="h-full w-full object-contain object-center rounded-full"
                                src={"/assets/images/sui-sui-logo.svg"}
                                alt=""
                            />
                        </div>
                        <div className="p-2 px-1 pb-0  mb-2  text-center">
                            <h3 className="font-medium text-lg leading-4 text-white">SUI</h3>
                        </div>
                    </div>
                </div>
                <div onClick={() => {
                    savePage("aptos")
                    hrefs && handleClick(hrefs[1])
                    // if (network !== "aptos") {
                    //     clearBalances()
                    // }
                }} className={`col-span-1 p-2 rounded-lg border bg-black/60  flex-1 border-gray/30 cursor-pointer flex`}>
                    <div className="my-auto">
                        <div className="w-1/3 mx-auto mt-1 p-2">
                            <img
                                className="h-full w-full object-contain object-center rounded-full"
                                src={"/assets/images/aptos-logo.png"}
                                alt=""
                            />
                        </div>
                        <div className="p-2 px-1 pb-0 mb-2 text-center">
                            <h3 className="font-medium text-lg leading-4 text-white">APTOS</h3> 
                        </div>
                    </div>
                </div>
            </div>
        </BaseModal>
    )
}

export default SelectNetwork