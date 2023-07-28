// import Image from "next/image"
import { ArrowRight, Clock } from "react-feather"


const HowItWorks = () => {
    return (
        <section className="w-full">
            <div className="container mx-auto flex flex-col items-center py-16 text-center max-w-5xl">
                <div className='bg-black bg-opacity-10   w-full p-8  '>
                    <h2 class="mb-12 text-3xl font-bold">
                        How It Works
                    </h2>
                    <div>
                        <img src="./illustration-1.png" class="w-full md:w-3/4 ml-auto mr-auto" />
                        <p class="text-sm md:text-base text-neutral-500   dark:text-neutral-300">
                            Users lock their yield-bearing tokens into the vault to receive derivative tokens. These derivative tokens represent the future value of the locked assets at the maturity date of the vault. Over time, the vault accrues yield from the underlying protocol, allowing the derivative holder to redeem the original tokens back at a 1:1 ratio at the maturity date.
                        </p>
                    </div>

                </div>
            </div>
        </section>
    )
}

export default HowItWorks