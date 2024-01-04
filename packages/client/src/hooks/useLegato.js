import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useState } from "react"
import MARKET from "../data/market.json"
import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';

export const LegatoContext = createContext()

const Provider = ({ children }) => {

    const [values, dispatch] = useReducer(
        (curVal, newVal) => ({ ...curVal, ...newVal }),
        {
            market: MARKET.SUI_TO_STAKED_SUI,
            validators: [],
            avgApy: 0,
            isTestnet: false,
            vaults: []
        }
    )

    const { market, validators, avgApy, isTestnet, vaults } = values

    const updateMarket = (key) => {
        dispatch({ market: MARKET[key] })
    }

    const updateValues = (values) => {
        dispatch({ ...values })
    }

    const legatoContext = useMemo(
        () => ({
            market,
            currentMarket: Object.keys(MARKET).find(item => MARKET[item] === market),
            updateMarket, 
            validators,
            avgApy,
            isTestnet,
            updateValues,
            vaults
        }),
        [
            market,
            validators,
            vaults,
            avgApy,
            isTestnet
        ]
    )

    return (
        <LegatoContext.Provider value={legatoContext}>
            {children}
        </LegatoContext.Provider>
    )
}

export default Provider