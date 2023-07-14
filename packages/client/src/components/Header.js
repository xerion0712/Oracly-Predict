
import Image from 'next/image'
import { ExternalLink } from 'react-feather'

const Header = () => {
    return (
        <div class="grid grid-cols-2 gap-3 px-2 mt-4 mb-4">
            <div class="col-span-1 flex flex-col">
                <div class="text-3xl w-full text-white font-bold flex flex-row">
                    <Image
                        src="/logo.png"
                        width={60}
                        height={60}
                        alt="Logo"
                    />
                </div>
            </div>
            <div class="col-span-1 flex flex-col text-right">
                {/* <button onClick={() => alert("hello...")} class="text-gray-900 mx-auto bg-white border border-gray-300 flex flex-row focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm px-5 py-2.5 mt-2 mr-0 dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700">
                    <ExternalLink size={18} className="mr-2" />
                    Launch App
                </button> */}
            </div>
        </div>
    )
}

export default Header