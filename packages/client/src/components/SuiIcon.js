import Image from "next/image"


export const SmallIcon = ({ className }) => (
    <Image className={`${className} rounded-full`} width={16} height={16} src={"/sui-sui-logo.svg"} alt="Sui Logo" />
) 