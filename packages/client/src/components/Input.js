


export const AmountInput = () => {
    return (
        <div class="flex mb-2">
            <div class="relative w-full">
                <input type="number" value={0} id="large-input" class="block w-full p-4 border rounded-l-lg sm:text-md  bg-gray-700 border-gray-600 placeholder-gray-400 text-white focus:outline-none focus:border-blue-500" />
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
    )
}

