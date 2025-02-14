import 'swiper/css';
import Head from 'next/head';
import Link from 'next/link'; 
import About from '@/components/Home/About';
import Blog from '@/components/Home/Blog';

import dynamic from 'next/dynamic'
 
const Faq = dynamic(() => import('@/components/Home/Faq'), { ssr: false })
const Hero = dynamic(() => import('@/components/Home/Hero'), { ssr: false })

export default function Index() {
    return (
        <div>
             <Head>
                <title>
                    Legato - AI-Powered Prediction Markets for Smarter DeFi
                </title>
            </Head>

            <div className="h-20 bg-black lg:h-[104px]"></div>
            <Hero />
            {/*
            <About />
            <Blog />

            <section className="bg-gradient-to-t from-white to-transparent pb-8 dark:bg-none  ">
                <Faq/>
            </section>  */}

        </div>
    )
}