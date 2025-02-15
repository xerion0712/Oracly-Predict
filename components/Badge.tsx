

export const Badge = ({ children }: any) => (
    <span className=" text-xs font-medium mr-1 sm:mr-2 px-1 sm:px-2.5 py-0.5 rounded  bg-gray-700  text-blue-400 border border-blue-400">{children}</span>
)

export const BadgePurple = ({ children, className }: any) => (
    <span className={`text-xs font-semibold mr-1 sm:mr-2 px-1 sm:px-2.5 py-0.5 rounded  bg-secondary  text-white border border-secondary ${className}`}>{children}</span>
)

export const BadgeWhite = ({ children, onClick }: any) => (
    <span onClick={onClick} className=" text-xs font-semibold mr-1 sm:mr-2 px-1 sm:px-1.5 py-0.5 rounded  bg-white  text-black border border-white cursor-pointer">{children}</span>
)


export const YellowBadge = ({ children }: any) => (
    <span className=" text-xs font-medium mr-2 px-2.5 py-0.5 rounded  bg-gray-700  text-yellow-300 border border-yellow-300">{children}</span>
)

export const OptionBadge = ({ children, onClick, className }: any) => (
    <span onClick={onClick} className={`${className} text-xs font-medium mr-1 px-2.5 py-0.5 rounded  bg-transparent  text-gray  border border-gray `}>{children}</span>
)