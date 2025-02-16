import { useContext, useReducer, useEffect, useState, useCallback } from "react"
import BaseModal from "../base"
import { Authenticator, useTheme, View, Heading, Image, Text, Button, ThemeProvider, Theme } from '@aws-amplify/ui-react'

import { ArrowRight, Save } from "react-feather";
import { Puff } from 'react-loading-icons'
import useDatabase from "../../hooks/useDatabase";
import useAtoma from "@/hooks/useAtoma";
import { LegatoContext } from "@/hooks/useLegato";
import Link from "next/link";

interface IMarketModal {
    visible: boolean
    close: () => void
    roundId: number
    marketId: string
    increaseTick: any
}

const components = {
    Footer() {
        const { tokens } = useTheme();

        return (
            <View textAlign="center" padding={tokens.space.large}>
                <Text color={tokens.colors.neutral[80]}>
                    <span className="text-secondary">
                        Login or create an account to continue
                    </span>
                </Text>
            </View>
        );
    }
};

enum STEP {
    PAGE_1,
    PAGE_2
}


const NewOutcomeModalOLD = ({ visible, close, roundId, marketId, increaseTick }: IMarketModal) => {

    const { generateOutcome } = useAtoma()
    const { getResources, crawl, addOutcome } = useDatabase()

    const [selected, setSelected] = useState(0)

    const [values, dispatch] = useReducer(
        (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
        {
            name: undefined,
            description: undefined,
            step: STEP.PAGE_1,
            topic: "Price Predictions",
            asset: undefined,
            errorMessage: undefined,
            loading: false,
            outcome: undefined,
            cleanedText: undefined
        }
    )

    const { name, description, step, topic, loading, errorMessage, asset, outcome, cleanedText } = values


    // useEffect(() => {

    //     if (currentMarket && currentMarket.outcomeId) {
    //         const { outcomeId } = currentMarket
    //         setSelected(outcomeId)
    //     }

    // }, [currentMarket])

    const onNext = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!topic) {
            dispatch({ errorMessage: "Invalid topic!" })
            return
        }

        dispatch({ loading: true })

        try {

            const resources = await getResources()

            const context = await crawl(resources[0])

            let cleanedText = context.replace(/\[(.*?)\]\(https?:\/\/[^\s)]+\)/g, '$1')
            cleanedText = cleanedText.replace(/\((https?:\/\/[^\s)]+)\)/g, "")

            if (cleanedText.indexOf("Find out how we work by clicking here") !== -1) {
                cleanedText = cleanedText.split("Find out how we work by clicking here")[0]
            }

            dispatch({ errorMessage: "Processing on DeepSeek R1 via Atoma. May take a few minutes." })

            console.log("cleanedText:", cleanedText)

            const content = await generateOutcome({
                topic,
                asset,
                context: cleanedText
            })

            console.log("final content : ", content)

            dispatch({ outcome: content, cleanedText, errorMessage: undefined, step: STEP.PAGE_2 })

        } catch (e: any) {
            console.log(e)
            dispatch({ errorMessage: `${e.message}`, loading: false })
        }


        dispatch({ loading: false })

    }, [topic, asset, roundId])


    const onSave = useCallback(async () => {

        dispatch({ errorMessage: undefined })

        if (!topic) {
            dispatch({ errorMessage: "Invalid topic!" })
            return
        }

        dispatch({ loading: true })

        try {

            console.log("saving content : ", outcome)

            await addOutcome({
                marketId,
                roundId,
                title: outcome,
                dataCrawled: cleanedText
            })

            dispatch({ outcome: undefined, cleanedText: undefined, errorMessage: undefined, step: STEP.PAGE_1 })

            increaseTick()

            close()

        } catch (e: any) {
            console.log(e)
            dispatch({ errorMessage: `${e.message}`, loading: false })
        }

        dispatch({ loading: false })

    }, [outcome, cleanedText, roundId, marketId])

    const { tokens } = useTheme()

    const theme: Theme = {
        name: 'Auth Theme',
        tokens: {
            components: {
                authenticator: {
                    router: {
                        boxShadow: `0 0 16px ${tokens.colors.overlay['10']}`,
                        borderWidth: '0',
                    }
                },

                tabs: {
                    item: {
                        backgroundColor: "#08111566",
                        borderColor: "#08111566"
                    },
                },
            },
        },
    }



    return (
        <BaseModal
            visible={visible}
            close={close}
            title={"Add New Outcome"}
            maxWidth="max-w-xl"
        >
            <ThemeProvider theme={theme} >
                <View>
                    <Authenticator components={components} >

                        {step === STEP.PAGE_1 && (
                            <>
                                <div className="py-2 pt-4">
                                    <h2 className="mb-2">Choose a topic:</h2>
                                    <div className="flex flex-row space-x-1">
                                        {["Price Predictions", "Market Capitalization & Rankings", "Trading Volume"].map((name) => (
                                            <div
                                                key={name}
                                                onClick={() => dispatch({ topic: name })}
                                                className={`rounded cursor-pointer py-2 px-4 text-sm  border border-gray/30 text-white/60  focus:outline-none ${topic === name && "bg-[#141F32] text-white/100"} hover:bg-[#141F32]  focus:outline-1 focus:outline-white`}
                                            >
                                                {name}
                                            </div>
                                        ))}
                                    </div>
                                    <h2 className="my-2 mt-4">Specify an asset (Optional):</h2>
                                    <input type="text" value={asset} onChange={(e) => dispatch({ asset: e.target.value })} id="asset" placeholder="Ex. BTC, ETH, SOL" className={`block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none`} />
                                </div>
                                <div className={`mt-4 grid ${step === STEP.PAGE_1 ? "grid-cols-1" : "grid-cols-2"} gap-2`}>
                                    {step === STEP.PAGE_2
                                        && (
                                            <button onClick={() => alert()} type="button" className="btn w-full text-base rounded-lg  py-2.5 px-8  cursor-pointer  text-black text-center bg-white hover:bg-white hover:scale-100 hover:text-black    ">
                                                Back
                                            </button>
                                        )
                                    }
                                    {step === STEP.PAGE_1
                                        && (
                                            <button disabled={loading} onClick={onNext} type="button" className="btn w-full text-base inline-flex justify-center rounded-lg  py-2.5 px-8  cursor-pointer  text-black text-center bg-white hover:bg-white hover:scale-100 hover:text-black   ">
                                                {loading
                                                    ?
                                                    <Puff
                                                        stroke="#000"
                                                        className="w-5 h-5"
                                                    />
                                                    :
                                                    <>
                                                        Next
                                                        <ArrowRight />
                                                    </>
                                                }
                                            </button>
                                        )
                                    }
                                </div>
                            </>
                        )}

                        {step === STEP.PAGE_2 && (
                            <>
                                <div className="py-2 pt-4">
                                    <h2 className="my-2">Your Outcome:</h2>
                                    <textarea rows={3} value={outcome} id="outcome" className={`block w-full p-2  rounded-lg text-base bg-[#141F32] border border-gray/30 placeholder-gray text-white focus:outline-none`} />
                                    <p className="text-gray text-center mt-2 px-0.5 text-sm">If you are satisfied, then save it.</p>
                                </div>
                                <div className={`mt-4 grid ${step === STEP.PAGE_1 ? "grid-cols-1" : "grid-cols-2"} gap-2`}>
                                    {step === STEP.PAGE_2
                                        && (
                                            <button onClick={() => dispatch({ outcome: undefined, step: STEP.PAGE_1 })} type="button" className="btn w-full text-base rounded-lg  py-2.5 px-8  cursor-pointer  text-black text-center bg-white hover:bg-white hover:scale-100 hover:text-black    ">
                                                Back
                                            </button>
                                        )
                                    }
                                    <button disabled={loading} onClick={onSave} type="button" className="btn w-full text-base inline-flex justify-center rounded-lg  py-2.5 px-8  cursor-pointer  text-black text-center bg-white hover:bg-white hover:scale-100 hover:text-black   ">
                                        {loading
                                            ?
                                            <Puff
                                                stroke="#000"
                                                className="w-5 h-5"
                                            />
                                            :
                                            <>
                                                Save
                                                <Save />
                                            </>
                                        }
                                    </button>
                                </div>
                            </>
                        )}

                        {errorMessage && (
                            <p className="text-sm text-center mt-2 text-secondary">
                                {errorMessage}
                            </p>
                        )}

                    </Authenticator>
                </View>
            </ThemeProvider>
        </BaseModal>
    )
}

const NewOutcomeModal = ({ visible, close, roundId, marketId, increaseTick }: IMarketModal) => {

    const { currentProfile }: any = useContext(LegatoContext)

    return (
        <BaseModal
            visible={visible}
            close={close}
            title={"Add New Outcome"}
            maxWidth="max-w-xl"
        >
            {currentProfile && (
                <View>
                    <Authenticator>

                        OK Now

                    </Authenticator>
                </View>
            )}
            {!currentProfile && (
                <div className="h-[150px] flex flex-col">
                    <Link href="/auth/profile" className="m-auto">
                        <button type="button" className="btn m-auto mb-0 bg-white text-sm flex rounded-lg px-8 py-3 hover:scale-100  flex-row hover:text-black hover:bg-white ">
                            Sign In
                        </button>
                        <p className="text-center m-auto mt-2 text-gray">You need to sign in to continue</p>
                    </Link>
                </div>
            )

            }
        </BaseModal>
    )
}


export default NewOutcomeModal