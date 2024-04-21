
#[test_only]
module legato::amm_tests {

    use sui::coin::{  mint_for_testing as mint, burn_for_testing as burn};
    // use sui::sui::SUI;
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};

    use legato::amm::{Self, AMMGlobal};
    
    const XBTC_DECIMAL: u8 = 8;
    const USDT_DECIMAL: u8 = 6;

    const XBTC_AMOUNT: u64 = 10_000_000; // 0.1 XBTC
    const USDT_AMOUNT: u64 = 6000_000_000; // 6,000 USDT

    // test coins

    struct XBTC {}

    struct USDT {}

    #[test]
    fun test_register_50_50_pool() {
        let scenario = scenario();
        register_50_50_pool(&mut scenario);
        end(scenario);
    }

    // #[test]
    // fun test_register_10_90_pool() {
    //     let scenario = scenario();
    //     register_10_90_pool(&mut scenario);
    //     end(scenario);
    // }

    #[test]
    fun test_remove_liquidity() {
        let scenario = scenario();
        remove_liquidity(&mut scenario);
        end(scenario);
    }

    fun remove_liquidity(test: &mut Scenario) {
        let (owner, _) = people();

        register_50_50_pool(test);

        // adding then removing
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(600_000_000, ctx(test)), // 10%
                mint<XBTC>(1_000_000, ctx(test)), // 10%
                5000,
                5000,
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
            assert!(599999999 == burn_coin_x, 0);
            let burn_coin_y = burn(coin_y); 
            assert!(999999 == burn_coin_y, 0);

            test_scenario::return_shared(global)
        };

    }

    fun register_50_50_pool(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
        {
            amm::test_init(ctx(test));
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(USDT_AMOUNT, ctx(test)),
                mint<XBTC>(XBTC_AMOUNT, ctx(test)),
                5000,
                5000,
                6,
                8,
                ctx(test)
            );

            let burn = burn(lp);

            assert!(burn == 24_494_896_427, burn);

            test_scenario::return_shared(global)
        };

        // doubling liquidity
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(600_000_000, ctx(test)), // 10%
                mint<XBTC>(1_000_000, ctx(test)), // 10%
                5000,
                5000,
                6,
                8,
                ctx(test)
            );

            let burn = burn(lp);

            assert!(burn == 2_449_489_742, burn);

            test_scenario::return_shared(global)
        };

    }

    fun register_10_90_pool(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
        {
            amm::test_init(ctx(test));
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(666_666_666, ctx(test)), // 666 USDT
                mint<XBTC>(XBTC_AMOUNT, ctx(test)), // 0.1 BTC
                1000,
                9000,
                6,
                8,
                ctx(test)
            );

            let burn = burn(lp);

            assert!(burn == 13_608_275_273, burn);

            test_scenario::return_shared(global)
        };

        // doubling liquidity
        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(666_666_666, ctx(test)), // 666 USDT
                mint<XBTC>(10_000_000, ctx(test)), // 0.1 BTC
                1000,
                9000,
                6,
                8,
                ctx(test)
            );

            burn(lp);

            test_scenario::return_shared(global)
        };
 
    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }

}