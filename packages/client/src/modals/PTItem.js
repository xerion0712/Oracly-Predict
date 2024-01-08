import BaseModal from "./Base"
import { parseAmount, shortAddress } from "@/helpers"
import BigNumber from "bignumber.js"

const PTItemModal = ({ visible, close, item, isTestnet }) => {

    const amount = item && Number(`${(BigNumber(item.balance)).dividedBy(BigNumber(10 ** 9))}`)
    const parsedAmount = amount && parseAmount(amount)

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
                </div>
            )}
        </BaseModal>
    )

}

const InfoRow = ({ name, value, link }) => {



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