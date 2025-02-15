


const ClosingDate = ({ dispatch, marketClosingDate, errors, setErrors  } : any) => {
    return (
        <div className="grid grid-cols-7 mt-4">
            <div className="col-span-2 text-white text-lg font-semibold flex">
                <div className="m-auto mr-4">
                    Closing Date:
                </div>
            </div>
            <div className="col-span-3">
                <input
                    type="datetime-local"
                    value={marketClosingDate}
                    onChange={(e: any) => {
                        dispatch({ marketClosingDate: e.target.value })

                        const closingDate = new Date(e.target.value)
                        const tomorrowDate = new Date().valueOf() + 86400000

                        if (closingDate.valueOf() < tomorrowDate) {
                            setErrors({ marketClosingDate: "Must be at least 24 hours from now." })
                        } else {
                            setErrors({ marketClosingDate: undefined })
                        }

                    }}
                    className="block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none"
                />
            </div>
            <div className="col-span-2 px-2 flex">
                {errors && errors.marketClosingDate && <p className="text-sm  my-auto text-secondary">{errors.marketClosingDate}</p>}
            </div>
            <div className="col-span-2 ">

            </div>
            <div className="col-span-3">
                <p className="text-sm py-2 pb-0 ">The last date and time users can place bets on the market.</p>
            </div>
        </div>
    )
}

export default ClosingDate