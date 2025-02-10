import { useState, useCallback, useEffect, useReducer } from "react"

// import { Puff } from 'react-loading-icons'
import useDatabase from "@/hooks/useDatabase"
 
import MarketTitle from "./MarketTitle";
import MarketDescription from "./MarketDescription";
import ClosingDate from "./ClosingDate"
import ResolutionDate from "./ResolutionDate"
import Category from "./Category"
import MarketOutcomes from "./MarketOutcomes";

const MarketInformation = ({ dispatch, markets, marketTitle, resource, marketDescription, marketCategory, marketClosingDate, marketResolutionDate, marketOutcomeA, marketOutcomeB, marketOutcomeC, marketOutcomeD, totalOutcomes }: any) => {

    const [errors, setErrors] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }), {}
    )
 
    return (
        <>

            <h2 className='text-xl tracking-tight font-semibold text-white'>Market Settings</h2>
            <p className="py-0.5">General information about your market</p>

            <div className='py-4 '>

                <MarketTitle
                    dispatch={dispatch} 
                    markets={markets} 
                    marketTitle={marketTitle}
                />

                <MarketDescription
                    dispatch={dispatch} 
                    resource={resource}
                    marketDescription={marketDescription}
                />

                <ClosingDate
                    dispatch={dispatch} 
                    marketClosingDate={marketClosingDate}
                    errors={errors}
                    setErrors={setErrors}
                />

                <ResolutionDate
                    dispatch={dispatch} 
                    marketResolutionDate={marketResolutionDate}
                    marketClosingDate={marketClosingDate}
                    errors={errors}
                    setErrors={setErrors}
                />
 
                <Category
                    dispatch={dispatch}
                    marketCategory={marketCategory}
                />
 
                <MarketOutcomes
                    dispatch={dispatch}
                    resource={resource}
                    marketDescription={marketDescription}
                    marketOutcomeA={marketOutcomeA}
                    marketOutcomeB={marketOutcomeB}
                    marketOutcomeC={marketOutcomeC}
                    marketOutcomeD={marketOutcomeD} 
                    totalOutcomes={totalOutcomes}
                />

            </div>
            <style>
                {`
                    ::-webkit-calendar-picker-indicator {
                        filter: invert(1);
                        cursor: pointer;
                    }
        `}
            </style>
        </>
    )
}

export default MarketInformation