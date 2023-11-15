import useSuiStake from "./useSuiStake"



const usePortfolio = () => {

    const { getStake } = useSuiStake()
 
    const getAllObjectsByKey = async (assetKey, address, isTestnet = false) => {

        if (assetKey === "SUI_TO_STAKED_SUI") return (await getStake(address, isTestnet)).map(item => ({...item, assetKey}))
        
        return []
    }

    return {
        getAllObjectsByKey
    }
}

export default usePortfolio