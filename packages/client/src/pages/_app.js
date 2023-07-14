
import { WalletProvider } from '@suiet/wallet-kit';
import '@suiet/wallet-kit/style.css';
import '@/styles/globals.css'

export default function App({ Component, pageProps }) {
  return  <WalletProvider><Component {...pageProps} /></WalletProvider>
}
