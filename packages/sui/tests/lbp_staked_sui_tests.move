

// Testing the launch of new tokens (LEGATO) on LBP when using future staking rewards on Legato vaults

#[test_only]
module legato::lbp_staked_sui_tests {

    use std::vector;

    use sui::coin::{ Self, Coin, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};
    use sui::tx_context::{Self};
    use sui::sui::SUI;
    use sui::random::{Random};
    use sui_system::sui_system::{ SuiSystemState };
 
    use legato::amm::{Self, AMMGlobal, AMMManagerCap, LP};
    use legato::vault_token_name::{  MAR_2024, JUN_2024 };
    use legato::vault::{Global, PT_TOKEN};

    use legato::vault_utils::{
        scenario, 
        advance_epoch,
        set_up_sui_system_state,
        setup_vault,
        set_up_random
    };

    // Setting up a LBP pool to distribute 25 mil. LEGATO tokens
    // Weight starts at a 90/10 ratio and gradually shifts to a 50/50 ratio.
    // A target amount of 30,000 SUI is set for complete weight shifting. 

    const LEGATO_AMOUNT: u64 = 25000000_00000000; // 25 mil. LEGATO at 90% 
    const SUI_AMOUNT: u64 = 300_000000000; // 300 SUI for bootstrap LP

    const TARGET_AMOUNT: u64 = 30000_000000000; 

    struct LEGATO {}

    #[test]
    fun test_register_pools() {
        let scenario = scenario();
        register_pools(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_stake_for_legato() {
        let scenario = scenario();
        stake_for_legato(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_stake_until_stablized() {
        let scenario = scenario();
        stake_until_stablized(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_legato_to_sui_after_stabilized() {
        let scenario = scenario();
        legato_to_sui_after_stabilized(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_replenish() {
        let scenario = scenario();
        replenish(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_legato_to_sui_before_stabilized() {
        let scenario = scenario();
        legato_to_sui_before_stabilized(&mut scenario);
        end(scenario);
    }

    fun stake_for_legato(test: &mut Scenario) {
        setup_all_system(test);

        register_pools(test);

        let (_, staker, trader) = people();
    
        future_swap<JUN_2024>( test, staker , 1000_000000000); // 1,000 SUI

        // Verify tokens received 
        next_tx(test, staker);
        { 
            let pt_token = test_scenario::take_from_sender<Coin<PT_TOKEN<JUN_2024>>>(test);
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);

            // Verify that 1000 PT tokens have been received, which can be claimed as SUI when the JUN_2024 vault matures.
            assert!( coin::value(&pt_token) == 1000_000000000, 0);

            // Verify that the future yield has been converted into 157,590 LEGATO tokens.
            assert!( coin::value(&legato_token) == 157590_92107100, 0);

            test_scenario::return_to_sender(test, pt_token);
            test_scenario::return_to_sender(test, legato_token);
        };

        // Verify the weights that are being shifted
        next_tx(test, staker);
        {  
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (weight_usdc, weight_legato, total_amount_collected, target_amount ) = amm::lbp_info<SUI, LEGATO>(&mut global);

            // Check if the weight for USDC is correct (expected 10.72%)
            assert!( weight_usdc == 1072 , weight_usdc ); 
            // Check if the weight for LEGATO is correct (expected 89.28%)
            assert!( weight_legato == 8928 , weight_legato );
            // Check if the total amount collected is correct (expected 17 SUI equivalent)
            assert!( total_amount_collected == 17_577352475 , total_amount_collected ); 
            // Check if the target amount is correct (expected 30,000 SUI equivalent)
            assert!( target_amount == 30000_000000000 , target_amount );

            test_scenario::return_shared(global);
        };

        // Stake 1,000 SUI for 10 times
        let count = 0;
        while (count < 10) {
            future_swap<MAR_2024>( test, staker , 1000_000000000); 
            count = count +1;
        };

    }

    fun stake_until_stablized(test: &mut Scenario) {
        setup_all_system(test);

        register_pools(test);

        let (_, staker, trader) = people();

        // Stake 100,000 SUI for 20 times
        let count = 0;
        while (count < 20) {
            future_swap<JUN_2024>( test, staker , 100000_000000000); 
            count = count +1;
        };

        // Verify the weights have fully shifted
        next_tx(test, staker);
        {  
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (weight_usdc, weight_legato, total_amount_collected, target_amount ) = amm::lbp_info<SUI, LEGATO>(&mut global);

            // Verify that the total amount collected in the LBP pool has exceeded 30K SUI.
            assert!( total_amount_collected == 31639_234456296 , total_amount_collected ); 

            // Verify that the weight of USDC is 4000 (40%).
            assert!( weight_usdc == 4000 , weight_usdc ); 

            // Verify that the weight of LEGATO is 6000 (60%).
            assert!( weight_legato == 6000 , weight_legato ); 

            test_scenario::return_shared(global);
        };

    }

    fun legato_to_sui_before_stabilized( test: &mut Scenario ) {
        stake_for_legato(test);

        let (_, staker, trader) = people();

        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test); 

            let returns = amm::swap_for_testing<LEGATO, SUI>(
                &mut amm_global,
                coin::mint_for_testing<LEGATO>( 100000_00000000, ctx(test)), // 100,000 LEGATO
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 1); 
            // 9.102 SUI. Approximately 0.000091021 LEGATO per SUI
            assert!(*coin_out == 9_102068329 , *coin_out);
            // 11.757428159 SUI. Approximately 0.000117574 LEGATO per SUI
            // assert!(*coin_out == 11_757428159 , *coin_out); <-- Without reserve blocking

            test_scenario::return_shared(amm_global);
        };

        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test); 

            let returns = amm::swap_for_testing<SUI, LEGATO>(
                &mut amm_global,
                coin::mint_for_testing<SUI>( 10_000000000, ctx(test)), // 10 SUI
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 3); 
            // 79,001 LEGATO. Approximately 0.000125706 LEGATO per SUI
            assert!(*coin_out == 79001_61102250 , *coin_out);
            
            test_scenario::return_shared(amm_global);
        };

    }

    fun legato_to_sui_after_stabilized( test: &mut Scenario ) {
        stake_until_stablized(test);

        let (_, _, trader) = people();

        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test); 

            let returns = amm::swap_for_testing<LEGATO, SUI>(
                &mut amm_global,
                coin::mint_for_testing<LEGATO>( 100000_00000000, ctx(test)), // 100,000 LEGATO
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 1); 
            // 5.9882 SUI. Approximately 0.000059882 LEGATO per SUI
            assert!(*coin_out == 5_988206892 , *coin_out);
            // 71.845 SUI. Approximately 0.007184547 LEGATO per SUI
            // assert!(*coin_out == 71_845471030 , *coin_out); <-- Without reserve blocking 

            test_scenario::return_shared(amm_global);
        };

        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test); 

            let returns = amm::swap_for_testing<SUI, LEGATO>(
                &mut amm_global,
                coin::mint_for_testing<SUI>( 10_000000000, ctx(test)), // 10 SUI
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 3); 
            // 1,050.558 LEGATO. Approximately 0.009616622 LEGATO per SUI
            assert!(*coin_out == 1050_55830263 , *coin_out);  

            test_scenario::return_shared(amm_global);
        };
    }

    fun replenish( test: &mut Scenario) { 
        setup_all_system(test);

        register_pools(test);

        let (_, staker, trader) = people();

        // Stake 3 million SUI for future swap with MAR_2024.
        future_swap<MAR_2024>( test, staker , 3000000_000000000); 
        // Stake another 2 million SUI for future swap with MAR_2024.
        future_swap<MAR_2024>( test, staker , 2000000_000000000); 

        // Verify if the pool weights have fully shifted.
        next_tx(test, staker);
        {  
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (weight_usdc, weight_legato, _, _ ) = amm::lbp_info<SUI, LEGATO>(&mut global);

            assert!( weight_usdc == 4000 , weight_usdc ); // 40%
            assert!( weight_legato == 6000 , weight_legato ); // 60%

            test_scenario::return_shared(global);
        };
        
        // Check swap rates before replenishing the pool.
        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test); 

            let returns = amm::swap_for_testing<LEGATO, SUI>(
                &mut amm_global,
                coin::mint_for_testing<LEGATO>( 100000_00000000, ctx(test)), // 100,000 LEGATO
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 1);
            assert!(*coin_out == 3_673491256, *coin_out);  // Approximately 0.000036735 LEGATO per SUI

            test_scenario::return_shared(amm_global);
        };

        advance_epoch(test, 61);

        // Perform the replenish operation.
        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test);
            let vault_global = test_scenario::take_shared<Global>(test);
            let system_state = test_scenario::take_shared<SuiSystemState>(test);  

            amm::lbp_replenish<LEGATO, MAR_2024 >(
                &mut system_state,
                &mut amm_global,
                &mut vault_global,
                ctx(test)
            );

            test_scenario::return_shared(amm_global);
            test_scenario::return_shared(vault_global);
            test_scenario::return_shared(system_state); 
        };

        // Check swap rates after replenishing the pool.
        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test); 

            let returns = amm::swap_for_testing<LEGATO, SUI>(
                &mut amm_global,
                coin::mint_for_testing<LEGATO>( 100000_00000000, ctx(test)), // 100,000 LEGATO
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 1);
            assert!(*coin_out == 428_351172547 , *coin_out);  // Approximately 0.00428351 LEGATO per SUI

            test_scenario::return_shared(amm_global);
        };

    }

    fun setup_all_system( test: &mut Scenario ) {
        set_up_sui_system_state();
        set_up_random(test);
        advance_epoch(test, 40);

        let (admin, _, _) = people();

        setup_vault(test, admin  );
    }

    fun register_pools(test: &mut Scenario) { 


        let (owner, lp_provider, _) = people();

        next_tx(test, owner);
        {
            amm::test_init(ctx(test));
        };

        // Registering an LBP pool for LEGATO token against USDC
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            amm::register_lbp_pool<SUI, LEGATO>( 
                &mut global, 
                false, // LEGATO is on Y
                9000,
                6000, 
                true,
                TARGET_AMOUNT, // 30,000 SUI
                ctx(test) 
            );
            test_scenario::return_shared(global);
        };

        // Adding liquidity to the registered pool
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            amm::add_liquidity<SUI, LEGATO>( 
                &mut global, 
                mint<SUI>(SUI_AMOUNT, ctx(test)),   
                1,
                mint<LEGATO>(LEGATO_AMOUNT, ctx(test)),  
                1,
                ctx(test) 
            );

            test_scenario::return_shared(global);
        };

    }

    fun future_swap<P>( test: &mut Scenario, trader: address, amount: u64 ) {

        next_tx(test, trader);
        {
            let amm_global = test_scenario::take_shared<AMMGlobal>(test);
            let vault_global = test_scenario::take_shared<Global>(test);
            let system_state = test_scenario::take_shared<SuiSystemState>(test);
            let random_state = test_scenario::take_shared<Random>(test);    

            amm::future_swap_with_sui<P, LEGATO>(
                &mut system_state,
                &mut amm_global,
                &mut vault_global,
                &random_state,
                coin::mint_for_testing<SUI>( amount, ctx(test)), // 1000 SUI
                ctx(test)
            );

            test_scenario::return_shared(amm_global);
            test_scenario::return_shared(vault_global);
            test_scenario::return_shared(system_state);
            test_scenario::return_shared(random_state);
        };

    }

    // utilities 

    fun people(): (address, address, address) { (@0xBEEF, @0x1337, @0x1338) }
}