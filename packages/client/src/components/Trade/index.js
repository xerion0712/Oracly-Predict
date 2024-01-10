
import { useCallback, useContext, useEffect, useReducer } from "react"
import { ArrowsRightLeftIcon, ArrowRightIcon } from "@heroicons/react/20/solid"
import { useWallet } from '@suiet/wallet-kit'
import BigNumber from "bignumber.js"
import TradeAmountInput from "./TradeAmountInput"
import { LegatoContext } from "@/hooks/useLegato"
import CURRENCY from "../../data/currency.json"
import VAULT from "../../data/vault.json"
import MessageModal from "@/modals/Message"
import CurrencySelectModal from "@/modals/CurrencySelect"
import { useAccountBalance } from '@suiet/wallet-kit'
import Spinner from "@/components/Spinner"


const MODAL = {
    NONE: "NONE",
    CURRENCY_SELECT: "CURRENCY_SELECT",
    UNABLE_TO_SELECT: "UNABLE_TO_SELECT"
}


const Trade = () => {

    const wallet = useWallet()
    const { account, connected } = wallet
    const isTestnet = connected && account && account.chains && account.chains[0] === "sui:testnet" ? true : false
    const { balance } = useAccountBalance()
    const { swap, getTotalYT } = useContext(LegatoContext)

    const [values, dispatch] = useReducer(
        (curVal, newVal) => ({ ...curVal, ...newVal }),
        {
            tick: 0,
            baseAmount: 0,
            available: 0,
            baseCurrency: undefined,
            pairAmount: 0,
            pairCurrency: undefined,
            modal: MODAL.NONE,
            loading: false,
            errorMessage: undefined,
            disabled: false
        }
    )

    const { tick, disabled, available, baseAmount, baseCurrency, pairAmount, pairCurrency, modal, loading, errorMessage } = values

    const handleChange = (e) => {
        dispatch({
            baseAmount: 0,
            pairAmount: 0,
            [e.target.name]: Number(e.target.value)
        })
    }

    useEffect(() => {
        dispatch({
            baseCurrency: isTestnet ? CURRENCY[1] : CURRENCY[0],
            pairCurrency: isTestnet ? CURRENCY[2] : CURRENCY[3]
        })
    }, [isTestnet])

    useEffect(() => {
        connected && baseCurrency && fetchBalance(baseCurrency, balance)
    }, [baseCurrency, connected, isTestnet, balance, tick])

    const fetchBalance = useCallback(async ({ symbol }, balance) => {

        if (symbol === "SUI") {
            dispatch({
                available: Number(`${(BigNumber(balance)).dividedBy(BigNumber(10 ** 9))}`)
            })
        } else {

            const { vaultId } = CURRENCY.find(item => item.symbol === symbol)
            const vault = VAULT.find(item => item.id === vaultId)

            const allYT = await getTotalYT(account.address, isTestnet)
            const myYT = allYT.filter(item => item.vault === vault.name)

            const available = myYT.reduce((output, item) => {
                return output+Number(`${(BigNumber(item.balance)).dividedBy(BigNumber(10 ** 9))}`)
            },0)

            dispatch({
                available
            })
        }

    }, [account, isTestnet])

    const onSelectCurrency = useCallback((currency) => {

        const pairCurrencyId = currency.pairs[0]
        const pairCurrency = CURRENCY.find(item => item.id === pairCurrencyId)

        dispatch({
            baseCurrency: currency,
            pairCurrency,
            modal: MODAL.NONE
        })

    }, [])

    const onNext = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!baseAmount || !baseCurrency || !pairCurrency) return

        dispatch({ loading: true })

        try {

            await swap(baseCurrency, pairCurrency, baseAmount, isTestnet)

            dispatch({ baseAmount: 0, pairAmount: 0, tick: tick + 1 })

        } catch (e) {
            console.log(e)
            dispatch({ errorMessage: `${e.message}` })
        }

        dispatch({ loading: false })

    }, [baseAmount, swap, pairCurrency, baseCurrency, tick, isTestnet])

    return (
        <>
            <MessageModal
                visible={modal === MODAL.UNABLE_TO_SELECT}
                close={() => dispatch({ modal: MODAL.NONE })}
                info="Pair currency selection is not available right now."
            />
            <CurrencySelectModal
                visible={modal === MODAL.CURRENCY_SELECT}
                close={() => dispatch({ modal: MODAL.NONE })}
                isTestnet={isTestnet}
                onSelectCurrency={onSelectCurrency}
            />

            <div class="wrapper p-2 mb-10">
                <div className=" mx-auto max-w-lg">
                    <h5 class="text-2xl text-white font-bold  my-3  ">
                        Trade
                    </h5>
                    <div class={` bg-gray-900 p-6 w-full border border-gray-700 rounded-2xl`}>

                        <div className="flex flex-col py-2">
                            <div>
                                <TradeAmountInput
                                    name="baseAmount"
                                    amount={baseAmount}
                                    currency={baseCurrency}
                                    onChange={handleChange}
                                    onSelect={() => dispatch({ modal: MODAL.CURRENCY_SELECT })}
                                />
                                <div className="text-xs flex p-2 flex-row text-gray-300 border-gray-400  ">
                                    <div className="font-medium ">
                                        Available: {Number(available).toFixed(3)}{` ${baseCurrency && baseCurrency.symbol}`}
                                    </div>
                                    {/* <div className="ml-auto  flex flex-row ">
                                        <OptionBadge onClick={() => available && Number(available) >= 1 ? dispatch({ amount: 1 }) : 0} className="cursor-pointer hover:underline">
                                            1 SUI
                                        </OptionBadge>
                                        <OptionBadge onClick={() => dispatch({ amount: (Math.floor(Number(available) * 500) / 1000) })} className="cursor-pointer hover:underline">
                                            50%
                                        </OptionBadge>
                                        <OptionBadge onClick={() => dispatch({ amount: (Math.floor(Number(available) * 1000) / 1000) })} className="cursor-pointer hover:underline">
                                            Max
                                        </OptionBadge>
                                    </div> */}
                                </div>
                            </div>
                            <div className='flex my-2'>
                                <ArrowsRightLeftIcon className="h-8 w-8 m-auto" />
                            </div>
                            <div className="mt-2">
                                <TradeAmountInput
                                    disabled={true}
                                    name="pairAmount"
                                    amount={pairAmount}
                                    currency={pairCurrency}
                                    onChange={handleChange}
                                    onSelect={() => dispatch({ modal: MODAL.UNABLE_TO_SELECT })}
                                />

                            </div>

                            <div className="text-xs font-medium text-gray-300 text-center py-4 mt-4 max-w-sm mx-auto">
                                Every vault comes with its own set of yield tokens (YT). If a vault accumulates surplus, you can claim extra rewards
                            </div>

                            <button disabled={disabled} onClick={onNext} className={`py-3 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row w-full justify-center bg-blue-700`}>
                                {loading && <Spinner />}
                                Proceed
                            </button>
                            {errorMessage && (
                                <div className="text-xs font-medium p-2 text-center text-yellow-300">
                                    {errorMessage}
                                </div>
                            )}

                        </div>


                    </div>
                </div>

            </div>
        </>
    )
}

export default Trade