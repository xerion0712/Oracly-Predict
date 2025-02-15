

const Overview = () => {
    return (
        <>
            <div className="heading mb-0 text-center lg:text-left ">
                <h6 className="inline-block bg-secondary/10 px-2.5 py-2 !text-secondary">markets</h6>
                <h4 className="!font-black">
                    COINMARKETCAP<span className="text-secondary">.COM</span>
                </h4>
            </div>
            <div>
                <a href="https://coinmarketcap.com" target="_blank" className="text-lg mt-1 text-secondary">
                    https://coinmarketcap.com/
                </a>
            </div>

            <p className="mt-1 text-center text-lg font-medium lg:text-left ">
                Predict anything listed on the 1st page from top token prices to market trends and trading volumes
            </p>
        </>
    )
}

export default Overview