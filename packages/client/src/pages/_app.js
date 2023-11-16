
import { WalletProvider } from '@suiet/wallet-kit';
import LegatoProvider from "../hooks/useLegato"
import ModalProvider from "../hooks/useModal"

import '@suiet/wallet-kit/style.css';
import '@/styles/globals.css'

export default function App({ Component, pageProps }) {
  return (
    <WalletProvider>
      <LegatoProvider>
        <ModalProvider>
          <Component {...pageProps} />
        </ModalProvider>
      </LegatoProvider>
    </WalletProvider>
  )
}
