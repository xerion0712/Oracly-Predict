
// run through basic tests, including using YT tokens to claim excess yield.

#[test_only]
module legato::vault_basic_tests {

    // use std::debug;

    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
    use sui_system::sui_system::{ SuiSystemState, epoch };
    use sui::sui::SUI;
    use legato::vault_utils::{
        scenario, 
        advance_epoch,
        set_up_sui_system_state,
        setup_vault,
        stake_and_mint,
        advance_epoch_with_snapshot,
        buy_yt
    };
    use legato::vault_template::{JAN_2024 };
    use legato::vault::{Self, Global, ManagerCap, PT_TOKEN, YT_TOKEN};
    use legato::lp_staking::{Self, Staking};

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;
    const STAKER_ADDR_3: address = @0x44;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    // ======== Asserts ========
    const ASSERT_CHECK_APY: u64 = 1;
    const ASSERT_CHECK_AMOUNT: u64 = 2;

    // the balanced state, where the debts equal the accumulated rewards
    #[test]
    public fun test_balanced_flow() {
        let scenario = scenario();
        test_balanced_flow_(&mut scenario);
        test::end(scenario);
    }

    // the deficit state, where the outstanding debt exceeds the accumulated rewards 
    #[test]
    public fun test_deficit_flow() {
        let scenario = scenario();
        test_deficit_flow_(&mut scenario);
        test::end(scenario);
    }

    // the surplus state, where the accumulated rewards exceed the outstanding debt
    // additionally, YT holders are able to claim rewards from the surplus
    #[test]
    public fun test_surplus_flow() {
        let scenario = scenario();
        test_surplus_flow_(&mut scenario);
        test::end(scenario);
    }

    fun test_balanced_flow_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR);
    
        // Using median APY
        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let managercap = test::take_from_sender<ManagerCap>(test); 
      
            let current_epoch = epoch(&mut system_state);
            let median_apy = vault::median_apy(&mut system_state, &global, current_epoch);

            vault::update_vault_apy<JAN_2024>(&mut global, &mut managercap , median_apy);

            // vault::set_deposit_cap(&mut global, &mut managercap, 100_000_000_000);

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

        // mint PT on 1st vault
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 100 * MIST_PER_SUI, VALIDATOR_ADDR_1);
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_2, 200 * MIST_PER_SUI, VALIDATOR_ADDR_2);

        advance_epoch(test, 61);

        // Redeem across 2 locked Staked SUI
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let pt_token = test::take_from_sender<Coin<PT_TOKEN<JAN_2024>>>(test);

            // Split 150 PT for withdrawal
            let pt_to_withdraw = coin::split(&mut pt_token, 150 * MIST_PER_SUI, ctx(test));

            vault::redeem<JAN_2024>(&mut system_state, &mut global, pt_to_withdraw, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
            coin::burn_for_testing(pt_token);
        };

    }

    fun test_deficit_flow_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR);

        // Using ceil APY
        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let managercap = test::take_from_sender<ManagerCap>(test); 
      
            let current_epoch = epoch(&mut system_state);
            let ceil_apy = vault::ceil_apy(&mut system_state, &global, current_epoch);

            vault::update_vault_apy<JAN_2024>(&mut global, &mut managercap , ceil_apy);

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 100 * MIST_PER_SUI, VALIDATOR_ADDR_1);

        advance_epoch(test, 61);

        // requires manual top-up from the project to redeem the full amount
        next_tx(test, ADMIN_ADDR);
        {
            let global = test::take_shared<Global>(test);
            let managercap = test::take_from_sender<ManagerCap>(test); 
            let topup_sui = coin::mint_for_testing<SUI>( MIST_PER_SUI, ctx(test));
            vault::emergency_topup_redemption_pool(&mut global, &mut managercap , topup_sui, ctx(test));
            test::return_shared(global);
            test::return_to_sender(test, managercap);
        };

        // Redeem
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let pt_token = test::take_from_sender<Coin<PT_TOKEN<JAN_2024>>>(test);

            vault::redeem<JAN_2024>(&mut system_state, &mut global, pt_token, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
        };

    }

    fun test_surplus_flow_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR);

        // Using floor APY
        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let managercap = test::take_from_sender<ManagerCap>(test); 
      
            let current_epoch = epoch(&mut system_state);
            let floor_apy = vault::floor_apy(&mut system_state, &global, current_epoch);

            vault::update_vault_apy<JAN_2024>(&mut global, &mut managercap , floor_apy);

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };
 
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 100 * MIST_PER_SUI, VALIDATOR_ADDR_1);

        // Buy YT from AMM
        buy_yt( test, 1_000_000, STAKER_ADDR_1 );
        buy_yt( test, 1_000_000, STAKER_ADDR_2 );

        // Staking YT
        next_tx(test, STAKER_ADDR_2);
        {
            let global = test::take_shared<Staking>(test);
            let yt_token = test::take_from_sender<Coin<YT_TOKEN<JAN_2024>>>(test);

            lp_staking::stake<YT_TOKEN<JAN_2024>>(&mut global, coin::split(&mut yt_token, 100_000_000_000, ctx(test)), ctx(test));
            lp_staking::stake<YT_TOKEN<JAN_2024>>(&mut global, coin::split(&mut yt_token, 100_000_000_000, ctx(test)), ctx(test));
            
            test::return_to_sender(test, yt_token);
            test::return_shared(global);
        };

        // Unstaking YT
        next_tx(test, STAKER_ADDR_2);
        {
            let global = test::take_shared<Staking>(test);
            lp_staking::unstake<YT_TOKEN<JAN_2024>>(&mut global, 100_000_000_000, ctx(test));
            test::return_shared(global);
        };

        advance_epoch_with_snapshot<JAN_2024>(test, ADMIN_ADDR , 30);

        // Claim rewards
        next_tx(test, STAKER_ADDR_2);
        {
            let global = test::take_shared<Staking>(test);
            lp_staking::withdraw_rewards<YT_TOKEN<JAN_2024>, PT_TOKEN<JAN_2024>>(&mut global, ctx(test));
            test::return_shared(global);
        };

        // Verify PT
        next_tx(test, STAKER_ADDR_2);
        {
            let pt_token = test::take_from_sender<Coin<PT_TOKEN<JAN_2024>>>(test);
            assert!( coin::value(&pt_token) == 199913769, ASSERT_CHECK_AMOUNT);
            coin::burn_for_testing(pt_token);
        };
    }

}