#[test_only]
module legato::vault_tests {

    use sui::sui::SUI;
    use sui::coin::{Self}; 
    use legato::staked_sui::{Self, StakedSui};
    use legato::vault::{Self, Reserve, ManagerCap, TOKEN, PT };
    use sui::test_scenario::{Self as test, Scenario, next_tx, next_epoch, ctx};

    const LOCK_AMOUNT: u64 = 10000000000; // 10 SUI

    #[test]
    public fun test_mint_redeem_after_expired() {
        let scenario = scenario();
        test_mint_redeem_(&mut scenario);
        test::end(scenario);
    }

    fun test_mint_redeem_(test: &mut Scenario) {
        let (admin, _) = users();

        next_tx(test, admin);
        {
            vault::test_init(ctx(test));
        };

        // Setup Vault that locks Staked SUI for 10 Epoch
        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            vault::new_vault(&mut managercap,  10,coin::mint_for_testing<SUI>(LOCK_AMOUNT, ctx(test)), staked_sui::wrap_for_new_vault(coin::mint_for_testing<SUI>(LOCK_AMOUNT, ctx(test)), ctx(test)), ctx(test));
            test::return_to_sender(test, managercap);
        };

        // Update APR value on Oracle
        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let reserve_val = test::take_shared<Reserve>(test);
            let reserve = &mut reserve_val;

            // 4.00%
            vault::update_feed_value(&mut managercap, reserve, 4000, ctx(test));

            test::return_to_sender(test, managercap);
            test::return_shared(reserve_val);
        };

        // Wraps SUI into Staked SUI obj,
        next_tx(test, admin);
        {
            let sui_token = coin::mint_for_testing<SUI>(LOCK_AMOUNT, ctx(test));
            staked_sui::wrap(sui_token, ctx(test));
        };
        
        // Locks Staked SUI into the vault
        next_tx(test, admin);
        {
            let reserve = test::take_shared<Reserve>(test);
            let my_staked_sui = test::take_from_sender<StakedSui>(test);

            // check the supply
            assert!(vault::total_pt_supply(&reserve) == 0, 1);
            // assert!(vault::total_yt_supply(reserve) == YT_TOTAL_SUPPLY, 2);
            // check feed value
            assert!(vault::feed_value(&reserve) == 4000, 2);

            vault::lock(
                &mut reserve,
                my_staked_sui,
                ctx(test)
            );

            assert!(vault::balance(&reserve) == LOCK_AMOUNT, 3);
            assert!(vault::total_pt_supply(&reserve) ==  LOCK_AMOUNT+10958904, 4);

            // fast-forward 10 epoch
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);
            next_epoch(test, admin);

            let mock_vault_token = coin::mint_for_testing<TOKEN<PT>>(LOCK_AMOUNT, ctx(test));

            vault::unlock_after_mature(
                &mut reserve,
                0,
                &mut mock_vault_token,
                ctx(test)
            );

            assert!(vault::balance(&reserve) == 0, 5);

            coin::burn_for_testing(mock_vault_token);
            test::return_shared(reserve);
        };

    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address) { (@0xBEEF, @0x1337) }
}