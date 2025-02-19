import { Aptos, AptosConfig, Network, InputViewFunctionData } from "@aptos-labs/ts-sdk"
import { useWallet } from "@aptos-labs/wallet-adapter-react"
import BigNumber from "bignumber.js"
import { useCallback } from "react";

const useAptos = () => {

    const { account, signAndSubmitTransaction } = useWallet()

    const getAptosConfig = (isMainnet = true) => {
        const aptosConfig = new AptosConfig({ network: isMainnet ? Network.MAINNET : Network.TESTNET })
        const aptos = new Aptos(aptosConfig)
        return aptos
    }

    const getBalanceAPT = useCallback(async (address: any, isMainnet = true) => {

        const aptos = getAptosConfig(isMainnet)

        try {
            const resource = await aptos.getAccountResource({
                accountAddress: address,
                resourceType: "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
            });

            // Now we have access to the response type property
            const value = resource.coin.value;

            return Number((BigNumber(value)).dividedBy(BigNumber(10 ** 8)))
        } catch (e) {
            const payload: InputViewFunctionData = {
                function: `0x1::primary_fungible_store::balance`,
                typeArguments: [
                    "0x1::fungible_asset::Metadata"
                ],
                functionArguments: [
                    address,
                    "0xA"
                ],
            };
            const result = await aptos.view({ payload });
            return result[0] ? Number((BigNumber(`${result[0]}`)).dividedBy(BigNumber(10 ** 8))) : 0;
        }

    }, [])

    const getBalanceUSDC = useCallback(async (address: any) => {

        const aptos = getAptosConfig(false)

        const payload: InputViewFunctionData = {
            function: `0x1::primary_fungible_store::balance`,
            typeArguments: [
                "0x1::fungible_asset::Metadata"
            ],
            functionArguments: [
                address,
                "0xc77afa5c74640e7d0f34a7cca073ea4e26d126c60c261b5c2b16c97ac6484f01"
            ],
        };
        const result = await aptos.view({ payload });
        return result[0] ? Number((BigNumber(`${result[0]}`)).dividedBy(BigNumber(10 ** 6))) : 0;

    }, [])

    return {
        getBalanceAPT,
        getBalanceUSDC
    }
}

export default useAptos