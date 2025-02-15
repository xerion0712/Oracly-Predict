import { useContext, useEffect, useReducer, useState } from "react"
import Divider from "../../Divider"
import ChainSelection from "./ChainSelection"
import ResourceSelection from "./ResourceSelection"
import useDatabase from "@/hooks/useDatabase"
import BaseModal from "@/modals/base"
import MarketInformation from "./MarketInformation"
import { LegatoContext } from "@/hooks/useLegato"
import Catagories from "../../../data/categories.json"

const NewMarketContainer = () => {

    const { currentProfile } = useContext(LegatoContext)
    const { getResources, getMarketsByCreator } = useDatabase()

    const [modal, setModal] = useState<boolean>(false)

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            chainId: "aptos",
            resources: [],
            resource: undefined,
            markets: [],
            marketTitle: undefined,
            marketDescription: undefined,
            marketCategory: Catagories[0],
            marketClosingDate: undefined,
            marketResolutionDate: undefined,
            totalOutcomes: 4,
            marketOutcomeA: undefined,
            marketOutcomeB: undefined,
            marketOutcomeC: undefined,
            marketOutcomeD: undefined
        }
    )

    const {
        chainId,
        resources,
        resource,
        markets,
        marketTitle,
        marketDescription,
        marketCategory,
        marketClosingDate,
        marketResolutionDate,
        totalOutcomes,
        marketOutcomeA,
        marketOutcomeB,
        marketOutcomeC,
        marketOutcomeD
    } = values

    useEffect(() => {
        if (currentProfile && currentProfile.id) {
            getMarketsByCreator(currentProfile.id).then(
                (markets: any) => {
                    dispatch({ markets })
                }
            )
        }
    }, [currentProfile])

    useEffect(() => {

        getResources().then((resources: any) => {
            dispatch({ resources })
        })

    }, [])

    useEffect(() => {

        if (localStorage.getItem("new_market_disclaimer")) {
            setModal(false)
        } else {
            setModal(true)
        }

    }, [])

    return (
        <>

            <BaseModal visible={modal} title="Disclaimer" maxWidth="max-w-lg" close={() => {
                setModal(false)
                localStorage.setItem("new_market_disclaimer", "true")
            }}>
                <p className="mt-2.5 text-left text-lg font-medium  ">
                    Ensure you have the creator role to create a new market. Contact us if you need one.
                </p>

                <div className="mt-4 ">
                    <button onClick={() => {
                        setModal(false)
                        localStorage.setItem("new_market_disclaimer", "true")
                    }} type="button" className="btn mx-auto rounded-lg  bg-white py-2.5 px-8  hover:text-black hover:bg-white flex flex-row">
                        Close
                    </button>
                </div>

            </BaseModal>

            <div className="heading mb-0 text-center">
                <h4 className="!font-black">
                    NEW <span className="text-secondary">MARKET</span>
                </h4>
            </div>

            <p className="mt-2.5 text-center text-lg font-medium mx-auto max-w-lg  ">
                Setup your market in just a few steps with AI assistance and share the fees with Legato
            </p>

            <div className="p-4">

                <ChainSelection
                    dispatch={dispatch}
                    chainId={chainId}
                />

                <Divider />

                <ResourceSelection
                    dispatch={dispatch}
                    resources={resources}
                    resource={resource}
                />

                <Divider />

                <MarketInformation
                    dispatch={dispatch}
                    markets={markets.filter((item: any) => item.chainId === chainId)}
                    marketTitle={marketTitle}
                    resource={resources.find((item: any) => item.name === resource)}
                    marketDescription={marketDescription}
                    marketCategory={marketCategory}
                    marketClosingDate={marketClosingDate}
                    marketResolutionDate={marketResolutionDate}
                    marketOutcomeA={marketOutcomeA}
                    marketOutcomeB={marketOutcomeB}
                    marketOutcomeC={marketOutcomeC}
                    marketOutcomeD={marketOutcomeD}
                    totalOutcomes={totalOutcomes}
                />
 


            </div>

        </>
    )
}

export default NewMarketContainer