import BasePanel from "./Base"

const InfoRow = ({ name, value }) => {
    return (
        <div class="grid grid-cols-2 gap-2 mt-1 mb-2">
            <div class="text-gray-300 text-sm font-medium">
                {name}
            </div>
            <div className=" font-medium text-sm ml-auto mr-3">
                {value}
            </div>
        </div>
    )
}

const MintPT = ({ visible, close, selected, onAmountChange, amount }) => {

    return (
        <BasePanel
            visible={visible}
            close={close}
        >
            <h2 class="text-2xl mb-2 mt-2 font-bold">
                Mint Principal Tokens
            </h2>
            <hr class="my-12 h-0.5 border-t-0 bg-neutral-100 mt-2 mb-2 opacity-50" />
            <p class="  text-sm text-gray-300  mt-2">
                Deposit your Staked SUI to convert it into Principal Tokens (PT), which locks in a fixed yield until the end of the period.
            </p>
            <div className="border rounded-lg mt-4   p-4 border-gray-400">
                <div className="flex items-center">
                    <img src={"./sui-sui-logo.svg"} alt="" className="h-6 w-6  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                    <span className="ml-1 block text-white font-medium text-right">
                        Staked SUI
                    </span>
                    <div class="ml-auto text-gray-300 text-sm font-medium">
                        {selected.name}
                    </div>
                </div>
            </div>
            <div className="border rounded-lg mt-4 p-4 border-gray-400">
                <div className="block leading-6 mb-2 text-gray-300">Amount to convert into PTs</div>
                <div class="flex mb-2">
                    <div class="relative w-full">
                        <input type="number" value={amount} onChange={onAmountChange} id="large-input" class="block w-full p-4 border rounded-l-lg sm:text-md  bg-gray-700 border-gray-600 placeholder-gray-400 text-white focus:outline-none focus:border-blue-500" />
                    </div>
                    <div class="flex-shrink-0 cursor-default z-10 inline-flex items-center py-2.5 px-4 text-sm font-medium text-center border rounded-r-lg border-gray-700 text-white  focus:ring-4 focus:outline-none   bg-gray-600   focus:ring-gray-800" type="button">
                        <div className='flex flex-row'>
                            <img src={"./sui-sui-logo.svg"} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                            Staked SUI
                        </div>
                        <svg class="w-2.5 h-2.5 ml-2.5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 10 6">
                            <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 4 4 4-4" />
                        </svg>
                    </div>
                </div>
            </div>
            <div className="border rounded-lg mt-4 p-4 border-gray-400">
                <div class="mt-2 flex flex-row">
                    <div class="text-gray-300 text-sm font-medium">You will receive at least</div>
                    <span class="ml-auto bg-blue-100 text-blue-800 text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-blue-900 dark:text-blue-300">
                        1 Staked SUI = 1.0234 PT
                    </span>
                </div>

                <hr class="h-px my-4 border-0  bg-gray-600" />
                <div class="grid grid-cols-2 gap-2 mt-2 mb-2">
                    <div>
                        <h2 className="text-3xl font-medium">
                            PT
                        </h2>
                        <div class="text-gray-300 text-sm font-medium">
                            SUI at Maturity
                        </div>
                    </div>
                    <div className="flex">
                        <div className="text-3xl font-medium mx-auto mt-3 mb-auto mr-2">
                            1.2033
                        </div>
                    </div>
                </div>
                <InfoRow
                    name={"Est. Profit at Maturity"}
                    value={"0.1123"}
                />
                <InfoRow
                    name={"Price impact"}
                    value={"0.01%"}
                />
                <InfoRow
                    name={"Fixed APR"}
                    value={"4.35%"}
                />
                <hr class="h-px my-4 border-0 bg-gray-600" />
                <button onClick={() => alert(true)} className=" py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700">
                    Mint
                </button>
            </div>


        </BasePanel>
    )
}

export default MintPT