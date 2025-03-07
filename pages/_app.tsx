import "@/styles/tailwind.css";
import type { AppProps } from "next/app";
import { Amplify } from "aws-amplify";
import outputs from "@/amplify_outputs.json";
import "@aws-amplify/ui-react/styles.css";
import 'react-loading-skeleton/dist/skeleton.css'

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
import { SkeletonTheme } from 'react-loading-skeleton';

Amplify.configure(outputs);

export default function App({ Component, pageProps }: AppProps) {

  return (
    <Suspense>
      <Head>
        <title>
          Legato - The Most Interactive AI-Powered Prediction Markets
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
            {/* <SuiLayout> */}
              <AptosLayout>
                <MainLayout>
                <SkeletonTheme baseColor="#141F32" highlightColor="#444">
                  <Component {...pageProps} />
                  </SkeletonTheme>
                </MainLayout>
              </AptosLayout>
            {/* </SuiLayout> */}
          </TxProvider>
        </LegatoProvider>
      </AuthProvider> 
    </Suspense>
  )
}
