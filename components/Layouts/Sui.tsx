import { PropsWithChildren } from 'react';
import MainLayout from './Main';

import '@suiet/wallet-kit/style.css';

import { WalletProvider } from '@suiet/wallet-kit';

const SuiLayout = ({ children }: PropsWithChildren) => {

    return (
        <WalletProvider>
            <MainLayout>
                {children}
            </MainLayout>
        </WalletProvider>
    )
}

export default SuiLayout