import BlockchainList from "../../data/blockchain.json"
import AboutCard from "./AboutCard"
import { Activity, CheckCircle, Globe, Server, PlayCircle, MousePointer, ArrowRight, ChevronRight, Grid } from "react-feather"
import Link from "next/link"

const About = () => {
    return (
        <>
            <section className=" py-14 md:py-20">
                <div className="container">
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
                        <div className="col-span-1 lg:col-span-2 flex">
                            <div className="heading my-auto mb-auto text-left mx-4 sm:mx-0 ">
                                <div className='text-secondary text-lg font-bold'>About</div>
                                <h4>What is Legato?</h4>
                                <p className="pt-5 text-base lg:text-xl pr-2 lg:pr-6">
                                    Legato provides DeFi solutions for Move-based blockchains that leverage AI to creating a smarter, more resilient DeFi ecosystem for users.
                                </p>
                                <div className="  mt-[24px] gap-3  ">
                                    <div className='  mt-2 flex  flex-col lg:flex-row'>
                                        <div >
                                            <div className="mt-7 flex justify-center gap-2.5 pr-4">
                                                <div className="text-sm sm:text-base mr-1 mt-auto mb-auto text-white">
                                                    Available on
                                                </div>
                                                <div className='flex flex-row'>
                                                    {BlockchainList.map((item, index) => (<img src={item.image} key={index} alt="" className='w-[30px] sm:w-[40px] mx-1.5' />))}
                                                </div>
                                            </div>
                                        </div>

                                    </div>
                                </div>
                            </div>
                        </div>
                        <div className="relative h-[300px] sm:h-[450px] px-2 sm:px-0" >
                            <div className="absolute block z-[2] top-12 h-full overflow-hidden rounded-2xl rtl:rotate-y-180" data-aos="fade-up" data-aos-duration="1000">
                                <img
                                    src="/assets/images/illustration-about-4.png"
                                    alt=""
                                    className="mx-auto h-full w-full object-cover lg:mx-0"
                                />
                            </div>
                            <div className="relative z-[1] h-full overflow-hidden rounded-2xl rtl:rotate-y-180" data-aos="zoom-in" data-aos-duration="1000">
                                <img
                                    src="/assets/images/about-illustration-1.png"
                                    alt=""
                                    className="mx-auto h-full w-full object-cover lg:mx-0"
                                />
                            </div>
                        </div>
                    </div>
                </div>
            </section>
            <section className="bg-black mt-[40px]  bg-left-top bg-no-repeat py-10 dark:bg-gray-dark lg:py-20">
                <div className="container">
                    <div className="heading my-auto mb-auto text-left mx-4 sm:mx-0 ">
                        <div className='text-secondary text-lg font-bold'>Legato</div>
                        <h4>Prediction Market</h4>
                    </div>
                    <p className="pt-5 text-base sm:text-lg lg:text-xl mx-4 sm:mx-0">
                        Legato's non-custodial prediction market empowers users to create and participate in markets with AI-calculated odds, leveraging real-time data from external sources to sharpen market strategies and increase earnings
                    </p>

                    <div className="w-full mt-[40px] mx-4 sm:mx-0">
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">

                            <AboutCard icon={<PlayCircle size={36} className="text-secondary" />} title="Real-Time Odds" info="Leverage AI to analyze market odds using data from external sources, providing transparent and accurate predictions." />
                            <AboutCard icon={<Grid size={36} className="text-secondary" />} title="Multiple Choices" info="Each market has up to 4 outcome options, giving users flexibility to predict diverse scenarios." />
                            <AboutCard icon={<Server size={36} className="text-secondary" />} title="Seamless Staking Integration" info="Provide liquidity connected to Legato's vault, earning staking rewards while countering all incoming bets." />

                        </div>
                    </div>

                </div>
            </section>

            <section className=" py-14 md:py-20">
                <div className="container">
                    <div className="flex flex-col items-center gap-8 text-left lg:flex-row">
                        <div className="max-w-[500px] flex-1 lg:max-w-none"  >
                            <div className="heading mb-0 mx-4 sm:mx-0  text-left">
                                <div className='text-secondary text-lg font-bold'>
                                    Legato
                                </div>
                                <div className="flex flex-row">
                                    <h4>Liquidity Vault</h4>
                                    <div className="ml-2.5 flex">
                                        <div className="mt-auto mb-[9px]">
                                            {/* <BadgePurple>
                                                New
                                            </BadgePurple> */}
                                        </div>

                                    </div>
                                </div>
                                <p className="pt-5 text-base sm:text-lg lg:text-xl ">
                                    Designed to integrate with each network's validators, empowering liquidity providers to earn even more.
                                </p>
                                <div className=" pt-4 max-w-lg" >
                                    <li className="text-secondary">
                                        <span className=" font-semibold text-lg sm:text-xl ">Intelligent Validator Selection</span>
                                        {/* <p className="text-gray ml-[20px] text-sm sm:text-base">Optimize staking rewards with minimal risk using AI that monitors performance and reliability.</p> */}
                                    </li>
                                    <li className="text-secondary mt-1 sm:mt-2">
                                        <span className=" font-semibold text-lg sm:text-xl ">Non-Custodial and Fully Transparent</span>
                                        {/* <p className="text-gray ml-[20px] text-sm sm:text-base">Maintain full control of your assets while benefiting from automated staking strategies.</p> */}
                                    </li>
                                    <li className="text-secondary mt-1 sm:mt-2">
                                        <span className=" font-semibold text-lg sm:text-xl ">Passive Income for Liquidity Providers</span>
                                        {/* <p className="text-gray ml-[20px] text-sm sm:text-base">Provide liquidity to prediction markets and earn staking rewards while countering market bets.</p> */}
                                    </li>
                                    {/* <Link href={`/vault`}>
                                        <button type="button" className="btn mt-[18px]   bg-secondary/[0.06] text-secondary py-4  hover:bg-secondary/[0.06] hover:text-secondary rounded-xl  flex flex-row">
                                            <div className="ml-2 my-auto">
                                                Stake Now
                                            </div>
                                            <ChevronRight size={18} className='mt-[1px] ml-1' />
                                        </button>
                                    </Link> */}
                                </div>
                            </div>
                        </div>
                        <div className="relative   h-[330px] sm:h-[450px] px-2 sm:px-0 flex justify-center gap-5  lg:block">
                            <div className="relative z-[1] h-full overflow-hidden rounded-2xl rtl:rotate-y-180" data-aos="fade-up" data-aos-duration="1000">
                                <img
                                    src="/assets/images/about-new-illustration-1.png"
                                    alt=""
                                    className="mx-auto h-full w-full object-cover lg:mx-0"
                                />
                            </div>
                        </div>
                    </div>



                </div >

                {/* <div className="container"> 
                    <div className="heading mb-0 mx-4 sm:mx-0  text-center">
                        <div className='text-secondary text-lg font-bold'>
                        How it works
                        </div>
                    </div>
                    <div className="grid grid-cols-1 gap-[30px] md:grid-cols-2 ">
                        <div className="flex flex-col group rounded-xl border-2 border-primary bg-white p-6 px-4 transition   hover:drop-shadow-[-10px_30px_70px_rgba(40,38,77,0.25)] dark:border-white/10 dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.01] dark:to-transparent dark:drop-shadow-none    sm:px-6" data-aos="fade-up" data-aos-duration="1000">
                            <div className="mb-8">
                                <h3 className="text-[22px] font-black text-black dark:text-white">As Bettor</h3>
                            </div>


                        </div>
                        <div className="flex flex-col group rounded-xl border-2 border-primary bg-white p-6 px-4 transition   hover:drop-shadow-[-10px_30px_70px_rgba(40,38,77,0.25)] dark:border-white/10 dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.01] dark:to-transparent dark:drop-shadow-none    sm:px-6" data-aos="fade-up" data-aos-duration="1000">
                            <div className="mb-8">
                                <h3 className="text-[22px] font-black text-black dark:text-white">As Bettor</h3>
                            </div>


                        </div>

                    </div>
                </div> */}

            </section >
        </>
    )
}

export default About