#[test_only]
module legato::vault_tests {

    use legato::vault::{Self, ManagerCap, Reserve, PT};
    use legato::staked_sui::{STAKED_SUI};
    use sui::coin;
    // use sui::pay;
    use sui::test_scenario::{Self as test, Scenario, next_tx ,next_epoch, ctx};

    const YT_TOTAL_SUPPLY: u64 = 1000000000;
    const LOCK_AMOUNT: u64 = 100000; // 100 Staked Sui
    
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

        // Setup Vault for 10 Epoch
        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            vault::new_vault<STAKED_SUI>(&mut managercap, 10, ctx(test));
            test::return_to_sender(test, managercap);
        };

        // Update APR value on Oracle
         next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let reserve_val = test::take_shared<Reserve<STAKED_SUI>>(test);
            let reserve = &mut reserve_val;

            // 4.00%
            vault::update_feed_value<STAKED_SUI>(&mut managercap, reserve, 4000, ctx(test));

            test::return_to_sender(test, managercap);
            test::return_shared(reserve_val);
        };

        next_tx(test, admin);
        {
            let reserve_val = test::take_shared<Reserve<STAKED_SUI>>(test);
            let reserve = &mut reserve_val;

            // check the supply
            assert!(vault::total_pt_supply(reserve) == 0, 1);
            assert!(vault::total_yt_supply(reserve) == YT_TOTAL_SUPPLY, 2);
            // check feed value
            assert!(vault::feed_value(reserve) == 4000, 3);

            // lock tokens
            let mock_staked_sui = coin::mint_for_testing<STAKED_SUI>(LOCK_AMOUNT, ctx(test));

            vault::lock(
                reserve,
                mock_staked_sui,
                ctx(test)
            );

            assert!(vault::total_pt_supply(reserve) ==  LOCK_AMOUNT+109, 3);
            assert!(vault::total_collateral(reserve) == LOCK_AMOUNT, 4);

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

            let mock_vault_token = coin::mint_for_testing<PT<STAKED_SUI>>(LOCK_AMOUNT, ctx(test));

            vault::unlock(
                reserve,
                mock_vault_token,
                ctx(test)
            );

            assert!(vault::total_collateral(reserve) == 0, 5);

            // pay::keep(mock_staked_sui, ctx(test));
            // pay::keep(mock_vault_token, ctx(test));
            test::return_shared(reserve_val);
        };
    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address) { (@0xBEEF, @0x1337) }
}