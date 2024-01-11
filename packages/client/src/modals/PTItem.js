import BaseModal from "./Base"
import { parseAmount, shortAddress } from "@/helpers"
import { LegatoContext } from "@/hooks/useLegato"
import BigNumber from "bignumber.js"
import { useCallback, useContext, useState } from "react"
import Spinner from "@/components/Spinner"

const PTItemModal = ({ visible, close, item, isTestnet }) => {

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
                            value={`${parsedAmount} PT`}
                        />
                    </div>

                    <div className="py-1">
                        <div class="border-b-2 border-gray-700">
                            <ul class="flex flex-wrap -mb-px text-sm  text-center text-gray-300">
                                <li class="me-2">
                                    <div onClick={() => setTab(1)} class={`cursor-pointer inline-flex items-center justify-center p-4 py-2.5 border-b-2 rounded-t-lg  group ${tab === 1 ? "text-white border-blue-700 active" : "border-transparent hover:border-blue-700 "} `}>
                                        Redeem
                                    </div>
                                </li>
                            </ul>
                        </div>
                    </div>

                    {tab === 1 && <RedeemPanel item={item} close={close} />}

                </div>
            )}
        </BaseModal>
    )

}

const RedeemPanel = ({ item, close }) => {

    const [errorMessage, setErrorMessage] = useState()
    const [loading, setLoading] = useState(false)
    const { redeem } = useContext(LegatoContext)

    const onRedeem = useCallback(async () => {

        setLoading(true)
        setErrorMessage()

        try {

            const { vault, objectId } = item

            await redeem(vault, objectId)

            close()

        } catch (e) {
            console.log("error:", e)
            setErrorMessage(`${e.message} ${e.message.includes("WALLET.SIGN_TX_ERROR") ? " - Possibly too low rewards" : ""} `)
        }

        setLoading(false)

    }, [])

    return (
        <>
            <button disabled={loading} onClick={onRedeem} className={`${(loading) && "opacity-40"} mt-4 py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700`}>
                {loading && <Spinner />}
                Redeem
            </button>
            {errorMessage && (
                <div className="text-xs font-medium p-2 text-center text-yellow-300">
                    {errorMessage}
                </div>
            )}
        </>
    )
}

export const InfoRow = ({ name, value, link }) => {

    return (
        <div class="flex flex-row gap-2 mt-1 mb-2">
            <div class="text-gray-300 text-sm font-medium">
                {name}
            </div>
            <div className="flex-grow text-right font-medium text-sm  mr-3">
                {!link && <>{value}</>}
                {link && <a href={link} className="hover:underline" target="_blank">{value}</a>}
            </div>
        </div>
    )
}


export default PTItemModal