import { createContext, useCallback, ReactNode, useContext, useEffect, useMemo, useReducer, useState } from "react"
import BaseModal from "../modals/base"
import { CheckCircle } from "react-feather"
import { Copy } from 'react-feather';
import { CopyToClipboard } from 'react-copy-to-clipboard'
import { shortAddress } from "../helpers";

type txContextType = {
    txId: string | undefined,
    network: string,
    isTestnet: boolean,
    updateTx: (txId: string) => void,
}

const txContextDefaultValues: txContextType = {
    txId: undefined,
    network: "sui",
    isTestnet: false,
    updateTx: () => { }
}

type Props = {
    children: ReactNode
}

export const TxContext = createContext<txContextType>(txContextDefaultValues)

const Provider = ({ children }: Props) => {

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            txId: undefined,
            network: "sui",
            isTestnet: false
        }
    )

    const { txId, network, isTestnet } = values

    const updateTx = (txId: string) => {
        dispatch({
            txId,
            network: "sui",
            isTestnet: false
        })
    }

    const onReset = () => {
        dispatch({
            txId: undefined,
            network: "sui",
            isTestnet: false
        })
    }

    const txContext: any = useMemo(
        () => ({
            txId,
            network,
            isTestnet,
            updateTx
        }),
        [
            txId,
            network,
            isTestnet
        ]
    )

    return (
        <TxContext.Provider value={txContext}>

            <BaseModal
                title={" "}
                visible={txId !== undefined}
                close={() => onReset()}
                maxWidth="max-w-sm"
            >
                {txId && (
                    <div className="px-0">
                        <h4 className="text-center mt-4 font-bold text-2xl">
                            Transaction Successful
                        </h4>

                        <div className="flex p-4 justify-center">
                            <CheckCircle size={60} />
                        </div>
                        <div className="mx-auto text-sm py-2 max-w-[250px] text-center">
                            <p>Your transaction has been successfully processed</p>
                        </div>
                        <div className="w-full flex">
                            <div className="py-2  mx-auto text-sm flex flex-row">
                                <span className="font-bold mr-2">Transaction:</span>
                                <CopyToClipboard text={txId}
                                >
                                    <div className={`  mt-auto mb-1  flex flex-row cursor-pointer text-white text-sm hover:text-white/80`}>
                                        {shortAddress(txId, 10, -6)}
                                        <Copy size={14} className='ml-1 mt-0.5' />
                                    </div>
                                </CopyToClipboard>
                            </div>
                        </div> 
                    </div>
                )}
            </BaseModal>

            {children}
        </TxContext.Provider>
    )
}

export default Provider