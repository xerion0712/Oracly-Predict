import dynamic from 'next/dynamic'

const Tabs = dynamic(() => import('./Tabs'), { ssr: false })


const Features = () => {
    return (
        <section className=" py-14 md:py-20">

            <div className="container">
                <div className="heading my-auto max-w-3xl mx-auto text-center  ">
                    <div className='text-secondary text-lg font-bold'>
                        See In Action
                    </div>
                    <h4>
                        Anything You Predict, AI Optimizes
                    </h4>
                    <p className="pt-3 sm:pt-5 text-sm sm:text-base lg:text-xl  ">
                        Legato AI-Agent refines your predictions with real-time data,
                        ensuring smarter actions and fairer outcomes in every market round
                    </p>
                </div>
 
                <Tabs /> 
            </div>

        </section>
    )
}

export default Features