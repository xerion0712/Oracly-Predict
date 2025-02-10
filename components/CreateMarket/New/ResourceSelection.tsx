import BaseModal from "@/modals/base"
import { useState } from "react"

const ResourceSelection = ({ dispatch, resources, resource }: any) => {

    const [modal, setModal] = useState<boolean>(false)

    const currentItem = resources.find((item: any) => item.name === resource)

    return (
        <>

            <BaseModal
                visible={modal}
                title="Add New Resource"
                close={() => setModal(false)}
            >
                <p className="mt-2.5 text-left text-lg font-medium  ">
                    For now, please contact our team to request a new resource.
                </p>
                <div className="mt-4 ">
                    <button onClick={() => {
                        setModal(false)
                    }} type="button" className="btn mx-auto rounded-lg  bg-white py-2.5 px-8  hover:text-black hover:bg-white flex flex-row">
                        Close
                    </button>
                </div>
            </BaseModal>


            <h2 className='text-xl tracking-tight font-semibold text-white'>Resource Selection</h2>
            <p className="py-0.5">Select the data source that will power your market</p>
            <div className='py-4 h-[100px]'>
                <div className="grid grid-cols-7">
                    <div className="col-span-2 text-white text-lg font-semibold flex">
                        <div className="m-auto mr-4">
                            Resource:
                        </div>
                    </div>
                    <div className="col-span-3">
                        <select value={resource && resource.name || undefined}
                            onChange={(e: any) => {
                                dispatch({ resource: e.target.value })
                            }} className="block w-full p-2 cursor-pointer  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none">
                            <option value={undefined}>Select a resource</option>
                            {resources.map((resource: any, index: number) => (
                                <option key={index} value={resource.name}>{resource.name}</option>
                            ))}
                        </select>

                    </div>
                    <div className="col-span-2 px-2">
                        <button onClick={() => {
                            setModal(true)
                        }} type="button" className="btn ml-2  rounded-lg  bg-white py-2.5 px-8  hover:text-black hover:bg-white flex flex-row">
                            Add New Resource
                        </button>
                    </div>
                    <div className="col-span-2 ">

                    </div>
                    <div className="col-span-3">
                        {currentItem ? (
                            <>
                                <p className="text-sm py-2 pb-0 ">{currentItem.description}{` `}
                                    ({<a href={currentItem.url} target="_blank" className="text-sm underline  ">{currentItem.url}</a>})
                                </p>
                            </>
                        ) : <p className="text-sm py-2 pb-0 ">Select one to see the resource's description.</p>}

                    </div>
                </div>
            </div>
        </>
    )
}

export default ResourceSelection