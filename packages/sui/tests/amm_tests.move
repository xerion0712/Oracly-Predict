

#[test_only]
module legato::amm_tests {

    use std::vector;

    use sui::coin::{Self, Coin, mint_for_testing as mint, burn_for_testing as burn};
    use sui::sui::SUI;
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};

    use legato::amm::{Self, AMMGlobal};
    use legato::math::{sqrt, mul_to_u128};

    const XBTC_AMOUNT: u64 = 100000000;
    const USDT_AMOUNT: u64 = 1900000000000;

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
    fun test_add_liquidity_with_register() {
        let scenario = scenario();
        add_liquidity_with_register(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_add_liquidity() {
        let scenario = scenario();
        add_liquidity(&mut scenario);
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
    fun test_router() {
        let scenario = scenario();
        test_router_(&mut scenario);
        end(scenario);
    }


    fun add_liquidity_with_register(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
        {
            amm::init_for_testing(ctx(test));
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(USDT_AMOUNT, ctx(test)),
                mint<XBTC>(XBTC_AMOUNT, ctx(test)),
                ctx(test)
            );

            let burn = burn(lp);
            assert!(burn == sqrt(mul_to_u128(USDT_AMOUNT, XBTC_AMOUNT)) - MINIMAL_LIQUIDITY, burn);

            test_scenario::return_shared(global)
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);

            let (reserve_usdt, reserve_xbtc, lp_supply) = amm::get_reserves_size(pool);

            assert!(lp_supply == sqrt(mul_to_u128(USDT_AMOUNT, XBTC_AMOUNT)), lp_supply);
            assert!(reserve_usdt == USDT_AMOUNT, 0);
            assert!(reserve_xbtc == XBTC_AMOUNT, 0);

            test_scenario::return_shared(global)
        };
    }

    fun setup_multi_pool(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
        {
            amm::init_for_testing(ctx(test));
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<XXX, USDT>(
                &mut global,
                mint<XXX>(XXX_AMOUNT, ctx(test)),
                mint<USDT>(USDT_AMOUNT, ctx(test)),
                ctx(test)
            );
            
            burn(lp);
            test_scenario::return_shared(global)
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            let (lp, _pool_id) = amm::add_liquidity_for_testing<ZZZ, USDT>(
                &mut global,
                mint<ZZZ>(ZZZ_AMOUNT, ctx(test)),
                mint<USDT>(USDT_AMOUNT, ctx(test)),
                ctx(test)
            );

            burn(lp);
            test_scenario::return_shared(global)
        };

    }

    /// Expect LP tokens to double in supply when the same values passed
    fun add_liquidity(test: &mut Scenario) {
        add_liquidity_with_register(test);

        let (_, theguy) = people();

        next_tx(test, theguy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);

            let (reserve_usdt, reserve_xbtc, _lp_supply) = amm::get_reserves_size<USDT, XBTC>(pool);

            let (lp_tokens, _returns) = amm::add_liquidity_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(reserve_usdt / 100, ctx(test)),
                mint<XBTC>(reserve_xbtc / 100, ctx(test)),
                ctx(test)
            );

            let burn = burn(lp_tokens);
            assert!(burn == 137840487, burn);

            test_scenario::return_shared(global)
        };
    }

    fun swap_usdt_for_xbtc(test: &mut Scenario) {
        add_liquidity_with_register(test);

        let (_, the_guy) = people();

        next_tx(test, the_guy);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);
            let (reserve_usdt, reserve_xbtc, _lp_supply) = amm::get_reserves_size<USDT, XBTC>(pool);

            let expected_xbtc = amm::get_amount_out(
                USDT_AMOUNT / 100,
                reserve_usdt,
                reserve_xbtc
            );

            let returns = amm::swap_for_testing<USDT, XBTC>(
                &mut global,
                mint<USDT>(USDT_AMOUNT / 100, ctx(test)),
                1,
                ctx(test)
            );
            assert!(vector::length(&returns) == 4, vector::length(&returns));

            let coin_out = vector::borrow(&returns, 3);
            assert!(*coin_out == expected_xbtc, *coin_out);

            test_scenario::return_shared(global);
        };
    }

    fun swap_xbtc_for_usdt(test: &mut Scenario) {
        swap_usdt_for_xbtc(test);

        let (owner, _) = people();

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);
            let pool = amm::get_mut_pool_for_testing<USDT, XBTC>(&mut global);
            let (reserve_usdt, reserve_xbtc, _lp_supply) = amm::get_reserves_size<USDT, XBTC>(pool);

            let expected_usdt = amm::get_amount_out(
                XBTC_AMOUNT / 100,
                reserve_xbtc,
                reserve_usdt
            );

            let returns = amm::swap_for_testing<XBTC, USDT>(
                &mut global,
                mint<XBTC>(XBTC_AMOUNT / 100, ctx(test)),
                1,
                ctx(test)
            );
            assert!(vector::length(&returns) == 4, vector::length(&returns));

            let coin_out = vector::borrow(&returns, 1);
            assert!(*coin_out == expected_usdt, expected_usdt);

            test_scenario::return_shared(global);
        };
    }

    fun test_router_(test: &mut Scenario) {
        setup_multi_pool(test);

        let (_, user) = people();

        next_tx(test, user);
        {
            let global = test_scenario::take_shared<AMMGlobal>(test);

            amm::swap_xyz<XXX, USDT, ZZZ>(
                &mut global,
                mint<XXX>(ONE, ctx(test)),
                1,
                ctx(test)
            );
            
            test_scenario::return_shared(global);
        };

        next_tx(test, user);
        {
            let zzz_token = test_scenario::take_from_sender<Coin<ZZZ>>(test);

            assert!(coin::value(&zzz_token) == 1684121880, 4);
            burn(zzz_token); 
        };

    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }

}