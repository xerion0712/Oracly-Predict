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
                maxWidth='max-w-xl'
            >

                <p className="text-center text-sm sm:text-lg mt-4 mb-4">
                    We've made huge updates to make your prediction experience more fun and rewarding:
                </p>
                <div className="text-white/70 text-sm sm:text-lg">
                    <li><b>Endlessly Flexible:</b> Propose any outcomes with AI tracking and revealing the results automatically</li>
                    <li><b>Ever-Increasing Payouts:</b> Unclaimed amounts adding to the next round's prize </li>
                    <li><b>With DeepSeek R1:</b> Via Atoma’s Decentralized AI Network </li>
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
                                Legato's AI tracks major trusted sources, letting you propose future outcomes and earn rewards when you're right
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
                                    <Link href={`/markets`}>
                                        <button type="button" className="btn bg-white text-xs sm:text-base flex rounded-lg px-6 py-3 sm:py-4 sm:px-12 flex-row hover:text-black hover:bg-white ">
                                            <div className='my-auto'>
                                                Explore{` `}
                                            </div>
                                            <ArrowRight size={18} className='mt-[3px] ml-1' />
                                        </button>
                                    </Link>
                                </div>
                                {/* <div className=' '>
                                    <button type="button" className="btn bg-secondary  text-white text-xs sm:text-base flex rounded-lg px-6 py-3 sm:py-4 sm:px-12 flex-row hover:text-black hover:bg-white ">
                                        <div className='my-auto'>
                                            Learn More{` `}
                                        </div> 
                                    </button>
                                </div> */}

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