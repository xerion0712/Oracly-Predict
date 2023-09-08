#[test_only]
module legato::vault_tests {

    use sui::coin::{Self, Coin, mint_for_testing as mint};
    use legato::vault::{Self, VAULT};
    use legato::staked_sui::{STAKED_SUI};
    use sui::test_scenario::{Self as test, Scenario, next_tx, next_epoch, ctx};
    use sui::test_utils; 

    const AMT: u64 = 1000;

    #[test]
    public fun test_mint_redeem() {
        let scenario = scenario();
        test_mint_redeem_(&mut scenario);
        test::end(scenario);
    }

    #[test_only]
    fun burn<T>(x: Coin<T>): u64 {
        let value = coin::value(&x);
        test_utils::destroy(x);
        value
    }

    fun test_mint_redeem_(test: &mut Scenario) {
        let (admin, _) = users();

        next_tx(test, admin);
        {
            vault::init_for_testing(ctx(test));
        };

        next_tx(test, admin);
        {
            let reserve_val = test::take_shared(test);
            let reserve = &mut reserve_val;

            assert!(vault::total_supply(reserve) == 0, 0);

            vault::mint(
                reserve,
                mint<STAKED_SUI>(AMT, ctx(test)),
                ctx(test)
            );
             
            assert!(vault::total_supply(reserve) == 1, 1);
            assert!(vault::total_collateral(reserve) == 1000, 2);

            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);

            vault::redeem(reserve, mint<VAULT>(1, ctx(test)), ctx(test));
            
            assert!(vault::total_supply(reserve) == 0, 3);
            assert!(vault::total_collateral(reserve) == 0, 4);

            test::return_shared(reserve_val)
        };
    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address) { (@0xBEEF, @0x1337) }
}