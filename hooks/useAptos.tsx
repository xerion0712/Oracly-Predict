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

    const getMarketInfo = useCallback(async (marketId: number) => {

        const aptos = getAptosConfig(false)

        const payload: InputViewFunctionData = {
            function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::generalized::get_market_data`,
            functionArguments: [
                marketId
            ],
        };

        const result = await aptos.view({ payload });

        const entry = {
            balance: result[0],
            maxBet: result[1],
            createdTime: result[2],
            interval: result[3]
        }

        const diff = (new Date().valueOf()) - (Number(entry.createdTime) * 1000)
        const interval = Number(entry.interval) * 1000
        const round = Math.floor(diff / interval) + 1

        return {
            round,
            ...entry
        }

    }, [])

    const checkPayoutAmount = useCallback(async (positionId: number) => {

        const aptos = getAptosConfig(false)

        const payload: InputViewFunctionData = {
            function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::generalized::check_payout_amount`,
            functionArguments: [
                positionId
            ],
        };

        try {
            const result = await aptos.view({ payload }); 
            return Number(result[0])
        } catch (e) { 
            return 0
        }
 
    }, [])


    const placeBet = useCallback(async (marketId: number, roundId: number, outcomeId: number, betAmount: number) => {

        if (!account) {
            return
        }

        const aptos = getAptosConfig(false)

        const transaction: any = {
            data: {
                function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::generalized::place_bet`,
                functionArguments: [
                    marketId,
                    roundId,
                    outcomeId,
                    `${(BigNumber(betAmount)).multipliedBy(BigNumber(10 ** 6))}`
                ]
            }
        }

        const response = await signAndSubmitTransaction(transaction);
        // wait for transaction
        await aptos.waitForTransaction({ transactionHash: response.hash });

        return response.hash

    }, [account])

    const claim = useCallback(async (positionId: number) => {

        if (!account) {
            return
        }

        const aptos = getAptosConfig(false)

        const transaction: any = {
            data: {
                function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::generalized::claim_prize`,
                functionArguments: [
                    positionId
                ]
            }
        }

        const response = await signAndSubmitTransaction(transaction);
        // wait for transaction
        await aptos.waitForTransaction({ transactionHash: response.hash });

        return response.hash

    }, [account])

    const refund = useCallback(async (positionId: number) => {

        if (!account) {
            return
        }

        const aptos = getAptosConfig(false)

        const transaction: any = {
            data: {
                function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::generalized::refund`,
                functionArguments: [
                    positionId
                ]
            }
        }

        const response = await signAndSubmitTransaction(transaction);
        // wait for transaction
        await aptos.waitForTransaction({ transactionHash: response.hash });

        return response.hash

    }, [account])

    return {
        getBalanceAPT,
        getBalanceUSDC,
        getMarketInfo,
        placeBet,
        checkPayoutAmount,
        claim,
        refund
    }
}

export default useAptos