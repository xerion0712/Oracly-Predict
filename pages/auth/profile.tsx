import Head from 'next/head';

import dynamic from 'next/dynamic'

const ProfileContainer = dynamic(() => import('@/components/Profile'), { ssr: false })

const ProfilePage = () => {
    return (
        <div>
            <Head>
                <title>Legato | Profile</title>
            </Head>
            <section className="dark: relative py-12 lg:py-24 min-h-[90vh]  bg-[url(/assets/images/modern-saas/banner-bg.png)] bg-cover bg-center bg-no-repeat">
                <div className="container pt-6 lg:pt-4  mb-[40px]">
                    <ProfileContainer />
                </div>
            </section>
        </div>
    )
}

export default ProfilePage