import { OptionBadge } from "./Badge";

interface IInputStake {
    value: number | undefined
    onChange: any
    symbol: string
    available: number | undefined
}

const InputStake = ({ value, onChange, symbol, available }: IInputStake) => {

    let icon = ""

    if (symbol === "apt") {
        icon = "/assets/images/aptos-logo.png"
    } else if (symbol === "sui") {
        icon = "/assets/images/sui-sui-logo.svg"
    }

    return (
        <>
            <div className="block leading-6 mb-2 text-gray ">Enter deposit amount</div>
            <div className="grid grid-cols-7"> 
                <div className="col-span-5">
                    <input value={value} onChange={(e) => {
                        onChange(e.target.value)
                    }} type="number" id="input-asset" className={`block w-full p-4  rounded-l-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none`} />
                </div>
                <div className="col-span-2">
                    <div className="cursor-default flex border border-l-0 border-gray/30 bg-gray/30  rounded-r-lg h-full">
                        <div className="m-auto flex flex-row text-white font-normal">
                            <img className="h-5 w-5 mt-0.5 rounded-full" src={icon} alt="" />
                            <div className="mt-auto mb-auto ml-1.5">
                                {symbol.toUpperCase()}
                            </div>
                        </div>
                    </div> 
                </div>
            </div>
            <div className="text-xs flex flex-row my-2">
                <div className="font-medium ">
                    Available: {Number(available).toFixed(3)}{` `}{symbol.toUpperCase()}
                </div>
                <div className="ml-auto flex flex-row ">
                    <OptionBadge onClick={() => onChange(1)} className="cursor-pointer hover:bg-gray hover:text-black">
                        1{` `}{symbol.toUpperCase()}
                    </OptionBadge>
                    <OptionBadge onClick={() => onChange((Math.floor(Number(available) * 500) / 1000))} className="cursor-pointer hover:bg-gray hover:text-black">
                        50%
                    </OptionBadge>
                    <OptionBadge onClick={() => onChange((Math.floor(Number(available) * 1000) / 1000))} className="cursor-pointer hover:bg-gray hover:text-black">
                        Max
                    </OptionBadge>
                </div>
            </div>
        </>
    )
}

export default InputStake