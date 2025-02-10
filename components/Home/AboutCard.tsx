
const AboutCard = ({ icon, title, info }: any) => {
    return (
        <div className={` flex flex-row sm:flex-col mt-[3px] sm:mt-0`} data-aos="fade-up" data-aos-duration="1000" >

            <div className="h-20 w-20 flex-none">
                <div className="flex h-20 w-20 items-center justify-center rounded-2xl bg-secondary/[0.06]">
                    {icon}
                </div>
            </div>

            <div className="mt-3 px-4 sm:px-0">
                <h4 className=" font-bold text-xl lg:text-2xl text-white ">{title}</h4>
                <p className="mt-1 text-sm sm:text-base lg:text-lg">{info}</p>
            </div>

        </div>
    )
}

export default AboutCard