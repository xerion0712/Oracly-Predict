import { createContext, useCallback, ReactNode, useContext, useEffect, useMemo, useReducer, useState } from "react"
import useDatabase from "./useDatabase";

type legatoContextType = {
    currentNetwork: string
    setToAptos: () => void
    setToSui: () => void
    setNetwork: (network: string) => void
    loadDefault: () => void
    loadProfile: (userId: string) => void
    currentProfile: any
};

const legatoContextDefaultValues: legatoContextType = {
    currentNetwork: "aptos",
    currentProfile: undefined,
    setToAptos: () => { },
    setToSui: () => { },
    loadDefault: () => { },
    setNetwork: (network: string) => { },
    loadProfile: (userId: string) => { }
};

type Props = {
    children: ReactNode;
};


export const LegatoContext = createContext<legatoContextType>(legatoContextDefaultValues)


const Provider = ({ children }: Props) => {

    const { getProfile } = useDatabase()

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            ...legatoContextDefaultValues
        }
    )

    const { currentNetwork, currentProfile } = values

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
            loadProfile
        }),
        [
            currentNetwork,
            currentProfile
        ]
    )

    return (
        <LegatoContext.Provider value={legatoContext}>
            {children}
        </LegatoContext.Provider>
    )
}

export default Provider

