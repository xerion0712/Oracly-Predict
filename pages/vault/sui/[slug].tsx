

import Head from 'next/head';
import WithWalletPanel from "../../../components/Layouts/WithWallet"
import dynamic from 'next/dynamic'
import { useRouter } from "next/router"
import VaultList from "../../../data/vault.json"
import { slugify } from '@/helpers';

const VaultSuiContainer = dynamic(() => import('../../../components/Vault/Sui'), { ssr: false })

const VaultSui = () => {

    const router = useRouter()

    const { slug } = router.query

    const vault = (VaultList.find(item => item.network === "sui"))?.vaults.find(item => slugify(item.name) === slug)

    const title1 = vault?.name.split(" ")[0]
    const title2 = vault?.name.split(title1 || " ")[1]

    return (
        <div>
            <Head>
                <title>Legato | {vault?.name}</title>
            </Head>

            <section className="dark: relative py-12 lg:py-24 min-h-[90vh]  bg-[url(/assets/images/modern-saas/banner-bg.png)] bg-cover bg-center bg-no-repeat">
                <div className="container pt-6 lg:pt-4">
                    <WithWalletPanel
                        pageName="vault"
                        title1={title1 || ""}
                        title2={title2 || ""}
                        info={ vault?.description || "" }
                        href={"/vault"}
                    >
                        <VaultSuiContainer />
                    </WithWalletPanel>
                </div>
            </section>

        </div>
    )
}

export default VaultSui