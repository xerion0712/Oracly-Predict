import "@/styles/tailwind.css";
import type { AppProps } from "next/app";
import { Amplify } from "aws-amplify";
import outputs from "@/amplify_outputs.json";
import "@aws-amplify/ui-react/styles.css";

import { GoogleAnalytics } from '@next/third-parties/google'
import { Suspense } from 'react';
import Head from 'next/head';
import { useRouter } from 'next/router';
import TxProvider from "../hooks/useTx"
import LegatoProvider from "@/hooks/useLegato";
import SuiLayout from "@/components/Layouts/Sui";
import AptosLayout from "@/components/Layouts/Aptos";
import MainLayout from "@/components/Layouts/Main";
import AuthProvider from "@/hooks/useAuth";

Amplify.configure(outputs);

// export default function App({ Component, pageProps }: AppProps) {

//   const router = useRouter()

//   const isSui = router.pathname.includes("sui")
//   const isAptos = router.pathname.includes("aptos")
//   const isLanding = !isSui && !isAptos

//   return (
//     <Suspense>
//       <Head>
//         <title>
//           Legato - AI-Powered Prediction Markets for Smarter DeFi
//         </title>
//         <meta charSet="UTF-8" />
//         <meta
//           name="description"
//           content="Legato provides AI-powered DeFi solutions on the MoveVM, including a prediction market, decentralized exchange (DEX), and a liquid staking system for Aptos and Sui blockchains."
//         />
//         <meta
//           name="keywords"
//           content="AI DeFi, polymarket, market prediction, blockchain finance, Aptos, Sui, Aptos DeFi, MoveVM, Sui staking, MoveVM blockchain, decentralized prediction market, liquid staking, crypto staking rewards, DeFi protocols, decentralized finance solutions, blockchain-powered prediction markets"
//         />
//         <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
//         <meta name="viewport" content="width=device-width, initial-scale=1.0" />
//       </Head>
//       <GoogleAnalytics gaId="G-QNBVXZZR9E" />
//       <AuthProvider>
//         <LegatoProvider> 
//           <TxProvider>
//             {isSui && (
//               <SuiLayout>
//                 <Component {...pageProps} />
//               </SuiLayout>
//             )}
//             {isAptos && (
//               <AptosLayout>
//                 <Component {...pageProps} />
//               </AptosLayout>
//             )}
//             {isLanding && (
//               <MainLayout>
//                 <Component {...pageProps} />
//               </MainLayout>
//             )}
//           </TxProvider>
//         </LegatoProvider>
//       </AuthProvider>

//     </Suspense>
//   )
// }



export default function App({ Component, pageProps }: AppProps) {

  return (
    <Suspense>
      <Head>
        <title>
          Legato - AI-Powered Prediction Markets for Smarter DeFi
        </title>
        <meta charSet="UTF-8" />
        <meta
          name="description"
          content="Legato provides AI-powered DeFi solutions on the MoveVM, including a prediction market, decentralized exchange (DEX), and a liquid staking system for Aptos and Sui blockchains."
        />
        <meta
          name="keywords"
          content="AI DeFi, polymarket, market prediction, blockchain finance, Aptos, Sui, Aptos DeFi, MoveVM, Sui staking, MoveVM blockchain, decentralized prediction market, liquid staking, crypto staking rewards, DeFi protocols, decentralized finance solutions, blockchain-powered prediction markets"
        />
        <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      </Head>
      <GoogleAnalytics gaId="G-QNBVXZZR9E" />
      <AuthProvider>
        <LegatoProvider>
          <TxProvider>
            <SuiLayout>
              <AptosLayout>
                <MainLayout>
                  <Component {...pageProps} />
                </MainLayout>
              </AptosLayout>
            </SuiLayout>
          </TxProvider>
        </LegatoProvider>
      </AuthProvider> 
    </Suspense>
  )
}
