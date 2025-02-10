import WithWalletPanel from "@/components/Layouts/WithWallet"
import BaseOverview from "../BaseOverview"
import StakePanel from "./StakePanel"

const VaultAptos = () => {



    return (
        <>
            <WithWalletPanel
                pageName="vault"
                title1={"LIQUIDITY"}
                title2={"VAULT"}
                info={"lock-in assets for counter bets and maximize returns with network rewards"}
                href={"/vault"}
            >
                <BaseOverview network="aptos" />
                <StakePanel />
            </WithWalletPanel>
        </>
    )
}

export default VaultAptos