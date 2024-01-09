import BaseModal from "./Base"
import CURRENCY from "../data/currency.json"

const CurrencySelectModal = ({ visible, close, isTestnet, onSelectCurrency }) => {

    const networkName = isTestnet ? "testnet" : "mainnet"
    const currencyList = CURRENCY.filter(item => item.network === networkName)

    return (
        <BaseModal
            title={"Select Currency"}
            visible={visible}
            close={close}
            borderColor="border-gray-700"
            maxWidth="max-w-sm"
        >
            <div className="grid grid-cols-2 gap-2 max-h-[350px] mt-4 mb-2 overflow-y-auto">
                {currencyList.map((item, index) => {

                    return (
                        <div key={index} onClick={() => onSelectCurrency(item)} className={`border-2 border-gray-700 p-2 rounded-md hover:border-blue-700 flex-1  hover:cursor-pointer flex`}>
                            <div className="flex flex-col" >
                                <div class="w-1/3 mx-auto mt-1">
                                    <div class="relative">
                                        <img
                                            class="h-full w-full object-contain object-center rounded-full"
                                            src={item.image}
                                            alt=""
                                        />

                                        { item.isYT && <img src="/yt-badge.png" class="bottom-1 right-7 absolute  w-7 h-4" />}
                                    </div> 
                                </div>
                                <div className="p-2 px-1 pb-0 text-center">
                                    <h3 class="text-sm font-medium leading-4 text-white">{item.name}</h3>
                                </div>
                            </div>
                        </div>
                    )
                })

                }
            </div>
        </BaseModal>
    )
}

export default CurrencySelectModal