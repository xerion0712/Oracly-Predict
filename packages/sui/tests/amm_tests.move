


#[test_only]
module legato::amm_tests {

    use std::vector;

    use sui::coin::{  mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};
    use sui::sui::SUI;

    use legato::amm::{Self, AMMGlobal};
    
    const XBTC_DECIMAL: u8 = 8;
    const USDT_DECIMAL: u8 = 6; 
    
    // when setup a 90/10 pool of $100k
    // 50,000 XBTC/USDT at the initial
    const XBTC_AMOUNT: u64 = 180_000_000; // 90% at 1.8 BTC
    const USDT_AMOUNT: u64 = 10_000_000_000; // 10% at 10,000 USDT

    // when setup a 50/50 pool of $100k
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

    // Registering two liquidity pools:
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

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(USDT_AMOUNT, ctx(test)),  
                mint<XBTC>(XBTC_AMOUNT, ctx(test)),  
                1000,
                9000,
                6,
                8,
                ctx(test)
            );

            let burn = burn(lp);   
            assert!(burn == 26_898_565, burn); 

            test_scenario::return_shared(global)
        };

        // add 10% more
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(USDT_AMOUNT / 10, ctx(test)),
                mint<XBTC>(XBTC_AMOUNT / 10, ctx(test)),
                1000,
                9000,
                6,
                8,
                ctx(test)
            );

            let burn = burn(lp);
            assert!(burn == 2_666_882, burn);

            test_scenario::return_shared(global)
        };


        // Setup a 50/50 pool first 
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<SUI, USDC>(
                &mut global,
                mint<SUI>(SUI_AMOUNT, ctx(test)),  
                mint<USDC>(USDC_AMOUNT, ctx(test)),  
                5000,
                5000,
                9,
                6,
                ctx(test)
            );

            let burn = burn(lp);   
            assert!(burn == 129_098_798_372, burn); 

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
            assert!(*coin_out == 197015, *coin_out); // 0.00197015 XBTC at a rate of 1 BTC = 50757 USDT

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
            assert!(*coin_out == 49376974, *coin_out); // 49.376974 USDT at a rate of 1 BTC = 49376 USDT

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
            assert!(*coin_out == 368_517_443, *coin_out); // 368.517443 USDC at a rate of 1 SUI = 1.474069772 USDC

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
            std::debug::print((coin_out));
            assert!(*coin_out == 66_849_734_058, *coin_out); // 66.849734058 SUI at a rate of 1 SUI = 1.495892264 USDC

            test_scenario::return_shared(global);
        };
    }

    fun remove_liquidity(test: &mut Scenario) {
        register_pools(test);

        let (owner, _) = people();

        // adding then removing
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(USDT_AMOUNT / 20, ctx(test)), // 5% - 500 USDT
                mint<XBTC>(XBTC_AMOUNT / 20, ctx(test)), // 5% - 0.09 XBTC
                1000,
                9000,
                6,
                8,
                ctx(test)
            );

            let (coin_x, coin_y) = amm::remove_liquidity_for_testing<USDT, XBTC>(
                 &mut global,
                 lp,
                 ctx(test)
            ); 

            let burn_coin_x = burn(coin_x);  
            assert!(488_488_727 == burn_coin_x, 0); // 488 USDT
            let burn_coin_y = burn(coin_y); 
            assert!(8_945_898 == burn_coin_y, 0); // 0.089 XBTC

            test_scenario::return_shared(global)
        };

    }


    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }


}