import MarketSelectModal from "@/modals/MarketSelect"
import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useState } from "react"
import { LegatoContext } from "./useLegato"

export const ModalContext = createContext()

export const MODAL = {
    NONE: "NONE",
    MARKET: "MARKET"
}

const Provider = ({ children }) => {

    const [values, dispatch] = useReducer(
        (curVal, newVal) => ({ ...curVal, ...newVal }),
        {
            modal: MODAL.NONE,
            info : undefined
        }
    )

    const { modal, info } = values
    const { market } = useContext(LegatoContext)

    const closeModal = () => {
        dispatch({
            modal: MODAL.NONE
        })
    }

    const openModal = (modal, info) => {
        dispatch({
            modal,
            info
        })
    }

    const modalContext = useMemo(
        () => ({
            modal,
            openModal,
            closeModal
        }),
        [
            modal
        ]
    )

    return (
        <ModalContext.Provider value={modalContext}>
            <MarketSelectModal
                visible={modal === MODAL.MARKET}
                close={() => closeModal()}
                currentMarket={market}
                info={info}
            />
            {children}
        </ModalContext.Provider>
    )
}

export default Provider