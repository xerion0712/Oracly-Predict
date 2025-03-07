import { ArrowRight, Plus } from 'react-feather';
import Link from 'next/link';
import { useContext, useEffect, useState } from 'react';
import BlockchainList from "../../data/blockchain.json"
import MarketCard from './MarketCard';
import { Swiper, SwiperSlide } from 'swiper/react';
import { secondsToDDHHMMSS, titleToIcon } from '@/helpers';

// Import Swiper styles
import 'swiper/css';
import 'swiper/css/navigation';

// import required modules
import { Autoplay, Navigation } from 'swiper/modules';
import BaseModal from '@/modals/base';
import { LegatoContext } from '@/hooks/useLegato';
import useDatabase from '@/hooks/useDatabase';
import Skeleton  from 'react-loading-skeleton';
 

const Hero = () => {

    const [modal, setModal] = useState<boolean>(false)

    useEffect(() => {
        if (!localStorage.getItem("new_version")) {
            setModal(true)
        }
    }, [])

    return (
        <>
            <BaseModal
                title="🚀 What’s New?"
                visible={modal}
                close={() => setModal(false)}
                maxWidth='max-w-2xl'
            >

                <p className="text-center text-sm sm:text-lg mt-4 mb-4">
                    We've made huge updates to make your prediction experience more fun:
                </p>
                <div className="text-white/70 text-sm sm:text-lg">
                    <li><b>Endlessly Flexible:</b> Propose any outcomes with AI tracking and revealing the results automatically</li>
                    <li><b>Ever-Increasing Payouts:</b> Unclaimed amounts adding to the next round's prize </li>
                    <li><b>Robust AI:</b> With OpenAI GPT-4 and supported by AWS AI Services </li>
                </div>

                <div className='text-center mt-5'>
                    <button onClick={() => {
                        localStorage.setItem("new_version", "true")
                        setModal(false)
                    }} type="button" className="btn rounded-lg  bg-white py-3.5 w-[120px]  hover:text-black hover:bg-white ">
                        close
                    </button>
                </div>
                <p className="text-center mx-auto max-w-full sm:max-w-md text-xs sm:text-sm text-secondary/90 font-semibold mt-4 mb-2  ">
                    This new version is currently available on the Aptos Testnet, with Mainnet and Sui launching soon
                </p>
            </BaseModal>
            <section className="bg-white bg-[url(/assets/images/banner-bg-1.png)]  bg-bottom bg-no-repeat  dark:bg-black">
                <div className="py-24 dark:bg-gradient-to-r dark:from-[#B476E5]/10 dark:to-[#47BDFF]/10 lg:py-32    ">
                    <div className='container'>
                        <div className='mx-2 sm:mx-6  flex'>
                            <div className=' mx-auto'>
                                <h1
                                    className="text-4xl  font-extrabold tracking-tight text-white/80  sm:text-5xl md:text-6xl"
                                    data-aos="fade-up" data-aos-duration="1000"
                                >
                                    <span className="block xl:inline"><span className="mb-1 block">Predict, stake</span>
                                        <span className="bg-gradient-to-r from-secondary/80 to-secondary/40 bg-clip-text text-transparent">
                                            and earn with AI
                                        </span>
                                    </span>
                                    <div className="mt-2">— 10x fun and easy!
                                    </div>
                                </h1>
                            </div>

                        </div>
                        <div className='mx-2 sm:mx-6'>
                            <p className="mt-[20px] sm:mt-[40px] text-center mx-auto mb-[20px] max-w-[700px]   text-sm sm:text-lg lg:text-xl font-normal sm:font-semibold">
                                Legato's AI tracks major trusted sources, letting you propose any future outcomes and earn when you're right
                            </p>
                        </div>
                        <div className='mx-2 sm:mx-4 flex w-full mb-6'>
                            <Link href={`/markets`} className='mx-auto'>
                                <button type="button" className="btn bg-white text-xs sm:text-base flex rounded-lg px-6 py-3 sm:py-4 sm:px-12 flex-row hover:text-black hover:bg-white ">
                                    <div className='my-auto'>
                                        Explore{` `}
                                    </div>
                                    <ArrowRight size={18} className='mt-[3px] ml-1' />
                                </button>
                            </Link>
                        </div>
                    </div>

                    <Highlighted />

                </div>
            </section>
        </>
    )
}


const Highlighted = () => {

    const { getAllOutcomes } = useDatabase()
    const [outcomes, setOutcomes] = useState([])

    useEffect(() => {
        getAllOutcomes().then(setOutcomes)
    }, [])
 
    return (
        <div className="px-6 sm:px-1">

            <div className='text-center text-secondary font-normal  mb-2 sm:mb-4 text-sm sm:text-base tracking-widest'>
                highlighted markets
            </div>

            <Swiper
                spaceBetween={30}
                centeredSlides={false}
                slidesPerView={5}
                autoplay={{
                    delay: 5000,
                    disableOnInteraction: false,
                }}
                loop={false}
                navigation={true}
                modules={[Autoplay, Navigation]}
                className="mySwiper"
                breakpoints={{
                    320: {
                        slidesPerView: 1,
                        spaceBetween: 20,
                    },
                    640: {
                        slidesPerView: 2,
                        spaceBetween: 20,
                    },
                    768: {
                        slidesPerView: 4,
                        spaceBetween: 30,
                    },
                    1024: {
                        slidesPerView: 5,
                        spaceBetween: 30,
                    },
                }}
            >

                { outcomes.length === 0 && (
                    <div className="grid grid-cols-3 gap-5 max-w-5xl mx-auto">
                        <div className='overflow-hidden   opacity-60'>
                            <Skeleton height={120} />
                        </div>
                        <div className='overflow-hidden  opacity-60'>
                            <Skeleton height={120} />
                        </div>
                        <div className='overflow-hidden  opacity-60'>
                            <Skeleton height={120} />
                        </div> 
                    </div>
                ) }


                {outcomes.map((item: any, index: number) => {

                    const icon = titleToIcon(item.title || "")

                    let countdown = "0"

                    const diffTime = (new Date(Number(item.resolutionDate) * 1000)).valueOf() - (new Date()).valueOf()
                    const totals = Math.floor(diffTime / 1000)
                    const { days } = secondsToDDHHMMSS(totals)

                    if (Number(days) > 0) {
                        countdown = `${days}`
                    }


                    return (
                        (
                            <SwiperSlide key={index}>
                                <MarketCard
                                    market_name={item.title}
                                    icon={icon}
                                    popular_outcome={item.totalBetAmount}
                                    close_in={countdown} 
                                />
                            </SwiperSlide>
                        )
                    )
                })}
            </Swiper>

             


        </div>
    )
}

export default Hero