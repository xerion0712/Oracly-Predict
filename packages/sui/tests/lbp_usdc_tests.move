// Test launching new tokens (LEGATO) on LBP when using USDC as the settlement assets

#[test_only]
module legato::lbp_usdc_tests {

    use std::vector;

    use sui::coin::{ Self, Coin, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};
    use sui::tx_context::{Self};
    
    use legato::fixed_point64::{Self};
    use legato::amm::{Self, AMMGlobal, AMMManagerCap, LP};

    // Setting up a LBP pool to distribute 60 mil. LEGATO tokens 
    // Weight starts at a 90/10 ratio and gradually shifts to a 60/40 ratio.
    // A target amount of 50,000 USDC is set for complete weight shifting.

    const LEGATO_AMOUNT: u64 = 60000000_00000000; // 60 mil. LEGATO
    const USDC_AMOUNT: u64 = 500_000_000; // 500 USDC for bootstrap LP

    // Results:
    // During 1-10,000 USDC added - LEGATO sold for an average of 0.00059276 LEGATO/USDC
    // During 10,001-20,000 added - LEGATO sold for an average of 0.001586317 LEGATO/USDC
    // During 20.001-30,000 added - LEGATO sold for an average of 0.002102528 LEGATO/USDC
    // During 30,001-40,000 added - LEGATO sold for an average of 0.003425913 LEGATO/USDC
    // During 40,001-50,000 added - LEGATO sold for an average of 0.004948511 LEGATO/USDC
    // After stabilization  - LEGATO sold for 0.005698006 LEGATO/USDC 

    struct USDC {}

    struct LEGATO {}

    #[test]
    fun test_register_pools() {
        let scenario = scenario();
        register_pools(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_trade_until_stabilized() {
        let scenario = scenario();
        trade_until_stabilized(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_legato_to_usdc_after_stabilized() {
        let scenario = scenario();
        legato_to_usdc(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_remove_liquidity() {
        let scenario = scenario();
        remove_liquidity(&mut scenario);
        end(scenario);
    }


    // Test scenario for buying LEGATO tokens on an LBP using USDC until stabilized
    fun trade_until_stabilized(test: &mut Scenario) {
        register_pools(test);
        
        let (_, trader) = people();
 
        // Buy LEGATO with 1000 USDC for 50 times
        let counter=  0;

        while ( counter < 50) {

            next_tx(test, trader);
            {
                let global = test_scenario::take_shared<AMMGlobal>(test);
                
                let returns = amm::swap_for_testing<USDC, LEGATO>(
                    &mut global,
                    mint<USDC>(1000_000_000, ctx(test)),  // Mint 1000 USDC (scaled by 1e6)
                    1,
                    ctx(test)
                );

                let coin_out = vector::borrow(&returns, 3); 

                // check the rates above
                assert!(counter != 5  || counter == 5 && *coin_out == 1687023_91334698 , *coin_out);  
                assert!(counter != 15  || counter == 15 && *coin_out == 630391_02540454 , *coin_out);   
                assert!(counter != 25  || counter == 25 && *coin_out == 475618_10922002 , *coin_out);   
                assert!(counter != 35  || counter == 35 && *coin_out == 291893_95554000 , *coin_out);   
                assert!(counter != 45  || counter == 45 && *coin_out == 202081_47608849 , *coin_out);   
 
                test_scenario::return_shared(global);
            };
 
            counter = counter+1;
        };

        // trade after stablized
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
                
            let returns = amm::swap_for_testing<USDC, LEGATO>(
                 &mut global,
                mint<USDC>(10_000_000, ctx(test)),  // Mint 10 USDC (scaled by 1e6)
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 3); 
            assert!( *coin_out == 1755_61532093 , *coin_out); 

            test_scenario::return_shared(global);
        };

        // Verify weights received and amount on all reserves
        next_tx(test, trader);
        {  
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (weight_usdc, weight_legato, total_amount_collected, target_amount ) = amm::lbp_info<USDC, LEGATO>(&mut global);

            assert!( weight_usdc == 4000 , weight_usdc); // 40%
            assert!( weight_legato == 6000 , weight_legato); // 60%
            assert!( total_amount_collected == 50000_000000 , total_amount_collected); // 50000 USDC
            assert!( target_amount == 50000_000000 , target_amount); // 50000 USDC 

            let pool = amm::get_mut_pool<USDC,  LEGATO>(&mut global, true);
            let (usdc_reserve, legato_reserve, _) = amm::get_reserves_size<USDC, LEGATO>(pool);
            
            assert!( legato_reserve == 17741339_88106594 , 0); // 17.74 million LEGATO tokens remain in the pool
            assert!( usdc_reserve == 50384_975051 , 0); // 50384 USDC has been received as liquidity after the weight is stabilized

            test_scenario::return_shared(global);
        };
    
    }

    fun legato_to_usdc(test: &mut Scenario) { 
        trade_until_stabilized(test);
        
        let (_, trader) = people();

        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
                
            let returns = amm::swap_for_testing<LEGATO, USDC>(
                 &mut global,
                mint<LEGATO>(100_00000000, ctx(test)),  // Mint 100 LEGATO (scaled by 1e8)
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 1);  
            assert!( *coin_out == 422587 , *coin_out); // 0.422587 USDC at 0.00422587 LEGATO/USDC

            test_scenario::return_shared(global);
        };

        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
                
            let returns = amm::swap_for_testing<USDC, LEGATO>(
                 &mut global,
                mint<USDC>(1000000, ctx(test)),  // Mint 1 USDC (scaled by 1e6)
                1,
                ctx(test)
            );

            let coin_out = vector::borrow(&returns, 3);   
            assert!( *coin_out == 174_79362004 , *coin_out); // 174.79 LEGATO at 0.005721033 LEGATO/USDC

            test_scenario::return_shared(global);
        };

    }

    fun register_pools(test: &mut Scenario) { 

        let (owner, lp_provider) = people();

        next_tx(test, owner);
        {
            amm::test_init(ctx(test));
        };

        // Registering an LBP pool for LEGATO token against USDC
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let current_epoch = tx_context::epoch(ctx(test));

            amm::register_lbp_pool<USDC, LEGATO >( 
                &mut global, 
                false, // LEGATO is on Y
                9000,
                6000, 
                false,
                50000_000000, // 50,000 USDC
                ctx(test) 
            );
            test_scenario::return_shared(global);
        };

        // Adding liquidity to the registered pool
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            amm::add_liquidity<USDC, LEGATO>( 
                &mut global, 
                mint<USDC>(USDC_AMOUNT, ctx(test)),   
                1,
                mint<LEGATO>(LEGATO_AMOUNT, ctx(test)),  
                1,
                ctx(test) 
            );

            test_scenario::return_shared(global);
        };

    }

    fun remove_liquidity(test: &mut Scenario) {
        trade_until_stabilized(test);

        let (_, lp_provider) = people();

        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
 
            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<USDC, LEGATO>(
                &mut global,
                mint<USDC>(5000_000000, ctx(test)), // Mint 5000 USDC (scaled by 1e6)
                mint<LEGATO>(1000000_00000000, ctx(test)), // Mint 1 mil. LEGATO (scaled by 1e8)
                4000,
                6000, 
                false,
                ctx(test)
            );

            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_for_testing<USDC, LEGATO>(
                 &mut global,
                 lp,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x); 
            assert!(4320_651604 == burn_coin_x, 0);  
            let burn_coin_y = burn(coin_y); 
            assert!(898336_30379336 == burn_coin_y, 0);  
            
            test_scenario::return_shared(global)
        };

        


    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }
}