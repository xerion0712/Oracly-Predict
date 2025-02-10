import Link from "next/link"
import { ArrowRight } from "react-feather"

const Promo = () => {
    return (
        <Link href="/auth/my-markets">
            <div className='p-2 sm:p-4 group grid grid-cols-5 mx-auto py-4 sm:py-6 w-full max-w-3xl cursor-pointer   border-gray/20  mt-[15px] border-[1px] rounded-lg bg-[url(/assets/images/consulting/business-img.png)] bg-cover bg-center bg-no-repeat '>
                <div className="flex flex-col col-span-4 pl-4">
                    <h2 className="text-left  font-semibold text-white text-2xl mb-1">
                        Want to Create Your <span className="text-secondary">Own Market?</span>
                    </h2>
                    <p className="text-sm sm:text-base text-muted text-left  ">
                        Create your custom market in a few steps with AI assistance and and earn shared fees with Legato
                    </p>
                </div>
                <div className="col-span-1 flex pt-4">
                    <div className="text-secondary p-2 uppercase font-semibold text-sm flex flex-row m-auto">
                        <span className="mr-1 hidden sm:block">Create Now </span>
                        <ArrowRight size={18} className="duration-300 ml-0.5 group-hover:translate-x-2 rtl:rotate-180 text-secondary rtl:group-hover:-translate-x-2" />
                    </div>
                </div>

            </div>
        </Link>

    )
}

export default Promo