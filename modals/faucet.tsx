import { useEffect, useCallback, useReducer, useContext } from "react"
import BaseModal from "./base"
import type { Schema } from "../amplify/data/resource"
import { Amplify } from "aws-amplify"
import { generateClient } from "aws-amplify/api"
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Puff } from 'react-loading-icons'
import { LegatoContext } from "@/hooks/useLegato"

const client = generateClient<Schema>()

const Faucet = ({
    visible,
    close
}: any) => {

    const { loadBalance } = useContext(LegatoContext)

    const { account, network } = useWallet()

    const address = account && account.address

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            name: undefined,
            errorMessage: undefined,
            loading: false
        }
    )

    const { name, errorMessage, loading } = values

    useEffect(() => {
        if (address) {
            dispatch({ name: address })
        }
    }, [address])

    const onMint = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!name || name.length !== 66) {
            dispatch({ errorMessage: "Invalid address" })
            return
        }

        dispatch({ loading: true })
        try {
            const { data } = await client.queries.Faucet({
                name,
            })
            console.log(data)
            dispatch({ loading: false })
            close()

            setTimeout(() => {
                address && loadBalance(address)
            }, 2000)
        } catch (error: any) {
            console.log(error)
            dispatch({ loading: false })
            dispatch({ errorMessage: error.message })
        }
    }, [name, address])

    return (
        <BaseModal
            visible={visible}
            close={close}
            title="Faucet"
            maxWidth="max-w-md"
        >
            <div>
                <div className="py-2 ">
                    <h2 className="my-2 mt-0">Your wallet address:</h2>
                    <input type="text" value={name} onChange={(e) => dispatch({ name: e.target.value })} id="asset" className={`block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none`} />
                </div>
                <div className={`mt-4 grid grid-cols-1 gap-2`}>

                    <button disabled={loading} onClick={onMint} type="button" className="btn w-full text-base inline-flex justify-center rounded-lg  py-2.5 px-8  cursor-pointer  text-black text-center bg-white hover:bg-white hover:scale-100 hover:text-black   ">
                        {loading
                            ?
                            <Puff
                                stroke="#000"
                                className="w-5 h-5"
                            />
                            :
                            <>
                                Send 10 USDC
                            </>
                        }
                    </button>
                </div>
                {errorMessage && (
                    <p className="text-sm text-center mt-2 text-secondary">
                        {errorMessage}
                    </p>
                )}

            </div>
        </BaseModal>
    )
}

export default Faucet