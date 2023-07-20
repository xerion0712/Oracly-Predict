
import { Plus, Clock, Calendar, CheckCircle } from "react-feather"

const About = () => {
    return (
        <div id="about" class="container max-w-5xl my-24 mx-auto">
            <section class="mb-32 text-center">
                <h2 class="mb-16 text-3xl font-bold">
                    Why Legato?
                </h2>
                <div class="grid gap-x-6 md:grid-cols-3 lg:gap-x-12">
                    <div class="mb-12 md:mb-0">
                        <div class="mb-6 inline-block rounded-md bg-primary-100 p-2 text-primary">
                            <Clock size={48} />
                        </div>
                        <h5 class="mb-4 text-lg font-bold">Trade Future Yield</h5>
                        <p class="text-neutral-500 dark:text-neutral-300">
                            Allowing users to lock SuiStaked objects as collateral for vault tokens which can then be sold along with future yield to obtain additional Sui tokens
                        </p>
                    </div>

                    <div class="mb-12 md:mb-0">
                        <div class="mb-6 inline-block rounded-md bg-primary-100 p-2 text-primary">
                            <Calendar size={48} />
                        </div>
                        <h5 class="mb-4 text-lg font-bold">Fixed Maturity Date</h5>
                        <p class="text-neutral-500 dark:text-neutral-300">
                            Vaults are designed with specific maturity dates allowing for the redemption of StakedSui tokens at market rates through a stateless Oracle
                        </p>
                    </div>

                    <div class="mb-12 md:mb-0">
                        <div class="mb-6 inline-block rounded-md bg-primary-100 p-2 text-primary">
                            <CheckCircle size={48} />
                        </div>
                        <h5 class="mb-4 text-lg font-bold">Sui Move-Native</h5>
                        <p class="text-neutral-500 dark:text-neutral-300">
                            Natively built on Sui, aims to support any Sui-based assets that can benefit from time-bound functionalities and enhanced yield opportunities
                        </p>
                    </div>
                </div>
            </section>
            {/* <div className='bg-black bg-opacity-10 backdrop-blur-lg  drop-shadow-lg p-4 border-2'>
                <div class="grid grid-cols-3 gap-3">
                    <div className="col-span-2">
                        <p className="px-8 mt-8 mb-8 font-bold text-2xl">Follow us for updates </p>
                    </div>
                    <div className="col-span-1 flex text-sm">
                    <div className="text-sm mt-auto mb-auto ml-auto mr-8"> 
                        <a className="mr-5 hover:underline" href="https://twitter.com/pisuthd" target="_blank">Twitter</a>{` `}
                        <a className="hover:underline" href="https://github.com/pisuthd/legato-finance" target="_blank">GitHub</a>
                    </div>
                    </div>
                </div>
            </div> */}
        </div>
    )
}

export default About