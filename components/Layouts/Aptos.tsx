import { PropsWithChildren } from 'react';
import MainLayout from './Main';

import "@aptos-labs/wallet-adapter-ant-design/dist/index.css";

import { MartianWallet } from "@martianwallet/aptos-wallet-adapter"
import { AptosWalletAdapterProvider } from '@aptos-labs/wallet-adapter-react'
import { BitgetWallet } from "@bitget-wallet/aptos-wallet-adapter";
import { FewchaWallet } from "fewcha-plugin-wallet-adapter";
import { PontemWallet } from "@pontem/wallet-adapter-plugin";
import { MSafeWalletAdapter } from "@msafe/aptos-wallet-adapter";
import { OKXWallet } from "@okwallet/aptos-wallet-adapter";
import { TrustWallet } from "@trustwallet/aptos-wallet-adapter";
import { PetraWallet } from 'petra-plugin-wallet-adapter';

const wallets: any = [
    new BitgetWallet(),
    new FewchaWallet(),
    new MartianWallet(),
    new MSafeWalletAdapter(),
    new PontemWallet(),
    new TrustWallet(),
    new OKXWallet(),
    new PetraWallet()
];

const AptosLayout = ({ children }: PropsWithChildren) => {

    return (
        <AptosWalletAdapterProvider
            plugins={wallets}
            autoConnect={true}
        >
            {children}
        </AptosWalletAdapterProvider>
    )
}

export default AptosLayout