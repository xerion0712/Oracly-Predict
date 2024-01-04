import { useContext, useMemo } from "react"
import BaseModal from "./Base"
import { LegatoContext } from "@/hooks/useLegato"
import { TrendingUp, Lock } from "react-feather"


const PTValidatorList = ({ visible, close , vault }) => {

    const { validators } = useContext(LegatoContext)
    const filtered = vault && vault.pools ? validators.filter(item => vault.pools.indexOf(item.stakingPoolId) !== -1) : []

    return (
        <BaseModal
            title={`Supported Pools (${filtered.length})`}
            visible={visible}
            close={close}
            maxWidth="max-w-3xl"
        >
             The protocol supports Staked SUI objects obtained from a limited list of validators as below:
             <div className="grid grid-cols-5 gap-2 max-h-[350px] mt-4 mb-2 overflow-y-auto">
                {filtered.map((item, index) => {

                    const imageUrl = item.imageUrl || "/sui-sui-logo.svg"
                    
                    return <div key={index} className={`  border-2 border-gray-700 p-2 rounded-md   flex-1    flex`}>
                        <div class="my-auto">
                            <div class="w-1/2 mx-auto mt-1">
                                <img
                                    class="h-full w-full object-contain object-center rounded-full"
                                    src={imageUrl}
                                    alt=""
                                />
                            </div>
                            <div className="p-2 px-1 pb-0 text-center">
                                <h3 class="text-sm font-medium leading-4 text-white">{item.name}</h3> 
                            </div>
                        </div>
                    </div>
                })}
            </div>
        </BaseModal>
    )
}

export default PTValidatorList