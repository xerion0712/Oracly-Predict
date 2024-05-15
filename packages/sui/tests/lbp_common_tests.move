
// Test launching new tokens (LEGATO) on LBP when using common coin as the settlement assets

#[test_only]
module legato::lbp_common_tests {

    use std::vector;

    use sui::coin::{ Self, Coin, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};
    
    use legato::fixed_point64::{Self};
    use legato::lbp::{Self, LBPGlobal, LBPManagerCap, LBPToken};

    // Setting up a LBP pool to distribute 25 mil. LEGATO tokens at different weights. 
    // Weight is shifted by 10% every 5 mil. tokens sold until it reaches a 60/40 ratio:
    // 1. 90% LEGATO, 10% USDC 
    // 2. 80% LEGATO, 20% USDC 
    // 3. 70% LEGATO, 30% USDC 
    // 4. 60% LEGATO, 40% USDC 

    // The initial price is set to 1 LEGATO = 0.002 USDC.
    const LEGATO_AMOUNT: u64 = 25000000_00000000; // 25 mil. LEGATO at 90% 
    const USDC_AMOUNT: u64 = 1111_000_000; // // 1111 USDC at 10%, needed for bootstrap LP

    // Results:
    // At 90/10 Weight - LEGATO sold for an average of 0.001649722 LEGATO/USDC
    // At 80/20 Weight - LEGATO sold for an average of 0.004327831 LEGATO/USDC
    // At 70/30 Weight - LEGATO sold for an average of 0.0077703 LEGATO/USDC
    // After stabilization (60/40) - LEGATO sold for 0.013464387 LEGATO/USDC
    // Thus, a total of 67,000 USDC has been collected

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
    fun test_legato_to_usdc_before_stabilized() {
        let scenario = scenario();
        legato_to_usdc_before(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_remove_liquidity() {
        let scenario = scenario();
        remove_liquidity(&mut scenario);
        end(scenario);
    }

    // Registering 2 LBP pools:
    // 1. Pool that accepts the common coin USDC.
    // 2. Pool that accepts staking rewards (moved to another file)
    fun register_pools(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
        {
            lbp::test_init(ctx(test));
        };

        setup_common_pool(test);
    
    }

    fun legato_to_usdc(test: &mut Scenario) {
        trade_until_stabilized(test);

        let (_, trader) = people();
 
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<LEGATO, USDC>(
                &mut global,
                mint<LEGATO>(1000_00000000, ctx(test)),  // Mint 1000 LEGATO
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of USDC tokens received and burn them
        next_tx(test, trader);
        {
            let usdc_token = test_scenario::take_from_sender<Coin<USDC>>(test);
            // Assert that the amount of USDC received is as expected (10.05 USDC at a rate of 0.01005 LEGATO/USDC) 
            assert!( coin::value(&usdc_token) == 10_058007 , 0); 
            burn(usdc_token); 
        };

        // try to buy LEGATO back at the same amount
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(10_000000, ctx(test)),  // Mint 10 USDC
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received and burn them
        next_tx(test, trader);
        {
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);
            // Assert that the amount of LEGATO received is as expected (741 LEGATO at a rate of 0.01349038 LEGATO/USDC) 
            assert!( coin::value(&legato_token) == 741_26894574 , 0);    
            burn(legato_token); 
        };

    }

    fun legato_to_usdc_before(test: &mut Scenario) {
        register_pools(test);

        let (_, trader) = people();

        // buy LEGATO at a 90/10 weight
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(10_000000, ctx(test)),  // Mint 10 USDC
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received and burn them
        next_tx(test, trader);
        {
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);
            // Assert that the amount of LEGATO received is as expected (24816 LEGATO at a rate of 0.000402966 LEGATO/USDC) 
            assert!( coin::value(&legato_token) == 24816_25168070 , 0);     
            burn(legato_token); 
        };

        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<LEGATO, USDC>(
                &mut global,
                mint<LEGATO>(10000_00000000, ctx(test)),  // Mint 10000 LEGATO
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of USDC tokens received and burn them
        next_tx(test, trader);
        {
            let usdc_token = test_scenario::take_from_sender<Coin<USDC>>(test);
            // Assert that the amount of USDC received is as expected (10.05 USDC at a rate of 0.000402139 LEGATO/USDC) 
            assert!( coin::value(&usdc_token) == 4_021386 , 0);  
            burn(usdc_token); 
        };

    }

    fun remove_liquidity(test: &mut Scenario) {
        trade_until_stabilized(test);

        let (_, lp_provider) = people();

        // Add liquidity to the pool first
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::add_liquidity<LEGATO, USDC>( 
                &mut global, 
                mint<LEGATO>(1000000_00000000, ctx(test)),  // Mint 1 million LEGATO tokens
                1,
                mint<USDC>(13000_000000, ctx(test)), // Mint 13000 USDC tokens (actual deducted: 11519.179494 USDC)
                1,
                ctx(test) 
            );
            
            test_scenario::return_shared(global);
        };

        // Then remove liquidity from the pool
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            let lbp_token = test_scenario::take_from_sender<Coin<LBPToken<LEGATO>>>(test); 

            lbp::remove_liquidity<LEGATO, USDC>( 
                &mut global, 
                lbp_token,
                ctx(test) 
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the tokens received after removing liquidity
        next_tx(test, lp_provider);
        { 
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test); 
            let usdc_token = test_scenario::take_from_sender<Coin<USDC>>(test); 
            
            // Assert that the correct amount of LEGATO and USDC tokens are received
            assert!( coin::value(&legato_token) == 898174_19875721 , 0); // 898174 LEGATO
            assert!( coin::value(&usdc_token) == 10426_005789 , 0); // 10426 USDC

            burn(legato_token);
            burn(usdc_token);
            
        };

    }

    // Test scenario for buying LEGATO tokens on an LBP using USDC until stabilized
    fun trade_until_stabilized(test: &mut Scenario) {
        register_pools(test);
        
        let (_, trader) = people();
        
        // First transaction: buy LEGATO with 2000 USDC
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(2000_000_000, ctx(test)),  // Mint 2000 USDC (scaled by 1e6)
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received and burn them
        next_tx(test, trader);
        {
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);
            // Assert that the amount of LEGATO received is as expected (2.698665 million at a rate of 0.000741107 LEGATO/USDC)
            assert!( coin::value(&legato_token) == 2698665_94382582 , 0);  
            burn(legato_token); 
        };

        // Second transaction: buy LEGATO again to trigger the first weight shift
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(7000_000_000, ctx(test)),  // Mint 7000 USDC
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received and ensure the weight has shifted
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);

            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);
            // Assert that the amount of LEGATO received is as expected (2.736 million at a rate of 0.002558337 LEGATO/USDC)
            assert!( coin::value(&legato_token) == 2736152_16957298 , 0);   
            burn(legato_token); 

            let pool = lbp::get_mut_pool<LEGATO>(&mut global);
            let ( weight_x, weight_y, current_tier) = lbp::pool_current_weight<LEGATO>( pool );

            assert!( weight_x == 8000 , 0);  // The weight of LEGATO has shifted to 80%
            assert!( weight_y == 2000 , 0);  // The weight of USDC has shifted to 20%
            assert!( current_tier == 1 , 0);  // The current tier has shifted from 0 to 1

            let token_sold = lbp::pool_token_sold<LEGATO>(pool);
            // Assert that the total amount of LEGATO tokens sold is as expected (5.434 mil.)
            assert!( token_sold == 5434818_11339880 , 0);   

            test_scenario::return_shared(global);
        };

        // Third transaction: buy LEGATO tokens at the second tier
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(7000_000_000, ctx(test)),  // Mint 7000 USDC (scaled by 1e6)
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received 
        next_tx(test, trader);
        { 
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);
            // Assert that the amount of LEGATO received is as expected (2.41 million at a rate of 0.002903646 LEGATO/USDC)
            assert!( coin::value(&legato_token) == 2410762_28638006 , 0); 
            burn(legato_token); 
        };

        // Fourth transaction: buy LEGATO tokens with 13000 USDC to trigger the second weight shift
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(13000_000_000, ctx(test)),  // Mint 13000 USDC
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received from the fourth transaction and ensure the weight has shifted
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);

            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);
            // Assert that the amount of LEGATO received is as expected (2.26 million at a rate of 0.005752016 LEGATO/USDC)
            assert!( coin::value(&legato_token) == 2260077_68814917 , 0);   
            burn(legato_token); 

            let pool = lbp::get_mut_pool<LEGATO>(&mut global);
            let ( weight_x, weight_y, current_tier) = lbp::pool_current_weight<LEGATO>( pool );

            assert!( weight_x == 7000 , 0);  // The weight of LEGATO has shifted to 70%
            assert!( weight_y == 3000 , 0);  // The weight of USDC has shifted to 30%
            assert!( current_tier == 2 , 0);  // The current tier has shifted from 1 to 2

            let token_sold = lbp::pool_token_sold<LEGATO>(pool); 
            // Assert that the total amount of LEGATO tokens sold is as expected (10.196598 mil.)
            assert!( token_sold == 10105658_08792803 , 0);   

            test_scenario::return_shared(global);
        };

        // Fifth transaction: buy LEGATO tokens at the thrid tier using 15000 USDC
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(15000_000_000, ctx(test)),  // Mint 15000 USDC (scaled by 1e6)
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received 
        next_tx(test, trader);
        { 
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);
            // Assert that the amount of LEGATO received is as expected (2.725 million at a rate of 0.005503585 LEGATO/USDC)
            assert!( coin::value(&legato_token) == 2725496_94975255 , 0); 
            burn(legato_token); 
        };

        // Sixth transaction: buy LEGATO tokens to trigger the final weight shift
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(22000_000_000, ctx(test)),  // Mint 22000 USDC
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received and ensure the weight has shifted
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);

            // Assert that the amount of LEGATO received is as expected (2.191 million at a rate of 0.010037014 LEGATO/USDC)
            assert!( coin::value(&legato_token) == 2191887_42441387 , 0);   
            burn(legato_token); 

            let pool = lbp::get_mut_pool<LEGATO>(&mut global);
            let ( weight_x, weight_y, current_tier) = lbp::pool_current_weight<LEGATO>( pool );

            assert!( weight_x == 6000 , 0);  // The weight of LEGATO has shifted to 60%
            assert!( weight_y == 4000 , 0);  // The weight of USDC has shifted to 40%
            assert!( current_tier == 3 , 0);  // The current tier has shifted from 2 to 3

            let token_sold = lbp::pool_token_sold<LEGATO>(pool); 
            // Assert that the total amount of LEGATO tokens sold is as expected (15.02 mil.)
            assert!( token_sold == 15023042_46209445 , 0);   

            test_scenario::return_shared(global);
        };

        // Seventh transaction: buy LEGATO tokens when the weight is stabilized
        next_tx(test, trader);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::swap<USDC, LEGATO>(
                &mut global,
                mint<USDC>(100_000_000, ctx(test)),  // Mint 100 USDC (scaled by 1e6)
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        // Verify the amount of LEGATO tokens received and on all reserves
        next_tx(test, trader);
        {  
            let global = test_scenario::take_shared<LBPGlobal>(test);

            let legato_token = test_scenario::take_from_sender<Coin<LEGATO>>(test);

            // Assert that the amount of LEGATO received is as expected (7424 LEGATO at a rate of 0.013464387 LEGATO/USDC)
            assert!( coin::value(&legato_token) == 7424_11585537 , 0); 

            burn(legato_token);  

            let pool = lbp::get_mut_pool<LEGATO>(&mut global);
            let (legato_reserve, usdc_reserve, _) = lbp::get_reserves_size<LEGATO, USDC>(pool);

            assert!( legato_reserve == 9969533_42205018 , 0); // 9.96 million LEGATO tokens remain in the pool
            assert!( usdc_reserve == 67045_750007 , 0); // 67045 USDC has been received as liquidity after the weight is stabilized

            test_scenario::return_shared(global);
        };

    }

    fun setup_common_pool(test: &mut Scenario) {

        let (owner, _) = people();

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            lbp::register_lbp_pool<LEGATO>( &mut global, ctx(test) );
            test_scenario::return_shared(global);
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::setup_weight_data<LEGATO>( 
                &mut global, 
                9000,
                1000,
                8000,
                2000,
                7000,
                3000,
                6000,
                4000,
                0,
                0,
                1,
                5000000_00000000,
                ctx(test) 
            );

            lbp::setup_reserve_with_common_coin<LEGATO, USDC>( &mut global, ctx(test) );
            
            test_scenario::return_shared(global);
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::add_liquidity<LEGATO, USDC>( 
                &mut global, 
                mint<LEGATO>(LEGATO_AMOUNT, ctx(test)),  
                1,
                mint<USDC>(USDC_AMOUNT, ctx(test)),   
                1,
                ctx(test) 
            );

            test_scenario::return_shared(global);
        };

    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }

}