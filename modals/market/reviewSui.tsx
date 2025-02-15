import { useCallback, useContext, useReducer } from "react"
import { OptionBadge } from "../../components/Badge"
import { parseSuiAmount } from "../../helpers"
import ListGroup from "../../components/ListGroup"
import {
    ConnectButton,
    useAccountBalance,
    useWallet,
    SuiChainId,
    ErrorCode,
    formatSUI
} from "@suiet/wallet-kit"
import { Puff } from 'react-loading-icons'

const ReviewSui = () => {

    const { balance } = useAccountBalance()

    const wallet = useWallet()
    const { account, connected } = wallet
    const address = account && account?.address
    const isMainnet = connected && account && account.chains && account.chains[0] === "sui:mainnet" ? true : false

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            amount: 0,
            errorMessage: undefined,
            loading: false
        }
    )

    const { amount, errorMessage, loading } = values

    const onAmountChange = (amount: number) => {
        dispatch({
            amount
        })
    }

    const onBet = useCallback(async () => {

        

    }, [])

    const available = parseSuiAmount(balance, 9)

    return (
        <>
            <div className='p-2 border-gray/20   mt-[15px] border-[1px] rounded-md bg-[url(/assets/images/consulting/business-img.png)] bg-cover bg-center bg-no-repeat '>
                <div className="grid grid-cols-2 p-2 text-gray">
                    <div className=" py-0.5 text-sm  flex flex-row">
                        <span className="font-bold mr-2">Outcome:</span>
                        <div className={`   flex flex-row  text-white text-sm `}>
                            {/* {`${marketName}`} */}
                        </div>
                    </div>
                    <div className=" py-0.5 text-sm  flex flex-row">
                        <span className="font-bold mr-2">Outcome Liquidity:</span>
                        <div className={`   flex flex-row  text-white text-sm `}>
                            {/* {liquidity}{` APT`} */}
                        </div>
                    </div>
                    <div className=" py-0.5 text-sm  flex flex-row">
                        <span className="font-bold mr-2">Current Odds:</span>
                        <div className={`   flex flex-row  text-white text-sm `}>
                            {/* {odds.toLocaleString()} */}
                        </div>
                    </div>
                    <div className=" py-0.5 text-sm  flex flex-row">
                        <span className="font-bold mr-2">Deadline:</span>
                        <div className={`   flex flex-row  text-white text-sm `}>
                            {/* {(new Date(Number(expiration) * 1000)).toLocaleDateString()} */}
                        </div>
                    </div>
                </div>
            </div>

            <div className='p-4 border-gray mt-[15px] border-[1px] rounded-md '>
                <div className='py-3'>
                    <div className="block leading-6 mb-2">Enter bet amount</div>
                    <div className="grid grid-cols-7">
                        <div className="col-span-5">
                            <input value={amount} onChange={(e) => {
                                onAmountChange(Number(e.target.value))
                            }} type="number" id="input-asset" className={`block w-full p-4  rounded-l-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none`} />
                        </div>

                        <div className="col-span-2">
                            <div className="cursor-default flex border border-l-0 border-gray/30 bg-gray/30  rounded-r-lg h-full">
                                <div className="m-auto flex flex-row text-white font-normal">
                                    <img className="h-5 w-5 mt-0.5 rounded-full" src={"/assets/images/sui-sui-logo.svg"} alt="" />
                                    <div className="mt-auto mb-auto ml-1.5">
                                        SUI
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="text-xs flex flex-row my-2">
                        <div className="font-medium ">
                            Available: {Number(available).toFixed(3)}{` SUI`}
                        </div>
                        <div className="ml-auto flex flex-row ">
                            <OptionBadge onClick={() => onAmountChange(1)} className="cursor-pointer hover:bg-gray hover:text-black">
                                1{` SUI`}
                            </OptionBadge>
                            <OptionBadge onClick={() => onAmountChange((Math.floor(Number(available) * 500) / 1000))} className="cursor-pointer hover:bg-gray hover:text-black">
                                50%
                            </OptionBadge>
                            <OptionBadge onClick={() => onAmountChange((available > 3 ? 3 : Math.floor(Number(available) * 1000) / 1000))} className="cursor-pointer hover:bg-gray hover:text-black">
                                Max
                            </OptionBadge>
                        </div>
                    </div>
                    <div className="px-1 mt-4">
                        <ListGroup
                            items={[
                                ["Potential payout", `${(1 * amount).toLocaleString()} SUI`],
                                ["Estimate payout date", `${new Date().toLocaleDateString()}`],
                                ["Winning fee", "10%"],
                            ]}
                        />
                    </div>
                </div>
            </div>

            <div className="flex mt-4">
                {wallet && wallet.connected ? (
                    <button onClick={onBet} disabled={loading} type="button" className="btn mx-auto w-full bg-white hover:bg-white hover:text-black rounded-md">
                        {loading
                            ?
                            <Puff
                                stroke="#000"
                                className="w-5 h-5 mx-auto"
                            />
                            :
                            <>
                                Place Bet
                            </>}
                    </button>
                ) : (
                    <ConnectButton style={{ width: "100%", borderRadius: "8px" }}>
                        Connect
                    </ConnectButton>
                )}
            </div>

            {errorMessage && (
                <div className='text-gray-400 mt-2 text-sm font-medium  text-center w-full '>
                    <div className='p-2 pb-0 text-secondary'>
                        {errorMessage}
                    </div>
                </div>
            )}

        </>
    )
}

export default ReviewSui