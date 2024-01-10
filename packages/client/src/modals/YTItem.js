import BaseModal from "./Base"
import { useCallback, useContext, useState } from "react"
import { parseAmount, shortAddress } from "@/helpers"
import BigNumber from "bignumber.js"
import { InfoRow } from "./PTItem"
import Spinner from "@/components/Spinner"
import { LegatoContext } from "@/hooks/useLegato"

const YTItemModal = ({ visible, close, item, isTestnet }) => {

    const amount = item && Number(`${(BigNumber(item.balance)).dividedBy(BigNumber(10 ** 9))}`)
    const parsedAmount = amount && parseAmount(amount)

    const [tab, setTab] = useState(1)

    return (
        <BaseModal
            title="Item Details"
            visible={visible}
            close={close}
            borderColor="border-gray-700"
            maxWidth="max-w-lg"
        >
            {item && (
                <div className="flex flex-col">
                    <div className="border rounded-lg mt-4 p-4 border-gray-400">
                        <InfoRow
                            name={"Vault"}
                            value={`${item.vault}`}
                        />
                        <InfoRow
                            name={"Object ID"}
                            value={`${shortAddress(item.objectId, 8, -6)}`}
                            link={`https://suiexplorer.com/object/${item.objectId}${isTestnet ? "?network=testnet" : ""}`}
                        />
                        <InfoRow
                            name={"Amount"}
                            value={`${parsedAmount} YT`}
                        />
                    </div>

                    <div className="py-1">
                        <div class="border-b-2 border-gray-700">
                            <ul class="flex flex-wrap -mb-px text-sm  text-center text-gray-300">
                                <li class="me-2">
                                    <div onClick={() => setTab(1)} class={`cursor-pointer inline-flex items-center justify-center p-4 py-2.5 border-b-2 rounded-t-lg  group ${tab === 1 ? "text-white border-blue-700 active" : "border-transparent hover:border-blue-700 "} `}>
                                        Claim
                                    </div>
                                </li> 
                            </ul>
                        </div>
                    </div>

                    {tab === 1 && <ClaimPanel item={item} close={close} />}

                </div>
            )}

        </BaseModal>
    )
}

const ClaimPanel = ({ item, close }) => {

    const [errorMessage, setErrorMessage] = useState()
    const [loading, setLoading] = useState(false)
    const { claim } = useContext(LegatoContext)

    const onClaim = useCallback(async () => {

        setLoading(true)
        setErrorMessage()

        try {

            const { vault, objectId, digest, version } = item
            await claim(vault, objectId, digest, version)

            close()

        } catch (e) {
            console.log("error:", e) 
            setErrorMessage(`${e.message} ${e.message.includes("WALLET.SIGN_TX_ERROR") ? " - Possibly too low rewards" : "" } `)
        }

        setLoading(false)

    }, [claim])

    return (
        <>
            <button disabled={loading} onClick={onClaim} className={`${(loading) && "opacity-40"} mt-4 py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700`}>
                {loading && <Spinner />}
                Claim
            </button>
            {errorMessage && (
                <div className="text-xs font-medium p-2 text-center text-yellow-300">
                    {errorMessage}
                </div>
            )}
        </>
    )
}

export default YTItemModal