


interface IListGroup {
    items: [string, string][]
}

const ListGroup = ({ items }: IListGroup) => {
    return (
        <>
            {items.map((item, index) => {
                return (
                    <div key={index} className="mt-2 border-0 border-b-2 border-gray/20 bg-transparent">
                        <div
                            className="flex py-2.5 text-sm sm:text-base"

                        >
                            <div className="flex-2  font-medium  leading-snug">{item[0]}</div>
                            <div className="flex-1 font-bold text-white text-right">{item[1]}</div>
                        </div>
                    </div>
                )
            })}
        </>
    )
}

export default ListGroup