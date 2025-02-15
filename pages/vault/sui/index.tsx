import Head from 'next/head';

import dynamic from 'next/dynamic'
 
const VaultSuiContainer = dynamic(() => import('@/components/Vault/Sui'), { ssr: false })

const VaultPage = () => {
    return (
        <div> 
            <Head>
                <title>Legato | Vault</title>
            </Head>
            <section className="dark: relative py-12 lg:py-24 min-h-[90vh]  bg-[url(/assets/images/modern-saas/banner-bg.png)] bg-cover bg-center bg-no-repeat">
                <div className="container pt-6 lg:pt-4  mb-[40px]"> 
                    <VaultSuiContainer/>
                </div>
            </section>
        </div>
    )
}

export default VaultPage