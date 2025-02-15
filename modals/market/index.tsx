import { useContext, useReducer, useEffect, useState, useCallback } from "react"
import BaseModal from "../base"
import { Authenticator, useTheme, View, Heading, Image, Text, Button, ThemeProvider, Theme } from '@aws-amplify/ui-react'
import '@aws-amplify/ui-react/styles.css'
import { useRouter } from 'next/router';

import ReviewAptos from "./reviewAptos"
import ReviewSui from "./reviewSui"

import {
    Flex,
    Loader,
    TextAreaField,
} from "@aws-amplify/ui-react";

import { generateClient } from "aws-amplify/api";
import { createAIHooks } from "@aws-amplify/ui-react-ai";
import { Schema } from "../../amplify/data/resource"

const client = generateClient<Schema>({ authMode: "apiKey" });
const { useAIConversation, useAIGeneration } = createAIHooks(client);


interface IMarketModal {
    visible: boolean
    close: () => void
    currentMarket: any
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


const MarketDetailsModal = ({ visible, close, currentMarket }: IMarketModal) => {

    const [selected, setSelected] = useState(0)

    useEffect(() => {

        if (currentMarket && currentMarket.outcomeId) {
            const { outcomeId } = currentMarket
            setSelected(outcomeId)
        }

    }, [currentMarket])

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

    const title = currentMarket ? currentMarket.title : ""

    const router = useRouter()

    const isSui = router.pathname.includes("sui")
    const isAptos = router.pathname.includes("aptos")


    const [description, setDescription] = useState("");
 

    return (
        <BaseModal
            visible={visible}
            close={close}
            title={title}
            maxWidth="max-w-6xl"
        >
            <ThemeProvider theme={theme} >
                <View>
                    <Authenticator components={components} >

                        {currentMarket && (
                            <div className="grid grid-cols-5">

                                <div className="col-span-3 flex flex-col">

                                    <div className="pt-2 pr-2">
                                        <h2 className="text-xl">{currentMarket.description}</h2>

                                        <div className="grid grid-cols-2 gap-3 pt-4 pr-2">
                                            {currentMarket.outcomes.map((item: any, index: number) => {

                                                let letter = "?"
                                                let active = false

                                                switch (index) {
                                                    case 0:
                                                        letter = "A"
                                                        active = selected === 1
                                                        break;
                                                    case 1:
                                                        letter = "B"
                                                        active = selected === 2
                                                        break;
                                                    case 2:
                                                        letter = "C"
                                                        active = selected === 3
                                                        break;
                                                    case 3:
                                                        letter = "D"
                                                        active = selected === 4
                                                        break;
                                                    default:
                                                        break;
                                                }

                                                return (
                                                    <div key={`modal-outcome-${index}`}>
                                                        <button onClick={() => setSelected(index + 1)} className={`flex w-full items-start gap-[10px] rounded-[10px] border  py-2 px-4  cursor-pointer  ${active ? "bg-transparent border-secondary" : "border-transparent bg-secondary/10"}  `}>
                                                            <Square content={letter} />
                                                            <div className='my-auto  mr-2 sm:mr-0'>
                                                                <h6 className=" font-semibold text-sm  text-white">
                                                                    {item}
                                                                </h6>
                                                            </div>
                                                        </button>
                                                    </div>
                                                )
                                            })}
                                        </div> 
                                    </div> 
                                </div>

                                <div className="col-span-2">
                                    {isSui && <ReviewSui />}
                                    {isAptos && <ReviewAptos />}
                                </div>

                            </div>
                        )}

                    </Authenticator>
                </View>
            </ThemeProvider>
        </BaseModal>
    )
}


const Square = ({ content }: any) => (
    <span className=" flex h-[25px] w-[25px] min-w-[25px] items-center justify-center my-auto rounded-[8px] bg-secondary font-semibold text-sm text-white">
        {content}
    </span>
)

// const Outcome = ({ market, letter, text, active, resolved, won, select, outcomeId, setSelected }: any) => {

//     return (
//         <div 
//             onClick={() => {
//                 setSelected(outcomeId)
//             }}
//             className={` flex items-start gap-[10px] rounded-[10px] border border-transparent   py-2 px-4  
//             cursor-pointer bg-secondary/10 hover:border-secondary hover:bg-transparent ${active && "border-secondary/100 bg-transparent "}
//              `}
//         >
//             <Square content={letter} />
//             <div className='w-[40%] my-auto  mr-2 sm:mr-0'>
//                 <h6 className=" font-semibold text-sm  text-white">
//                     {text}
//                 </h6>
//             </div> 
//         </div>
//     )
// }

export default MarketDetailsModal