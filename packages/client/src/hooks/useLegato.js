import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useState } from "react"
import MARKET from "../data/market.json"

export const LegatoContext = createContext()

const Provider = ({ children }) => {

    const [values, dispatch] = useReducer(
        (curVal, newVal) => ({ ...curVal, ...newVal }),
        {
            market: MARKET.SUI_TO_STAKED_SUI,
        }
    )

    const { market } = values

    const updateMarket = (key) => {
        dispatch({ market: MARKET[key] })
    }

    const legatoContext = useMemo(
        () => ({
            market,
            currentMarket: Object.keys(MARKET).find(item => MARKET[item] === market),
            updateMarket
        }),
        [
            market
        ]
    )

    return (
        <LegatoContext.Provider value={legatoContext}>
            {children}
        </LegatoContext.Provider>
    )
}

export default Provider