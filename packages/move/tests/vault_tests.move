#[test_only]
module legato::vault_tests {

    // use std::debug;
    use std::vector;
    use sui::coin::{Self, Coin };
    use std::string::{Self};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
    use sui_system::sui_system::{ Self, SuiSystemState, validator_staking_pool_id, epoch};
    // use sui::tx_context::{Self};
    use legato::vault::{Self, ManagerCap, Vault, TOKEN, PT };
    use sui::object::{ID};
   
    use sui_system::governance_test_utils::{  
        // Self,
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };
    use sui_system::staking_pool::{ StakedSui};

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    // ======== Asserts ========
    const ASSERT_CHECK_APY: u64 = 1;
    const ASSERT_CHECK_WHITELIST: u64 = 2;
    const ASSERT_CHECK_PT_OUTPUT: u64 = 3;
    const ASSERT_CHECK_PT_BALANCE: u64 = 4;

    /// A witness type for the vault creation;
    /// The vault provider's identifier.
    struct JAN_2024 has drop {}

    #[test]
    public fun test_vault_normal_flow() {
        let scenario = scenario();

        test_vault_normal_flow_(&mut scenario);

        test::end(scenario);
    }

    fun test_vault_normal_flow_(test: &mut Scenario) {
        set_up_sui_system_state();
        forward_100_epoch(test);

        // setup a vault
        next_tx(test, ADMIN_ADDR);
        {
            vault::test_init(ctx(test));
        };

        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let system_state_mut_ref = &mut system_state;

            let managercap = test::take_from_sender<ManagerCap>(test);
            let pools = vector::empty<ID>();

            // add all pools
            let pool_id_1 = validator_staking_pool_id(system_state_mut_ref, VALIDATOR_ADDR_1);
            let pool_id_2 = validator_staking_pool_id(system_state_mut_ref, VALIDATOR_ADDR_2);
            let pool_id_3 = validator_staking_pool_id(system_state_mut_ref, VALIDATOR_ADDR_3);
            let pool_id_4 = validator_staking_pool_id(system_state_mut_ref, VALIDATOR_ADDR_4);

            vector::push_back<ID>(&mut pools, pool_id_1);
            vector::push_back<ID>(&mut pools, pool_id_2);
            vector::push_back<ID>(&mut pools, pool_id_3);
            vector::push_back<ID>(&mut pools, pool_id_4);

            let maturity_epoch = epoch(&mut system_state)+100;

            vault::new_vault(&mut managercap, JAN_2024 {},  string::utf8(b"Test Vault"), string::utf8(b"TEST"), pools , maturity_epoch,  ctx(test));

            test::return_to_sender(test, managercap);
            test::return_shared(system_state);
        };

        // check vault APY
        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let reserve = test::take_shared<Vault<JAN_2024>>(test);

            let current_epoch = epoch(&mut system_state);
            let current_apy = vault::vault_apy(&mut system_state, &mut reserve , current_epoch);
 
            // debug::print(&current_apy);
            assert!(current_apy == 45148018, ASSERT_CHECK_APY); // APY = 4.51%

            // then check derivative tokens will be received 
            let pt_amount = vault::estimate_pt_output( &mut system_state, &mut reserve , 10_000_000_000, current_epoch);

            // debug::print(&pt_amount);
            assert!(pt_amount == 10123693200, ASSERT_CHECK_PT_OUTPUT); // PT = 10.1239

            test::return_shared(system_state);
            test::return_shared(reserve);
        };

        // whitelisting users
        next_tx(test, ADMIN_ADDR);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let reserve = test::take_shared<Vault<JAN_2024>>(test);

            vault::whitelist_user(&mut reserve, &mut managercap, STAKER_ADDR_1 );
            vault::whitelist_user(&mut reserve, &mut managercap, STAKER_ADDR_2 );

            // debug::print(&result);

            assert!(vault::check_whitelist(&mut reserve, STAKER_ADDR_1), ASSERT_CHECK_APY);
            assert!(vault::check_whitelist(&mut reserve, STAKER_ADDR_2), ASSERT_CHECK_APY);

            test::return_to_sender(test, managercap);
            test::return_shared(reserve);
        };

        // Stake 100 SUI
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            sui_system::request_add_stake(&mut system_state, coin::mint_for_testing(100 * MIST_PER_SUI, ctx(test)), VALIDATOR_ADDR_1, ctx(test));
            test::return_shared(system_state);
        };

        // mint PT
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let reserve = test::take_shared<Vault<JAN_2024>>(test);
            let staked_sui = test::take_from_sender<StakedSui>(test);

            vault::mint<JAN_2024>(&mut system_state, &mut reserve, staked_sui, ctx(test));

            test::return_shared(system_state);
            test::return_shared(reserve);
        };

        // check PT balance
        next_tx(test, STAKER_ADDR_1);
        {
            let pt_token = test::take_from_sender<Coin<TOKEN<JAN_2024,PT>>>(test);
            assert!( coin::value(&pt_token) == 101236932000, ASSERT_CHECK_PT_BALANCE );
            coin::burn_for_testing(pt_token);
        };
        
    }

    fun forward_100_epoch(test: &mut Scenario) {

        let i = 0;
        while (i < 100) {
            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };

    }

    fun set_up_sui_system_state() {
        let scenario_val = test::begin(@0x0);
        let scenario = &mut scenario_val;
        let ctx = test::ctx(scenario);

        let validators = vector[
            create_validator_for_testing(VALIDATOR_ADDR_1, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_2, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_3, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_4, 1000000, ctx),
        ];
        create_sui_system_state_for_testing(validators, 40000000, 0, ctx);

        test::end(scenario_val);
    }

    fun validator_addrs() : vector<address> {
        vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4]
    }

    fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }

}