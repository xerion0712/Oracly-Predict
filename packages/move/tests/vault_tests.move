#[test_only]
module legato::vault_tests {

    use sui::sui::SUI;
    use sui::coin::{Self}; 
    use legato::staked_sui::{Self, StakedSui};
    use legato::vault::{Self, Reserve, ManagerCap, TOKEN, PT };
    use sui::test_scenario::{Self as test, Scenario, next_tx, next_epoch, ctx};

    const LOCK_AMOUNT: u64 = 10000000000; // 10 SUI
    const ONE : u64 = 1000000000;

    #[test]
    public fun test_mint_redeem_after_expired() {
        let scenario = scenario();
        test_mint_redeem_(&mut scenario);
        test::end(scenario);
    }

    #[test]
    public fun test_mint_yt_claim() {
        let scenario = scenario();
        test_mint_yt_claim_(&mut scenario);
        test::end(scenario);
    }

    fun test_mint_redeem_(test: &mut Scenario) {
        let (admin, _, _) = users();

        next_tx(test, admin);
        {
            vault::test_init(ctx(test));
        };

        // Setup Vault that locks Staked SUI for 10 Epoch
        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            vault::new_vault(&mut managercap,  10,coin::mint_for_testing<SUI>(LOCK_AMOUNT, ctx(test)), ctx(test));
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

    fun test_mint_yt_claim_(test: &mut Scenario) {
        let (admin, trader, _) = users();

        next_tx(test, admin);
        {
            vault::test_init(ctx(test));
        };

        // Setup Vault that locks Staked SUI for 120 Epoch
        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            vault::new_vault(&mut managercap,  120,coin::mint_for_testing<SUI>(100000000000, ctx(test)), ctx(test));
            test::return_to_sender(test, managercap);
        };

        // Use 3% APR 
        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let reserve = test::take_shared<Reserve>(test);
            // 3.00%
            vault::update_feed_value(&mut managercap, &mut reserve, 3000, ctx(test));

            test::return_to_sender(test, managercap);
            test::return_shared(reserve);
        };

        // Locks Staked SUI into the vault
        next_tx(test, admin);
        {
            let reserve = test::take_shared<Reserve>(test);

            vault::lock(
                &mut reserve,
                staked_sui::wrap_for_new_vault(coin::mint_for_testing<SUI>(LOCK_AMOUNT, ctx(test)) , ctx(test)),
                ctx(test)
            );

            test::return_shared(reserve);
        };

        // FORWARD 100 EPOCH AND RISE THE APR TO 5%
        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let reserve = test::take_shared<Reserve>(test);
            vault::update_feed_value(&mut managercap, &mut reserve, 5000, ctx(test));
        
            let count = 0;
            while(count < 100 ) {
                next_epoch(test, admin);
                count = count + 1;
            };

            // top up reward
            let sui_token = coin::mint_for_testing<SUI>(LOCK_AMOUNT, ctx(test));
            vault::update_reward_pool(&mut reserve, &mut sui_token, ctx(test));

            // claim rewards
            vault::claim(&mut reserve, ctx(test));

            coin::burn_for_testing(sui_token);
            test::return_to_sender(test, managercap);
            test::return_shared(reserve);
        };

        // BUY 9,900 YT with 1 SUI
        next_tx(test, trader);
        {
            let reserve = test::take_shared<Reserve>(test);
            let sui_token = coin::mint_for_testing<SUI>(ONE, ctx(test));

            vault::swap_sui(&mut reserve, ONE, &mut sui_token, ctx(test));

            coin::burn_for_testing(sui_token);

            test::return_shared(reserve);
        };

    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address, address) { (@0xBEEF, @0x1337, @0x2222) }
}