

#[test_only]
module legato::amm_tests {

    use sui::coin::{  mint_for_testing as mint, burn_for_testing as burn};
    use sui::sui::SUI;
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};

    use legato::amm::{Self, AMMGlobal};
    
    const XBTC_DECIMAL: u8 = 8;
    const USDT_DECIMAL: u8 = 6;

    const XBTC_AMOUNT: u64 = 10_000_000; // 0.1 XBTC
    const USDT_AMOUNT: u64 = 6000_000_000; // 6,000 USDT

    const XXX_AMOUNT: u64 = 38000000000000;
    const ZZZ_AMOUNT: u64 = 64000000000000;

    const MINIMAL_LIQUIDITY: u64 = 1000;
    const MAX_U64: u64 = 18446744073709551615;

    const ONE: u64 = 1_000_000_000;

    // test coins

    struct XBTC {}

    struct USDT {}

    struct BEEP {}

    struct XXX {}

    struct ZZZ {}

    // Tests section

    #[test]
    fun test_order() {
        assert!(amm::is_order<SUI, BEEP>(), 1);
        assert!(amm::is_order<USDT, XBTC>(), 2);
    }

    #[test]
    fun test_register_50_50_pool() {
        let scenario = scenario();
        register_50_50_pool(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_register_10_90_pool() {
        let scenario = scenario();
        register_10_90_pool(&mut scenario);
        end(scenario);
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

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);

            let (reserve_usdt, reserve_xbtc, lp_supply) = amm::get_reserves_size(pool);

            assert!(lp_supply == 24_494_897_427, lp_supply);
            assert!(reserve_usdt == USDT_AMOUNT, 0);
            assert!(reserve_xbtc == XBTC_AMOUNT, 0);

            test_scenario::return_shared(global)
        };

        // doubling liquidity
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

            burn(lp);

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

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);

            let (reserve_usdt, reserve_xbtc, lp_supply) = amm::get_reserves_size(pool);

            assert!(lp_supply == 13_608_276_273, lp_supply);
            assert!(reserve_usdt == 666_666_666, 0);
            assert!(reserve_xbtc == XBTC_AMOUNT, 0);

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