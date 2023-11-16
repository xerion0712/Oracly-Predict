


export const AmountInput = ({
    value,
    onChange,
    icon,
    tokenName
}) => {
    return (
        <div class="flex mb-2">
            <div class="relative w-full">
                <input value={value} onChange={onChange} type="number" id="large-input" class="block w-full p-4 border rounded-l-lg text-base  bg-gray-700 border-gray-600 placeholder-gray-400 text-white focus:outline-none focus:border-blue-500" />
            </div>
            <div class="flex-shrink-0 cursor-default  z-10 inline-flex items-center py-2.5 px-4 text-base font-medium text-center border rounded-r-lg border-gray-700 text-white  focus:ring-4 focus:outline-none   bg-gray-600   focus:ring-gray-800" type="button">
                <div className='flex flex-row mx-2'>
                    <img src={icon} alt="" className="h-5 w-5  mt-auto mb-auto  mr-2 flex-shrink-0 rounded-full" />
                    {tokenName}
                </div>
            </div>
        </div>
    )
}

export const TextInput = ({
    value,
    onChange,
    placeholder
}) => (
    <input value={value} onChange={onChange} type="text" id="large-input" placeholder={placeholder} class="block  w-full px-2 py-2 border rounded-md text-sm  bg-gray-700 border-gray-600 placeholder-gray-400 text-white focus:outline-none focus:border-blue-500" />

)