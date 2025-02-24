 
import { ReactNode } from "react"
import { Authenticator, useTheme, View, Heading, Image, Text, Button, ThemeProvider, Theme } from '@aws-amplify/ui-react'
import '@aws-amplify/ui-react/styles.css'
import { useRouter } from "next/router"
import Link from "next/link"
 

type Props = {
    children: ReactNode
}
 
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
 
};

const Wrapper = ({ children }: Props) => {

    const { tokens } = useTheme();

     
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