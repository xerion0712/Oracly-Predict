
#[test_only]
module legato_amm::amm_tests {

    use std::vector;

    use sui::coin::{ Self, Coin, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};
    use sui::sui::SUI;

    use legato_amm::amm::{Self, AMMGlobal, ManagerCap}; 

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
    fun test_remove_liquidity() {
        let scenario = scenario();
        remove_liquidity(&mut scenario);
        end(scenario);
    }

    // Registering three liquidity pools:
    // 1. Pool for trading USDT against XBTC, configured with weights 10% USDT and 90% XBTC.
    // 2. Pool for trading USDC against SUI, configured with equal weights of 50% USDC and 50% SUI.
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
            
            amm::register_pool<USDT, XBTC>(&mut global, 1000, 9000, ctx(test));

            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);

            let lp = amm::add_liquidity_non_entry(
                pool,
                mint<USDT>(USDT_AMOUNT, ctx(test)), // 10,000 USDT
                1,
                mint<XBTC>(XBTC_AMOUNT, ctx(test)), // 1.8 BTC
                1,
                true,
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

            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);

            let lp = amm::add_liquidity_non_entry(
                pool,
                mint<USDT>(6800_000_000, ctx(test)), // 6800 USDT
                1,
                mint<XBTC>(10_000_000 , ctx(test)), // 0.1 XBTC 
                1,
                true,
                ctx(test)
            );
            
            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_non_entry<USDT, XBTC>(
                 pool,
                 lp,
                 true,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x); 
            assert!(6341_919556 == burn_coin_x, 0); // Assert the returned USDT amount (6341.919556 USDT)
            let burn_coin_y = burn(coin_y);     
            assert!(9801033 == burn_coin_y, 0); // Assert the returned XBTC amount (0.09801033 XBTC)
            test_scenario::return_shared(global)
        };

        // test admin functions
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let managercap = test_scenario::take_from_sender<ManagerCap>(test);

            amm::pause<USDT, XBTC>( &mut global, &mut managercap );
            amm::resume<USDT, XBTC>( &mut global, &mut managercap );

            test_scenario::return_to_sender(test, managercap);
            test_scenario::return_shared(global);
        };

        // Setup a 50/50 pool 
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            amm::register_pool<SUI, USDC>(&mut global, 5000, 5000, ctx(test));

            let pool = amm::get_mut_pool_for_testing<SUI, USDC>(&mut global);

            let lp = amm::add_liquidity_non_entry(
                pool,
                mint<SUI>(SUI_AMOUNT, ctx(test)),  
                1,
                mint<USDC>(USDC_AMOUNT, ctx(test)),  
                1,
                true,
                ctx(test)
            );

            let burn = burn(lp);  
            assert!(burn == 1290_987_992_722, burn); 

            test_scenario::return_shared(global)
        };

    }
 
    fun swap_usdt_for_xbtc(test: &mut Scenario) {
        register_pools(test);

        let (_, the_guy) = people();

        next_tx(test, the_guy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            amm::swap<USDT, XBTC>(&mut global, mint<USDT>(100_000_000, ctx(test)), 1, ctx(test));
            test_scenario::return_shared(global);
        };

        // Checking
        next_tx(test, the_guy);
        { 
            let xbtc_token = test_scenario::take_from_sender<Coin<XBTC>>(test);
            assert!(coin::value(&(xbtc_token)) == 190821, 0); // 0.00190821 XBTC at a rate of 1 BTC = 52405 USDT
            test_scenario::return_to_sender( test , xbtc_token );
        };

    }

    fun swap_xbtc_for_usdt(test: &mut Scenario) {
        register_pools(test);

        let (_, the_guy) = people();

        next_tx(test, the_guy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            amm::swap<XBTC, USDT>(&mut global, mint<XBTC>(100000, ctx(test)), 1, ctx(test)); // 0.001 XBTC
            test_scenario::return_shared(global);
        };

        // Checking
        next_tx(test, the_guy);
        { 
            let usdt_token = test_scenario::take_from_sender<Coin<USDT>>(test);
            assert!(coin::value(&(usdt_token)) == 51465941, 0); // 51.465941 USDT at a rate of 1 BTC = 51465 USDT
            test_scenario::return_to_sender( test , usdt_token );
        };
    }

    fun swap_sui_for_usdc(test: &mut Scenario) {
        register_pools(test);

        let (user_1, user_2) = people();

        next_tx(test, user_2);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            amm::swap<SUI, USDC>(&mut global, mint<SUI>(250_000_000_000, ctx(test)), 1, ctx(test)); // 250 SUI
            test_scenario::return_shared(global);
        };

        // Checking
        next_tx(test, user_2);
        { 
            let usdc_token = test_scenario::take_from_sender<Coin<USDC>>(test);
            assert!(coin::value(&(usdc_token)) == 370364855, 0); // 370.364855 USDC at a rate of 1 SUI = 1.474069772 USDC
            test_scenario::return_to_sender( test , usdc_token );
        };

        next_tx(test, user_1);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            amm::swap<USDC, SUI>(&mut global, mint<USDC>(100_000_000, ctx(test)), 1, ctx(test)); // 100 USDC
            test_scenario::return_shared(global);
        };

        // Checking
        next_tx(test, user_1);
        { 
            let sui_token = test_scenario::take_from_sender<Coin<SUI>>(test);
            assert!(coin::value(&(sui_token)) == 67191680466, 0); // 67.191680466 SUI at a rate of 1 SUI = 1.495892264 USDC
            test_scenario::return_to_sender( test , sui_token );
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
            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);

            let lp = amm::add_liquidity_non_entry(
                pool,
                mint<USDT>(534_000_000, ctx(test)),  // Mint 534 USDT (scaled by 1e6)
                1,
                mint<XBTC>(1000000 , ctx(test)), // Mint 0.01 XBTC (scaled by 1e8)
                1,
                true,
                ctx(test)
            );

            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_non_entry<USDT, XBTC>(
                 pool,
                 lp,
                 true,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x);
            assert!(529_341_007 == burn_coin_x, 0); // Assert the returned USDT amount (529.341007 USDT)
            let burn_coin_y = burn(coin_y);
            assert!(997_803 == burn_coin_y, 0); // Assert the returned XBTC amount (0.00997803 XBTC)
            
            test_scenario::return_shared(global)
        };

        // Adding then removing liquidity from a 50/50 pool
        next_tx(test, lp_provider);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            
            // Add liquidity to the pool
            let pool = amm::get_mut_pool_for_testing<SUI, USDC>(&mut global);

            let lp = amm::add_liquidity_non_entry(
                pool,
                mint<SUI>(101_000_000_000, ctx(test)),   // Mint 101 SUI (scaled by 1e9)
                1,
                mint<USDC>(150_000_000 , ctx(test)), // Mint 150 USDC (scaled by 1e6)
                1,
                true,
                ctx(test)
            );

            // Remove liquidity from the pool
            let (coin_x, coin_y) = amm::remove_liquidity_non_entry<SUI, USDC>(
                 pool,
                 lp,
                 true,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x); 
            assert!(100_000_124_579 == burn_coin_x, 0); // Assert the returned SUI amount (100 SUI)
            let burn_coin_y = burn(coin_y); 
            assert!(150_000_336 == burn_coin_y, 0); // Assert the returned USDC amount (150 USDC)
            
            test_scenario::return_shared(global)
        };

    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }

}