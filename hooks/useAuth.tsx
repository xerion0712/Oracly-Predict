// import { createContext, useCallback, ReactNode, useContext, useEffect, useMemo, useReducer, useState } from "react"

import { ReactNode } from "react"
import { Authenticator, useTheme, View, Heading, Image, Text, Button, ThemeProvider, Theme } from '@aws-amplify/ui-react'
import '@aws-amplify/ui-react/styles.css'
import { useRouter } from "next/router"
import Link from "next/link"

// type authContextType = {

// }

// const authContextDefaultValues: authContextType = {

// }

type Props = {
    children: ReactNode
}

// export const AuthContext = createContext<authContextType>(authContextDefaultValues)


// const Provider = ({ children }: Props) => {

//     const [values, dispatch] = useReducer(
//         (curVal: any, newVal: any) => ({ ...curVal, ...newVal }),
//         {

//         }
//     )

//     const { } = values


//     const authContext: any = useMemo(
//         () => ({

//         }),
//         [

//         ]
//     )

//     return (
//         <AuthContext.Provider value={authContext}>
//             {children}
//         </AuthContext.Provider>
//     )
// }

const components = {
    Header() {
        const { tokens } = useTheme();

        return (
            <View textAlign="center" padding={tokens.space.large}>
                <Link href="/">
                    <Image
                        alt="Legato logo"
                        src="https://www.legato.finance/assets/images/logo-legato-3.png"
                    />
                </Link>

            </View>
        );
    },
    Footer() {
        const { tokens } = useTheme();

        return (
            <View textAlign="center" padding={tokens.space.large}>
                <Text color={tokens.colors.neutral[80]}>
                    <span className='hidden md:inline-flex'>Copyright</span>© {new Date().getFullYear() + ' '}
                    <Link href="https://legato.finance" className=" underline transition text-secondary  ">
                        Legato
                    </Link>
                </Text>
            </View>
        );
    },

    // SignIn: {
    //     Header() {
    //         const { tokens } = useTheme();

    //         return (
    //             <Heading
    //                 padding={`${tokens.space.xl} 0 0 ${tokens.space.xl}`}
    //                 level={3}
    //             >
    //                 Sign in to your account
    //             </Heading>
    //         );
    //     },
    //     Footer() {
    //         const { toForgotPassword } = useAuthenticator();

    //         return (
    //             <View textAlign="center">
    //                 <Button
    //                     fontWeight="normal"
    //                     onClick={toForgotPassword}
    //                     size="small"
    //                     variation="link"
    //                 >
    //                     Reset Password
    //                 </Button>
    //             </View>
    //         );
    //     },
    // },

    // SignUp: {
    //     Header() {
    //         const { tokens } = useTheme();

    //         return (
    //             <Heading
    //                 padding={`${tokens.space.xl} 0 0 ${tokens.space.xl}`}
    //                 level={3}
    //             >
    //                 Create a new account
    //             </Heading>
    //         );
    //     },
    //     Footer() {
    //         const { toSignIn } = useAuthenticator();

    //         return (
    //             <View textAlign="center">
    //                 <Button
    //                     fontWeight="normal"
    //                     onClick={toSignIn}
    //                     size="small"
    //                     variation="link"
    //                 >
    //                     Back to Sign In
    //                 </Button>
    //             </View>
    //         );
    //     },
    // },
    // ConfirmSignUp: {
    //     Header() {
    //         const { tokens } = useTheme();
    //         return (
    //             <Heading
    //                 padding={`${tokens.space.xl} 0 0 ${tokens.space.xl}`}
    //                 level={3}
    //             >
    //                 Enter Information:
    //             </Heading>
    //         );
    //     },
    //     Footer() {
    //         return <Text>Footer Information</Text>;
    //     },
    // },
    // SetupTotp: {
    //     Header() {
    //         const { tokens } = useTheme();
    //         return (
    //             <Heading
    //                 padding={`${tokens.space.xl} 0 0 ${tokens.space.xl}`}
    //                 level={3}
    //             >
    //                 Enter Information:
    //             </Heading>
    //         );
    //     },
    //     Footer() {
    //         return <Text>Footer Information</Text>;
    //     },
    // },
    // ConfirmSignIn: {
    //     Header() {
    //         const { tokens } = useTheme();
    //         return (
    //             <Heading
    //                 padding={`${tokens.space.xl} 0 0 ${tokens.space.xl}`}
    //                 level={3}
    //             >
    //                 Enter Information:
    //             </Heading>
    //         );
    //     },
    //     Footer() {
    //         return <Text>Footer Information</Text>;
    //     },
    // },
    // ForgotPassword: {
    //     Header() {
    //         const { tokens } = useTheme();
    //         return (
    //             <Heading
    //                 padding={`${tokens.space.xl} 0 0 ${tokens.space.xl}`}
    //                 level={3}
    //             >
    //                 Enter Information:
    //             </Heading>
    //         );
    //     },
    //     Footer() {
    //         return <Text>Footer Information</Text>;
    //     },
    // },
    // ConfirmResetPassword: {
    //     Header() {
    //         const { tokens } = useTheme();
    //         return (
    //             <Heading
    //                 padding={`${tokens.space.xl} 0 0 ${tokens.space.xl}`}
    //                 level={3}
    //             >
    //                 Enter Information:
    //             </Heading>
    //         );
    //     },
    //     Footer() {
    //         return <Text>Footer Information</Text>;
    //     },
    // },
};

const Wrapper = ({ children }: Props) => {

    const { tokens } = useTheme();

    // const theme: Theme = {
    //     name: 'Auth Theme',
    //     tokens: {
    //         components: {
    //             authenticator: {
    //                 router: {
    //                     boxShadow: `0 0 16px ${tokens.colors.overlay['10']}`,
    //                     borderWidth: '0',
    //                     backgroundColor: "#141F32"
    //                 }
    //             },
    //             heading: {
    //                 color:"white"
    //             },
    //             button: {
    //                 primary: {
    //                     backgroundColor: "white",
    //                     color: tokens.colors.neutral['100'],
    //                     _hover: {
    //                         backgroundColor: "white",
    //                         color: tokens.colors.neutral['100']
    //                     },
    //                     _active: {
    //                         backgroundColor: "white",
    //                         color: tokens.colors.neutral['100']
    //                     }
    //                 },
    //                 link: {
    //                     color: "#B476E5",
    //                 },
    //             }, 
    //             fieldcontrol: {
    //                 color: tokens.colors.neutral['60'],
    //                 _focus: {
    //                     boxShadow: `0 0 0 2px ${tokens.colors.neutral['60']}`,
    //                 }
    //             },
    //             passwordfield: {
    //                 button: {
    //                     color: tokens.colors.neutral['60'],
    //                 },

    //             },
    //             tabs: {
    //                 item: {
    //                     color: tokens.colors.neutral['80'],
    //                     borderColor: "#08111566",
    //                     backgroundColor: "#08111566",
    //                     _active: {
    //                         borderColor: "#B476E5",
    //                         color: "white"
    //                     },
    //                     _hover: {
    //                         color: "white"
    //                     }
    //                 },
    //             },
    //         },
    //     },
    // };

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
    };

    const router = useRouter()

    const isAuth = router.pathname.includes("auth")

    if (isAuth) {
        return (
            <ThemeProvider theme={theme} >
                <View backgroundColor={"#08111F"} className="min-h-screen">
                    <Authenticator components={components} >
                        {children}
                    </Authenticator>
                </View>
            </ThemeProvider>
        )
    } else {
        return (
            <>
                {children}
            </>
        )
    }
}

export default Wrapper