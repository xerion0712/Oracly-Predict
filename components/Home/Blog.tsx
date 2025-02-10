import { Swiper, SwiperSlide } from 'swiper/react';
import Link from 'next/link';

// Import Swiper styles
import 'swiper/css';
import 'swiper/css/navigation';

// import required modules
import { Autoplay, Navigation } from 'swiper/modules';

const DATA: any[] = [
    {
        id: 9,
        thumbnail: 'https://miro.medium.com/v2/resize:fit:720/format:webp/1*HXZrST01F_HXQTRLomzFWg.png',
        title: 'Fractional Exponents in Sui Move',
        excerpt: 'In a previous article, we showed you how to use fixed-point numbers in Sui Move by borrowing Aptos’s math library and placing it into your folder with minimal tweaks.',
        description: '',
        date: 'May 15, 2024',
        tag: 'Design',
        href: "https://blog.legato.finance/fractional-exponents-in-sui-move-using-legato-math-e4f01c051ccb"
    },
    {
        id: 8,
        thumbnail: 'https://miro.medium.com/v2/resize:fit:720/format:webp/1*FbxUNDqAlMcjV20ODNPbYA.png',
        title: 'Fixed-Point Math in Sui Move',
        excerpt: 'If you’re building a project on Sui with the Move language, you might sometimes wonder how to handle fractions, starting from basic operations like 1.5+2.4 to more complex ones like exponentiation, such as 100^0.5',
        description: '',
        date: 'May 1, 2024',
        tag: 'Design',
        href: "https://blog.legato.finance/fixed-point-math-in-sui-move-09171a78593f"
    },
    {
        id: 1,
        thumbnail: 'https://miro.medium.com/v2/resize:fit:720/format:webp/1*dVt6JUnn3wNGrjHJrm4CYg.png',
        title: 'Paris Blockchain Week’24',
        excerpt: 'Our team has just returned after participating in Paris Blockchain Week 2024, which was hosted in the beautiful city of Paris. Held beneath the iconic Louvre Museum.',
        description: '',
        date: 'Apr 15, 2024',
        tag: 'Design',
        href: "https://medium.com/tamago-labs/key-takeaways-from-paris-blockchain-week-2024-716a3e4428f4"
    },
    {
        id: 3,
        thumbnail: 'https://miro.medium.com/v2/resize:fit:720/format:webp/1*XB14LqH9If-bP1SiZvNKTA.png',
        title: 'Top Crypto Conferences in 2024',
        excerpt: 'At the time of writing, nearing the end of Q1/2024, the team is being prepared for the Paris Blockchain Week trip in early April, sponsored by the Sui Foundation.',
        description: '',
        date: 'Mar 18, 2024',
        tag: 'Design',
        href: "https://medium.com/tamago-labs/top-crypto-conferences-in-asia-and-japan-in-2024-672af53ba198"
    },
    {
        id: 4,
        thumbnail: 'https://miro.medium.com/v2/resize:fit:720/format:webp/1*XD_iibMM4kWVwnYkPZTaQg.png',
        title: 'Preview of Mainnet Version',
        excerpt: 'Today, we are excited to bring you the key highlights of the mainnet version that will be launching in the coming weeks.',
        description: '',
        date: 'Mar 15, 2024',
        tag: 'Design',
        href: "https://blog.legato.finance/preview-of-legatos-mainnet-version-19cdb4b77332"
    },
    {
        id: 6,
        thumbnail: 'https://miro.medium.com/v2/resize:fit:720/format:webp/1*HzKieULanDbUwCg2bJiBNw.jpeg',
        title: 'New Office at JR Hakata City',
        excerpt: 'At Tamago Labs, we strive to deliver innovative applications and tools for emerging blockchains like Sui, Aptos, Tezos, Oasys and Astar which currently lack some of the tools and utilities available on their networks.',
        description: '',
        date: 'Oct 30, 2023',
        tag: 'Design',
        href: "https://medium.com/tamago-labs/new-office-at-jr-hakata-city-3bdb0451c781"
    }
]

const Blog = () => {

    return (
        <section className={`py-14 relative lg:py-[100px] bg-left-top bg-no-repeat px-2 sm:px-0 bg-gray-dark`}>
            <div className='container'>
                <div className={`flex flex-col   mb-10`}>
                    <div className="heading mb-0   text-left">
                        <div className='text-secondary text-lg font-bold'>
                            Blog
                        </div>
                        <h4>Explore Newest Articles</h4>
                    </div>
                </div>

                <Swiper
                    modules={[Navigation, Autoplay]}
                    slidesPerView="auto"
                    spaceBetween={30}
                    loop={true}
                    autoplay={{ delay: 10000, disableOnInteraction: false }}
                    navigation={{
                        nextEl: '.blog-slider-button-next',
                        prevEl: '.blog-slider-button-prev',
                    }}
                    breakpoints={{
                        640: {
                            slidesPerView: 2,
                        },
                        1024: {
                            slidesPerView: 3,
                        },
                    }}
                >
                    {
                        DATA.map((blog: any, i: number) => {
                            return (
                                <SwiperSlide key={blog.id}>
                                    <Link href={blog.href} target='_blank'>
                                        <div className="rounded-xl group cursor-pointer bg-white dark:bg-black/50">
                                            <img src={blog.thumbnail} alt="blog-3" className="h-52 w-full rounded-t-xl object-cover" />
                                            <div className="p-5 text-sm font-bold"> 
                                                <div
                                                    className="my-[10px] block text-lg font-extrabold leading-[23px] text-black transition line-clamp-2   dark:text-white "
                                                >
                                                    {blog.title}
                                                </div>
                                                <p className="line-clamp-3">{blog.excerpt}</p>
                                                <div className="mt-6 flex items-center justify-between text-secondary">
                                                    <span>{blog.date}</span>
                                                    <div className="duration-300 group-hover:translate-x-2 rtl:rotate-180 rtl:group-hover:-translate-x-2">
                                                        <svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                            <path
                                                                d="M25.4091 13.0009C25.4091 19.8539 19.8531 25.41 13 25.41C6.14699 25.41 0.590937 19.8539 0.590937 13.0009C0.590937 6.14785 6.14699 0.591797 13 0.591797C19.8531 0.591797 25.4091 6.14785 25.4091 13.0009ZM12.7226 7.55043C12.6336 7.63872 12.5628 7.74368 12.5144 7.85931C12.466 7.97495 12.4408 8.09899 12.4403 8.22436C12.4398 8.34973 12.464 8.47398 12.5115 8.58999C12.559 8.70601 12.6289 8.81153 12.7172 8.90052L15.8386 12.0463H7.86935C7.61618 12.0463 7.37339 12.1469 7.19438 12.3259C7.01537 12.5049 6.9148 12.7477 6.9148 13.0009C6.9148 13.254 7.01537 13.4968 7.19438 13.6759C7.37339 13.8549 7.61618 13.9554 7.86935 13.9554H15.8386L12.7172 17.1013C12.6289 17.1903 12.5591 17.2959 12.5116 17.412C12.4641 17.5281 12.4399 17.6524 12.4405 17.7778C12.441 17.9033 12.4663 18.0273 12.5148 18.143C12.5633 18.2587 12.6341 18.3636 12.7232 18.4519C12.8123 18.5402 12.9179 18.6101 13.034 18.6576C13.1501 18.7051 13.2744 18.7292 13.3998 18.7287C13.5252 18.7281 13.6493 18.7029 13.765 18.6544C13.8806 18.6059 13.9856 18.5351 14.0739 18.446L18.8102 13.6732C18.9876 13.4944 19.0872 13.2528 19.0872 13.0009C19.0872 12.749 18.9876 12.5073 18.8102 12.3285L14.0739 7.5558C13.9856 7.46661 13.8806 7.39571 13.7648 7.34716C13.6491 7.29861 13.5249 7.27336 13.3994 7.27286C13.2739 7.27236 13.1495 7.29662 13.0333 7.34425C12.9172 7.39188 12.8116 7.46194 12.7226 7.55043Z"
                                                                fill="currentColor"
                                                            />
                                                        </svg>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </Link> 
                                </SwiperSlide>
                            );
                        })}
                </Swiper>

            </div>
        </section>
    )
}

export default Blog