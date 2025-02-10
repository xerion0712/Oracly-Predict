


const ResolutionDate = ({ dispatch, marketResolutionDate, marketClosingDate, errors, setErrors  }: any) => {
    return (
        <div className="grid grid-cols-7 mt-4">
            <div className="col-span-2 text-white text-lg font-semibold flex">
                <div className="m-auto mr-4">
                    Resolution Date:
                </div>
            </div>
            <div className="col-span-3">
                <input
                    type="datetime-local"
                    value={marketResolutionDate}
                    onChange={(e: any) => {
                        dispatch({ marketResolutionDate: e.target.value })

                        const resolutionDate = new Date(e.target.value)
                        const closingDate = new Date(marketClosingDate)
                        if (resolutionDate.valueOf() < closingDate.valueOf()) {
                            setErrors({ marketResolutionDate: "Must be after the closing date." })
                        } else {
                            setErrors({ marketResolutionDate: undefined })
                        }

                    }}
                    className="block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none"
                />
            </div>
            <div className="col-span-2 px-2 flex">
                {errors && errors.marketResolutionDate && <p className="text-sm  my-auto text-secondary">{errors.marketResolutionDate}</p>

                }
            </div>
            <div className="col-span-2 ">

            </div>
            <div className="col-span-3">
                <p className="text-sm py-2 pb-0 ">When the AI-agent finalizes the market outcome, should be aligned with the market description.</p>
            </div>
        </div>
    )
}

export default ResolutionDate