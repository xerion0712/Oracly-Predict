

export const Badge = ({ children }) => (
    <span class=" text-xs font-medium mr-2 px-2.5 py-0.5 rounded  bg-gray-700  text-blue-400 border border-blue-400">{children}</span>
)


export const YellowBadge = ({ children }) => (
    <span class=" text-xs font-medium mr-2 px-2.5 py-0.5 rounded  bg-gray-700  text-yellow-300 border border-yellow-300">{children}</span>
)

export const OptionBadge = ({ children, onClick,  className }) => (
    <span onClick={onClick} class={`${className} text-xs font-medium mr-1 px-2.5 py-0.5 rounded  bg-transparent  text-gray-300 border border-gray-300`}>{children}</span>
)