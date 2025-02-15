import { slugify } from "@/helpers"
import Link from "next/link"

import { Swiper, SwiperSlide } from 'swiper/react';

// Import Swiper styles
import 'swiper/css';
import 'swiper/css/navigation';
import 'swiper/css/pagination';
import { Pagination, Navigation } from 'swiper/modules';

import PreviewCard from "./PreviewCard";

interface IMarketCards {
    name: string
    index: number
    items: any[]
    filter: string | undefined
    setCurrentMarket: any
}

const GroupCards = ({ name, index, items, filter, setCurrentMarket }: IMarketCards) => {

    const titles = items.reduce((arr, item) => {
        if (arr.indexOf(item.title) === -1) {
            arr.unshift(item.title)
        }
        return arr
    }, [])

    return (
        <div className="space-y-0 " key={index}>
            {/* <div className={`bg-white dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent  rounded-t-xl  px-2 sm:px-5  border border-transparent h-[60px]  `} >
                <div className='grid grid-cols-7 h-full'>
                    <div className="col-span-3 sm:col-span-2 flex ">
                        <div className='mt-auto mb-auto flex flex-row'>
                            <div className="mt-auto mb-auto flex">
                                <h2 className='text-base lg:text-lg tracking-tight font-semibold text-white uppercase'>{name}</h2>
                            </div>
                        </div>
                    </div>
                </div>
            </div> */}
            {/* <h2 className='text-base lg:text-lg tracking-tight font-semibold mb-[20px] text-center text-white lowercase'>{name}</h2> */}
            {/* <div className='text-center text-secondary font-normal  mb-2 sm:mb-4 text-sm sm:text-base tracking-widest'>
                {name}
            </div> */}

            {titles.map((title: string, index: number) => {

                if (filter !== undefined) {
                    if (filter !== title) {
                        return
                    }
                    return (
                        <EachRow index={index} setCurrentMarket={setCurrentMarket} items={items.filter((item) => item.title === title)} />
                    )
                } else {
                    return (
                        <EachRow index={index} setCurrentMarket={setCurrentMarket} items={items.filter((item) => item.title === title)} />
                    )
                }

            })}
        </div>
    )
}

const EachRow = ({ items, index, setCurrentMarket }: any) => {

    return (
        <div key={index} data-aos="fade-up" data-aos-duration="1000">
            <Swiper
                spaceBetween={20}
                slidesPerView={3}
                pagination={{
                    type: 'fraction',
                }}
                navigation={true}
                modules={[Pagination, Navigation]}
                className="mySwiper"
                breakpoints={{
                    320: {
                        slidesPerView: 1,
                        spaceBetween: 10,
                    },
                    640: {
                        slidesPerView: 2,
                        spaceBetween: 10,
                    },
                    768: {
                        slidesPerView: 3,
                        spaceBetween: 20,
                    }
                }}
            >
                {items.sort((a: any, b: any) => {
                    return new Date(b.closingDate).getTime() - new Date(a.closingDate).getTime()
                }).map((item: any, index: number) => (
                    <SwiperSlide key={index}  >
                        <PreviewCard
                            item={item}
                            setCurrentMarket={setCurrentMarket}
                        />
                    </SwiperSlide>
                ))}
            </Swiper>
        </div>
    )
}


export default GroupCards