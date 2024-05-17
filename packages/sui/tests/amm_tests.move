


#[test_only]
module legato::amm_tests {

    use std::vector;

    use sui::coin::{ Self, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};
    use sui::sui::SUI;

    use legato::amm::{Self, AMMGlobal, AMMManagerCap};
    
    // When setting up a 90/10 pool of ~$100k
    // Initial allocation at 1 XBTC = 50,000 USDT
    const XBTC_AMOUNT: u64 = 180_000_000; // 90% at 1.8 BTC
    const USDT_AMOUNT: u64 = 10_000_000_000; // 10% at 10,000 USDT

    // When setting up a 50/50 pool of ~$100k
    // Initial allocation at 1 SUI = 1.5 USDC
    const SUI_AMOUNT: u64  = 33333_000_000_000; // 33,333 SUI
    const USDC_AMOUNT: u64 = 50_000_000_000; // 50,000 USDC

    // test coins

    struct XBTC {}

    struct USDT {}

    struct USDC {}

    #[test]
    fun test_register_pools() {
        let scenario = scenario();
        register_pools(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_swap_usdt_for_xbtc() {
        let scenario = scenario();
        swap_usdt_for_xbtc(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_swap_xbtc_for_usdt() {
        let scenario = scenario();
        swap_xbtc_for_usdt(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_swap_sui_for_usdc() {
        let scenario = scenario();
        swap_sui_for_usdc(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_swap_stable_coins() {
        let scenario = scenario();
        swap_stable_coins(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_remove_liquidity() {
        let scenario = scenario();
        remove_liquidity(&mut scenario);
        end(scenario);
    }

    // Registering three liquidity pools:
    // 1. Pool for trading USDT against XBTC, configured with weights 10% USDT and 90% XBTC.
    // 2. Pool for trading USDC against SUI, configured with equal weights of 50% USDC and 50% SUI.
    // 3. Pool for trading USDC against USDT, using stable_math.move formula.
    fun register_pools(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
        {
            amm::test_init(ctx(test));
        };

      
        // Setup a 10/90 pool first 
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(USDT_AMOUNT, ctx(test)), // 10,000 USDT
                mint<XBTC>(XBTC_AMOUNT, ctx(test)), // 1.8 BTC
                1000,
                9000, 
                false,
                ctx(test)
            );

            let burn = burn(lp); 
            assert!(burn == 268_994_649, burn); 
 
            test_scenario::return_shared(global);
        };

        // Add more liquidity to the pool and then remove it
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            // Add liquidity to the pool using USDT and XBTC
            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(6800_000_000, ctx(test)), // 6800 USDT
                mint<XBTC>(10_000_000 , ctx(test)), // 0.1 XBTC 
                1000,
                9000, 
                false,
                ctx(test)
            );
            
            // let burn = burn(lp);
            // assert!(burn == 27_613_099, burn);

            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_for_testing<USDT, XBTC>(
                 &mut global,
                 lp,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x);
            assert!(6341_919_556 == burn_coin_x, 0); // Assert the returned USDT amount (6341.919556 USDT)
            let burn_coin_y = burn(coin_y);    
            assert!(9_801_033 == burn_coin_y, 0); // Assert the returned XBTC amount (0.09801033 XBTC)
            test_scenario::return_shared(global)
        };

        // test admin functions
        // next_tx(test, owner);
        // {
        //     let global = test_scenario::take_shared<AMMGlobal>(test);
        //     let managercap = test_scenario::take_from_sender<AMMManagerCap>(test);

        //     amm::pause<USDT, XBTC>( &mut global, &mut managercap );
        //     amm::resume<USDT, XBTC>( &mut global, &mut managercap );

        //     test_scenario::return_to_sender(test, managercap);
        //     test_scenario::return_shared(global);
        // };

        // Setup a 50/50 pool 
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<SUI, USDC>(
                &mut global,
                mint<SUI>(SUI_AMOUNT, ctx(test)),  
                mint<USDC>(USDC_AMOUNT, ctx(test)),  
                5000,
                5000, 
                false,
                ctx(test)
            );

            let burn = burn(lp); 
            assert!(burn == 1290_987_992_722, burn); 

            test_scenario::return_shared(global)
        };

        // Now setup a stable pool 
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<USDC, USDT>(
                &mut global,
                mint<USDC>(50000_000_000, ctx(test)),  // 50,000 USDC
                mint<USDT>(50000_000_000, ctx(test)), // 50,000 USDT
                5000,
                5000, 
                true,
                ctx(test)
            );

            let burn = burn(lp); 
            assert!(burn == 49_999_999_000, burn); 

            test_scenario::return_shared(global)
        };

    
    }

    fun swap_stable_coins(test: &mut Scenario) {
        register_pools(test);

        let (owner, the_guy) = people();

        next_tx(test, the_guy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let returns = amm::swap_for_testing<USDT, USDC>(
                &mut global,
                mint<USDT>(100_000_000, ctx(test)), // 100 USDT
                1,
                ctx(test)
            ); 

            let coin_out = vector::borrow(&returns, 1);   
            assert!(*coin_out == 99900000, *coin_out); // 99.900000 USDC 

            test_scenario::return_shared(global);
        };

        next_tx(test, the_guy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let returns = amm::swap_for_testing<USDC, USDT>(
                &mut global,
                mint<USDC>(1000_000_000, ctx(test)), // 1000 USDC
                1,
                ctx(test)
            ); 

            let coin_out = vector::borrow(&returns, 3);    
            assert!(*coin_out == 998997387, *coin_out); // 998.997387 USDT 

            test_scenario::return_shared(global);
        };

        // Add 10% liquidity and then remove 
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<USDC, USDT>(
                &mut global,
                mint<USDC>(5000_000_000, ctx(test)),  // 5,000 USDC
                mint<USDT>(5000_000_000, ctx(test)), // 5,000 USDT
                5000,
                5000, 
                true,
                ctx(test)
            );
 
            assert!(coin::value(&lp) == 4_911_678_202, 0); 

            let (coin_x, coin_y) = amm::remove_liquidity_for_testing<USDC, USDT>(
                 &mut global,
                 lp,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x);    
            assert!(4_999_999_999 == burn_coin_x, 0); // 4,999 USDC
            let burn_coin_y = burn(coin_y);    
            assert!(4_838_724_552 == burn_coin_y, 0); // 4,838 USDT

            test_scenario::return_shared(global)
        };

    }

    fun swap_usdt_for_xbtc(test: &mut Scenario) {
        register_pools(test);

        let (_, the_guy) = people();

        next_tx(test, the_guy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let returns = amm::swap_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(100_000_000, ctx(test)), // 100 USDT
                1,
                ctx(test)
            );
            assert!(vector::length(&returns) == 4, vector::length(&returns));

            let coin_out = vector::borrow(&returns, 3);
            assert!(*coin_out == 190_821, *coin_out); // 0.00190821 XBTC at a rate of 1 BTC = 52405 USDT

            test_scenario::return_shared(global);
        };
    }

    fun swap_xbtc_for_usdt(test: &mut Scenario) {
        register_pools(test);

        let (_, the_guy) = people();

        next_tx(test, the_guy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let returns = amm::swap_for_testing<XBTC, USDT>(
                &mut global,
                mint<XBTC>(  100000, ctx(test)), // 0.001 XBTC
                1,
                ctx(test)
            );
            assert!(vector::length(&returns) == 4, vector::length(&returns));

            let coin_out = vector::borrow(&returns, 1); 
            assert!(*coin_out == 51465941, *coin_out); // 51.465941 USDT at a rate of 1 BTC = 51465 USDT

            test_scenario::return_shared(global);
        };
    }

    fun swap_sui_for_usdc(test: &mut Scenario) {
        register_pools(test);

        let (user_1, user_2) = people();

        next_tx(test, user_2);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let returns = amm::swap_for_testing<SUI, USDC>(
                &mut global,
                mint<SUI>(  250_000_000_000, ctx(test)), // 250 SUI
                1,
                ctx(test)
            );
            assert!(vector::length(&returns) == 4, vector::length(&returns));

            let coin_out = vector::borrow(&returns, 3); 
            assert!(*coin_out == 370364855, *coin_out); // 370.364855 USDC at a rate of 1 SUI = 1.474069772 USDC

            test_scenario::return_shared(global);
        };

        next_tx(test, user_1);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let returns = amm::swap_for_testing<USDC, SUI>(
                &mut global,
                mint<USDC>(  100_000_000, ctx(test)), // 100 USDC
                1,
                ctx(test)
            );
            assert!(vector::length(&returns) == 4, vector::length(&returns));

            let coin_out = vector::borrow(&returns, 1); 
            assert!(*coin_out == 67191680466, *coin_out); // 67.191680466 SUI at a rate of 1 SUI = 1.495892264 USDC

            test_scenario::return_shared(global);
        };
    }

    fun remove_liquidity(test: &mut Scenario) {
        register_pools(test);

        let (_, lp_provider) = people();


        // Adding then removing liquidity from a 90/10 USDT/XBTC pool
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            // Add liquidity to the pool using USDT and XBTC
            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(534_000_000, ctx(test)), // Mint 534 USDT (scaled by 1e6)
                mint<XBTC>(1000000, ctx(test)), // Mint 0.01 XBTC (scaled by 1e8)
                1000,
                9000, 
                false,
                ctx(test)
            );

            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_for_testing<USDT, XBTC>(
                 &mut global,
                 lp,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x);
            assert!(529_341_007 == burn_coin_x, 0); // Assert the returned USDT amount (529.341007 USDT)
            let burn_coin_y = burn(coin_y);
            assert!(997_803 == burn_coin_y, 0); // Assert the returned XBTC amount (0.00997803 XBTC)
            
            test_scenario::return_shared(global)
        };

        // Adding then removing liquidity from a 50/50 
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            // Add liquidity to the pool
            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<SUI, USDC>(
                &mut global,
                mint<SUI>(101_000_000_000, ctx(test)), // Mint 101 SUI (scaled by 1e9)
                mint<USDC>(150_000_000, ctx(test)), // Mint 150 USDC (scaled by 1e6)
                5000,
                5000, 
                false,
                ctx(test)
            );

            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_for_testing<SUI, USDC>(
                 &mut global,
                 lp,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x); 
            assert!(100_000_124_579 == burn_coin_x, 0); // Assert the returned SUI amount (100 SUI)
            let burn_coin_y = burn(coin_y); 
            assert!(150_000_336 == burn_coin_y, 0); // Assert the returned USDC amount (150 USDC)
            
            test_scenario::return_shared(global)
        };


        // Adding then removing liquidity from a stable pool
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            // Add liquidity to the pool
            let (lp, _pool_id, _) = amm::add_liquidity_for_testing<USDC, USDT>(
                &mut global,
                mint<USDC>(100_000_000, ctx(test)), // Mint 100 USDC (scaled by 1e6)
                mint<USDT>(100_000_000, ctx(test)), // Mint 100 USDT (scaled by 1e6)
                5000,
                5000, 
                true,
                ctx(test)
            );

            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_for_testing<USDC, USDT>(
                 &mut global,
                 lp,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x);  
            assert!(99_999_999 == burn_coin_x, 0); // Assert the returned USDC amount (100 USDC)
            let burn_coin_y = burn(coin_y);  
            assert!(99_999_998 == burn_coin_y, 0); // Assert the returned USDT amount (100 USDT)
            
            test_scenario::return_shared(global)
        };


    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }


}