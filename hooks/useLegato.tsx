import { createContext, useCallback, ReactNode, useContext, useEffect, useMemo, useReducer, useState } from "react"
import useDatabase from "./useDatabase";
import useAptos from "./useAptos";

type legatoContextType = {
    currentNetwork: string
    balance: number,
    setToAptos: () => void
    setToSui: () => void
    setNetwork: (network: string) => void
    loadDefault: () => void
    loadProfile: (userId: string) => void
    currentProfile: any,
    loadBalance: (userAddress: string) => void
};

const legatoContextDefaultValues: legatoContextType = {
    currentNetwork: "aptos",
    currentProfile: undefined,
    balance: 0,
    setToAptos: () => { },
    setToSui: () => { },
    loadDefault: () => { },
    setNetwork: (network: string) => { },
    loadProfile: (userId: string) => { },
    loadBalance: (userAddress: string) => { }
};

type Props = {
    children: ReactNode;
};


export const LegatoContext = createContext<legatoContextType>(legatoContextDefaultValues)


const Provider = ({ children }: Props) => {

    const { getBalanceUSDC } = useAptos()

    const { getProfile } = useDatabase()

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            ...legatoContextDefaultValues
        }
    )

    const { currentNetwork, currentProfile, balance } = values

    const loadDefault = useCallback(() => {
        if (localStorage.getItem("legatoDefaultNetwork")) {
            dispatch({
                currentNetwork: localStorage.getItem("legatoDefaultNetwork")
            })
        } else {
            dispatch({
                currentNetwork: "aptos"
            })
        }
    }, [])

    const loadProfile = useCallback((userId: string) => {

        getProfile(userId).then(
            (currentProfile: any) => {
                dispatch({
                    currentProfile
                })
            }
        )

    }, [])

    const loadBalance = useCallback((userAddress: string) => {
        getBalanceUSDC(userAddress).then(
            (balance: number) => {
                dispatch({
                    balance
                })
            }
        )
    }, [])

    const legatoContext: any = useMemo(
        () => ({
            currentNetwork,
            currentProfile,
            setNetwork: (network: string) => {
                dispatch({
                    currentNetwork: network
                })
            },
            loadDefault,
            loadProfile,
            balance,
            loadBalance
        }),
        [
            currentNetwork,
            currentProfile,
            balance
        ]
    )

    return (
        <LegatoContext.Provider value={legatoContext}>
            {children}
        </LegatoContext.Provider>
    )
}

export default Provider

