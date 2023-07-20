
import { X, ArrowDown } from "react-feather"
import { useState } from "react"
import Spinner from "./Spinner"

const ListingModal = ({
    closeModal,
    loading,
    price,
    setPrice,
    onCreateOrder
}) => {



    return (
        <div class="fixed inset-0 flex items-center justify-center z-50">
            <div class="absolute inset-0 bg-gray-900 opacity-50"></div>
            <div class="relative bg-gray-800 p-6 w-full max-w-sm text-white rounded-lg">
                <h5 class="text-xl font-bold">Listing Your Item</h5>
                <button class="absolute top-3 right-3 text-gray-500 hover:text-gray-400" onClick={closeModal}>
                    <X />
                </button>
                <div class="w-full mt-1 text-white">
                    <div className="grid grid-cols-8 p-2 gap-3">
                        <div class="col-span-6">
                            <input disabled={true} value={"1"} type="number" class="mt-1 block w-full py-2 px-3 border border-gray-700 bg-gray-900 text-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-base" />
                        </div>
                        <div class="col-span-2 flex">
                            <label class="block text-md text-md font-medium text-gray-300 mt-auto mb-auto mr-auto">VSS12-23</label>
                        </div>
                    </div>
                    <div className="flex justify-center">
                        <ArrowDown />
                    </div>
                    <div className="grid grid-cols-8 p-2 gap-3">
                        <div class="col-span-6">
                            <input onChange={(e) => setPrice(e.target.value)} value={price} type="number" class="mt-1 block w-full py-2 px-3 border border-gray-700 bg-gray-900 text-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-base" />
                        </div>
                        <div class="col-span-1 flex">
                            <label class="block text-md text-md font-medium text-gray-300 mt-auto mb-auto mr-auto">SUI</label>
                        </div>
                    </div>
                    <div className="flex flex-col p-4 mt-2">
                        <button type="button" onClick={onCreateOrder} disabled={loading} class="text-gray-900 flex flex-row justify-center bg-white border border-gray-300 focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm px-5 py-2.5 mr-2 mb-2 dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700">
                            {loading && <Spinner />}
                            Create Order
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default ListingModal