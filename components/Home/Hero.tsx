import { ArrowRight, Plus } from 'react-feather';
import Link from 'next/link';
import { useContext, useEffect, useState } from 'react';
import BlockchainList from "../../data/blockchain.json"
import MarketCard from './MarketCard';
import { Swiper, SwiperSlide } from 'swiper/react';

// Import Swiper styles
import 'swiper/css';
import 'swiper/css/navigation';

// import required modules
import { Autoplay, Navigation } from 'swiper/modules';
import BaseModal from '@/modals/base';
import { LegatoContext } from '@/hooks/useLegato';

const DUMMY_CARDS = [
    {
        market_name: "Who will win the 2024 US election?",
        icon: "/assets/images/us-election-icon.png",
        popular_outcome: "A. Donald Trump",
        close_in: 0,
        tag: "politics",
        chains: ["aptos"]
    },
    {
        market_name: "What will BTC's price be by the end of February 1, 2025?",
        icon: "/assets/images/btc-icon.png",
        popular_outcome: "C. $95,000-$100,000",
        close_in: 4,
        tag: "crypto",
        chains: ["sui", "aptos"]
    },
    {
        market_name: "What top position will SUI hold by market cap by February 2025?",
        icon: "/assets/images/sui-sui-logo.png",
        popular_outcome: "A. Top 10",
        close_in: 10,
        tag: "crypto",
        chains: ["sui"]
    },
    {
        market_name: "What top position will APT hold by market cap by March 2025?",
        icon: "/assets/images/aptos-logo.png",
        popular_outcome: "B. Top 11–20",
        close_in: 10,
        tag: "crypto",
        chains: ["aptos"]
    },
    {
        market_name: "Who will be the winner of the 2025 Six Nations Championship?",
        icon: "https://cdn.britannica.com/44/344-050-94536674/Flag-England.jpg",
        popular_outcome: "B. England",
        close_in: 30,
        tag: "sports",
        chains: ["sui", "aptos"]
    },
    {
        market_name: "Who will be the winner of the 2025 Men's Australian Open?",
        icon: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b9/Flag_of_Australia.svg/2560px-Flag_of_Australia.svg.png",
        popular_outcome: "A. Jannik Sinner",
        close_in: 30,
        tag: "sports",
        chains: ["sui", "aptos"]
    },
    {
        market_name: "What will be Mo Shaikh’s next move after leaving Aptos?",
        icon: "/assets/images/aptos-logo.png",
        popular_outcome: "A. Launch a new project",
        close_in: 100,
        tag: "crypto",
        chains: ["aptos"]
    }
]

const Hero = () => {

    const [modal, setModal] = useState<boolean>(false)
    const { currentNetwork } = useContext(LegatoContext)

    return (
        <>
            <BaseModal
                title="Create New Market"
                visible={modal}
                close={() => setModal(false)}
                maxWidth='max-w-md'
            >
                <p className=" text-base sm:text-lg mt-4 mb-4">
                    User-generated market creation is not available yet. Stay tuned for updates and be the first to launch your own market.
                </p>
                <div className='text-center'>
                    <button onClick={() => setModal(false)} type="button" className="btn rounded-lg  bg-white py-3.5 w-[120px]  hover:text-black hover:bg-white ">
                        close
                    </button>
                </div>
            </BaseModal>
            <section className="bg-white bg-[url(/assets/images/banner-bg-1.png)]  bg-bottom bg-no-repeat  dark:bg-black">
                <div className="py-24 dark:bg-gradient-to-r dark:from-[#B476E5]/10 dark:to-[#47BDFF]/10 lg:py-32    ">
                    <div className='container'>
                        <div className='mx-2 sm:mx-6  '>
                            <h1
                                className="text-4xl font-extrabold tracking-tight text-white/80  sm:text-5xl md:text-6xl"
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
                        <div className='mx-2 sm:mx-6'>
                            <p className="mt-[20px] sm:mt-[40px] mb-[20px] max-w-[900px]   text-sm sm:text-lg lg:text-xl font-normal sm:font-semibold">
                                Legato is a decentralized protocol on Move-based blockchains that enables users to predict markets, stake assets for smarter, faster decisions powered by AI
                            </p>
                        </div>
                    </div>
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
                            {DUMMY_CARDS.map((item, index) => (
                                <SwiperSlide key={index}>
                                    <MarketCard
                                        market_name={item.market_name}
                                        icon={item.icon}
                                        popular_outcome={item.popular_outcome}
                                        close_in={item.close_in}
                                        chains={item.chains}
                                        tag={item.tag}
                                    />
                                </SwiperSlide>
                            ))}
                        </Swiper>

                        <div className='mx-2 sm:mx-6 flex mt-[20px] sm:mt-[40px]'>
                            <div className='flex flex-row  container'>
                                <div className='mx-2 sm:mx-4'>
                                    <Link href={`/markets/${currentNetwork}`}>
                                        <button type="button" className="btn bg-white text-xs sm:text-base flex rounded-lg px-6 py-3 sm:py-4 sm:px-12 flex-row hover:text-black hover:bg-white ">
                                            <div className='my-auto'>
                                                Explore{` `}
                                            </div>
                                            <ArrowRight size={18} className='mt-[3px] ml-1' />
                                        </button>
                                    </Link>
                                </div>
                                <div className=' '>
                                    <Link href="/auth/my-markets">
                                        <button type="button" className="btn bg-white text-xs sm:text-base flex rounded-lg px-6 py-3 sm:py-4 sm:px-12 flex-row hover:text-black hover:bg-white ">
                                            <div className='my-auto'>
                                                New Market{` `}
                                            </div>
                                            <Plus size={18} className='mt-[3px] ml-1' />
                                        </button>
                                    </Link> 
                                </div>

                                {/* <div className='my-auto flex'>
                                <div className=" flex  flex-row  mx-auto my-auto  ">
                                    <div className="text-xs sm:text-sm mt-auto mb-auto text-white">
                                        Available on
                                    </div>
                                    <div className='flex flex-row mt-0.5 sm:mt-0 ml-0 sm:ml-2'>
                                        {BlockchainList.map((item, index) => (<img src={item.image} key={index} alt="" className='w-[20px] sm:w-[30px] mx-0.5 sm:mx-1' />))}
                                    </div>
                                </div>
                            </div> */}
                            </div>
                        </div>

                        {/* <div className='my-[10px] sm:my-[30px] mx-2 sm:mx-6 flex'>
                        <div className='flex flex-col mx-auto'>
                            <div className='mx-auto '>
                                <Link href={`/markets`}>
                                    <button type="button" className="btn bg-white text-xs sm:text-base flex rounded-lg px-8 py-3 sm:py-4 sm:px-12 flex-row hover:text-black hover:bg-white ">
                                        <div className='my-auto'>
                                            Explore{` `}
                                        </div>
                                        <ArrowRight size={18} className='mt-[3px] ml-1' />
                                    </button>
                                </Link>
                            </div>
                            <div className='mx-auto mt-2 sm:mt-4 flex'>
                                <div className=" flex flex-col sm:flex-row  mx-auto my-auto  ">
                                    <div className="text-xs sm:text-sm mt-auto mb-auto text-white">
                                        Available on
                                    </div>
                                    <div className='flex flex-row mt-0.5 sm:mt-0 ml-0 sm:ml-2'>
                                        {BlockchainList.map((item, index) => (<img src={item.image} key={index} alt="" className='w-[20px] sm:w-[30px] mx-0.5 sm:mx-1' />))}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="mt-[20px]  max-w-[600px] mx-auto gap-3 grid grid-cols-3">
                        <div className=" p-4 border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg " >
                            <p className="text-sm font-semibold">
                                ROI
                            </p>
                            <div className="flex justify-between  text-white">
                                <div className="text-lg sm:text-2xl my-auto  font-bold">125%</div>
                            </div>
                        </div>
                        <div className="  p-4 border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg  " >
                            <p className="  text-sm font-semibold">
                                TVL
                            </p>
                            <div className="flex justify-between  text-white">
                                <div className="text-lg sm:text-2xl my-auto  font-bold">{`<$10k`}</div>
                            </div>
                        </div>
                        <div className="  p-4 border-2 border-white/[0.1] bg-transparent bg-gradient-to-b from-white/5 to-transparent rounded-lg  " >
                            <p className=" text-sm font-semibold">
                                Trades
                            </p>
                            <div className="flex justify-between  text-white">
                                <div className="text-lg sm:text-2xl my-auto  font-bold">100+</div>
                            </div>
                        </div>
                    </div> */}
                    </div>
                </div>
            </section>
        </>
    )
}

export default Hero