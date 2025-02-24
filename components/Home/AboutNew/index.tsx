
import AboutCard from "../AboutCard"
import { Activity, CheckCircle, Globe, Server, PlayCircle, MousePointer, ArrowRight, ChevronRight, Grid } from "react-feather"
import Link from "next/link"

const About = () => {
    return (
        <section className="bg-black mt-[40px]  bg-left-top bg-no-repeat py-10 dark:bg-gray-dark lg:py-20">
            <div className="container">
                <div className="heading my-auto mb-auto text-left mx-4 sm:mx-0 ">
                    <div className='text-secondary text-lg font-bold'>Why Choose Us?</div>
                    <h4>Community-Powered Predictions</h4>
                </div>
                <p className="pt-5 text-base sm:text-lg lg:text-xl mx-4 sm:mx-0">
                    With a decentralized, AI-backed approach, anyone can contribute and influence the next prediction, fostering a collaborative environment for all participants
                </p>

                <div className="w-full mt-[40px] mx-4 sm:mx-0">
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">

                        <AboutCard icon={<CheckCircle size={36} className="text-secondary" />} title="Transparent & Fair" info="AI-Agent eliminates bias and ensures fair market odds" />
                        <AboutCard icon={<Grid size={36} className="text-secondary" />} title="Secure & Non-Custodial" info="Your funds remain in smart contracts, ensuring full control and security" />
                        <AboutCard icon={<Globe size={36} className="text-secondary" />} title="Data-Backed Insights" info="Predictions fueled by real-world market data" />

                    </div>
                </div>

            </div>
        </section>
    )
}

export default About