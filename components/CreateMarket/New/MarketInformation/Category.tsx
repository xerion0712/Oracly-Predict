

import Categories from "../../../../data/categories.json"

const Category = ({ dispatch, marketCategory }: any) => {
    return (
        <div className="grid grid-cols-7 mt-4">
            <div className="col-span-2 text-white text-lg font-semibold flex">
                <div className="m-auto mr-4">
                    Category:
                </div>
            </div>
            <div className="col-span-3">
                <select value={marketCategory} onChange={(e: any) => {
                    dispatch({ marketCategory: e.target.value })
                }} className="block w-full p-2 cursor-pointer  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none">
                    {Categories.map((c: any, index: number) => (
                        <option key={index} value={c}>{c}</option>
                    ))}
                </select>
            </div>
            <div className="col-span-2 px-2 flex">

            </div>
            <div className="col-span-2 ">

            </div>
            <div className="col-span-3">
                <p className="text-sm py-2 pb-0 ">Select a category to classify your market.</p>
            </div>
        </div>
    )
}

export default Category