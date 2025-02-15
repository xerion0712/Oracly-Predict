

const ChainSelection = ({ chainId, dispatch }: any) => {
    return (
        <>
            <h2 className='text-xl tracking-tight font-semibold text-white'>Chain Selection</h2>
            <p className="py-0.5">Choose the blockchain you want to use for your market</p>
            
            <div className="grid grid-cols-7 mt-4">
                <div className="col-span-2 text-white text-lg font-semibold flex">
                    <div className="m-auto mr-4">
                        Blockchain:
                    </div>
                </div>
                <div className="col-span-3">
                    <div className="grid grid-cols-2 gap-4  " >

                        <div onClick={() => dispatch({ chainId: "aptos", marketTitle: undefined })} className={`flex flex-row w-full items-start gap-[10px] rounded-lg border  py-2 px-4  cursor-pointer  ${chainId === "aptos" ? "bg-transparent border-secondary" : "border-transparent bg-secondary/10"}  `}>
                            <img src="/assets/images/aptos-logo.png" alt="Aptos" className="w-6 h-6 ml-auto mt-[1px] " />
                            <h3 className="text-lg mr-auto ml-0.5 font-semibold">APTOS</h3>
                        </div>

                        <div onClick={() => dispatch({ chainId: "sui", marketTitle: undefined })} className={`flex  flex-row w-full items-start gap-[10px] rounded-lg border  py-2 px-4  cursor-pointer  ${chainId === "sui" ? "bg-transparent border-secondary" : "border-transparent bg-secondary/10"}  `}>
                            <img src="/assets/images/sui-sui-logo.svg" alt="Sui" className="w-6 h-6 ml-auto mt-[1px]" />
                            <h3 className="text-lg mr-auto ml-0.5 font-semibold">SUI</h3>
                        </div>

                    </div> 
                </div>

            </div>
        </>
    )
}

export default ChainSelection