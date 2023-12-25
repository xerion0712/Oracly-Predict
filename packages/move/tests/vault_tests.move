

#[test_only]
module legato::vault_tests {

    // use std::debug;

    use std::vector;
    use std::string::{Self};
    use sui::coin::{Self, Coin };
    use sui::object::{ID};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
    use sui_system::sui_system::{ Self, SuiSystemState, validator_staking_pool_id, epoch };
    use sui_system::staking_pool::{ StakedSui};

    use legato::vault::{Self, ManagerCap, Vault, TOKEN, PT };
    // use legato::apy_reader::{Self};
    
    use sui_system::governance_test_utils::{  
        // Self,
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };

    const VAULT_MATURE_IN : u64 = 60;

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
    const ASSERT_CHECK_REWARDS: u64 = 5;
    const ASSERT_CHECK_DEBTS: u64 = 6;
    const ASSERT_CHECK_VALUES: u64 = 7;

    /// A witness type for the vault creation;
    /// The vault provider's identifier.
    struct JAN_2024 has drop {}

    #[test]
    public fun test_balanced_flow() {
        let scenario = scenario();
        test_balanced_flow_(&mut scenario);
        test::end(scenario);
    }

    #[test]
    public fun test_deficit_flow() {
        let scenario = scenario();
        test_deficit_flow_(&mut scenario);
        test::end(scenario);
    }

    #[test]
    public fun test_surplus_flow() {
        let scenario = scenario();
        test_surplus_flow_(&mut scenario);
        test::end(scenario);
    }

    // the balanced state, where the debts equal the accumulated rewards.
    fun test_balanced_flow_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup a vault
        setup_vault(test, ADMIN_ADDR);

        // whitelisting users
        whitelist_users(test, ADMIN_ADDR);

        // Using median APY
        next_tx(test, ADMIN_ADDR);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);

            let current_epoch = epoch(&mut system_state);
            let median_apy = vault::median_apy(&mut system_state, &vault, current_epoch);
            
            // debug::print(&median_apy);

            assert!(median_apy == 45485582, ASSERT_CHECK_APY);
            vault::update_vault_apy( &mut system_state, &mut vault ,&mut managercap, median_apy, ctx(test));

            test::return_shared(system_state);
            test::return_shared(vault);
            test::return_to_sender(test, managercap);
        };

        stake_and_mint(test, STAKER_ADDR_1, 100 * MIST_PER_SUI, VALIDATOR_ADDR_1);
        stake_and_mint(test, STAKER_ADDR_2, 200 * MIST_PER_SUI, VALIDATOR_ADDR_2);

        advance_epoch(test, 61);
 
        // Redeem across 2 locked Staked SUI
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);
            let pt_token = test::take_from_sender<Coin<TOKEN<JAN_2024,PT>>>(test);

            let current_epoch = epoch(&mut system_state);

            // test-out getter functions
            let total_rewards = vault::vault_rewards(&mut system_state, &vault, current_epoch);
            let total_debts = vault::vault_debts(&vault);

            assert!(total_rewards == 2238156427, ASSERT_CHECK_REWARDS);
            assert!(total_debts == 2243124591, ASSERT_CHECK_DEBTS);

            // Split 150 PT for withdrawal
            let pt_to_withdraw = coin::split(&mut pt_token, 150 * MIST_PER_SUI, ctx(test));

            vault::redeem<JAN_2024>(&mut system_state, &mut vault, pt_to_withdraw, ctx(test));

            let principal = vault::vault_principals(&vault);
            let debts = vault::vault_debts(&vault);
            let pending = vault::vault_pending(&vault);

            assert!(principal == 0, ASSERT_CHECK_VALUES);
            assert!(debts == 4968164, ASSERT_CHECK_VALUES);
            assert!(pending == 152238156427, ASSERT_CHECK_VALUES);

            test::return_shared(vault);
            test::return_shared(system_state);
            coin::burn_for_testing(pt_token);
        };
        

    }

    // the deficit state, where the outstanding debt exceeds the accumulated rewards 
    fun test_deficit_flow_(test: &mut Scenario) {
        set_up_sui_system_state_imbalance();
        advance_epoch(test, 40);

        // setup a vault
        setup_vault(test, ADMIN_ADDR);

        // whitelisting users
        whitelist_users(test, ADMIN_ADDR);

        // Using ceil APY
        next_tx(test, ADMIN_ADDR);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);

            let current_epoch = epoch(&mut system_state);
            let ceil_apy = vault::ceil_apy(&mut system_state, &vault, current_epoch);
       
            assert!(ceil_apy == 45485582, ASSERT_CHECK_APY);
            vault::update_vault_apy( &mut system_state, &mut vault, &mut managercap, ceil_apy, ctx(test));

            test::return_shared(system_state);
            test::return_shared(vault);
            test::return_to_sender(test, managercap);
        };

        stake_and_mint(test, STAKER_ADDR_1, 100 * MIST_PER_SUI, VALIDATOR_ADDR_1);

        advance_epoch(test, 61);

        // requires manual top-up from the project to redeem the full amount
        next_tx(test, ADMIN_ADDR);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);
            let topup_sui = coin::mint_for_testing<SUI>( MIST_PER_SUI, ctx(test));

            vault::topup<JAN_2024>(&mut vault, &managercap, topup_sui);

            test::return_shared(vault);
            test::return_to_sender(test, managercap);
        };

        // Redeem
        next_tx(test, STAKER_ADDR_1);
        {
            
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);
            let pt_token = test::take_from_sender<Coin<TOKEN<JAN_2024,PT>>>(test);

            vault::redeem<JAN_2024>(&mut system_state, &mut vault, pt_token, ctx(test));

            test::return_shared(vault);
            test::return_shared(system_state);
        };

    }

    // the surplus state, where the accumulated rewards exceed the outstanding debt
    // additionally, YT holders are able to claim rewards from the surplus
    fun test_surplus_flow_(test: &mut Scenario) {
        set_up_sui_system_state_imbalance();
        advance_epoch(test, 40);

        // setup a vault
        setup_vault(test, ADMIN_ADDR);

        // whitelisting users
        whitelist_users(test, ADMIN_ADDR);

        // Using ceil APY
        next_tx(test, ADMIN_ADDR);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);

            let current_epoch = epoch(&mut system_state);
            let floor_apy = vault::floor_apy(&mut system_state, &vault, current_epoch);
       
            assert!(floor_apy == 18227552, ASSERT_CHECK_APY);
            vault::update_vault_apy( &mut system_state, &mut vault, &mut managercap, floor_apy, ctx(test));

            test::return_shared(system_state);
            test::return_shared(vault);
            test::return_to_sender(test, managercap);
        };

    }

    fun advance_epoch(test: &mut Scenario, value: u64) {
        let i = 0;
        while (i < value) {
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

    fun set_up_sui_system_state_imbalance() {
        let scenario_val = test::begin(@0x0);
        let scenario = &mut scenario_val;
        let ctx = test::ctx(scenario);

        let validators = vector[
            create_validator_for_testing(VALIDATOR_ADDR_1, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_2, 1500000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_3, 2000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_4, 2500000, ctx),
        ];
        create_sui_system_state_for_testing(validators, 70000000, 0, ctx);

        test::end(scenario_val);
    }

    fun stake_and_mint(test: &mut Scenario, staker_address: address, amount : u64, validator_address: address) {

        next_tx(test, staker_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            sui_system::request_add_stake(&mut system_state, coin::mint_for_testing(amount, ctx(test)), validator_address, ctx(test));
            test::return_shared(system_state);
        };

        next_tx(test, staker_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);
            let staked_sui = test::take_from_sender<StakedSui>(test);

            vault::mint<JAN_2024>(&mut system_state, &mut vault, staked_sui, ctx(test));

            test::return_shared(system_state);
            test::return_shared(vault);
        };

    }

    fun setup_vault(test: &mut Scenario, admin_address:address) {

        next_tx(test, admin_address);
        {
            vault::test_init(ctx(test));
        };

        // vault matures in 60 epochs
        next_tx(test, admin_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let managercap = test::take_from_sender<ManagerCap>(test);
            let pools = vector::empty<ID>();

            // add all pools
            let pool_id_1 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_1);
            let pool_id_2 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_2);
            let pool_id_3 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_3);
            let pool_id_4 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_4);

            vector::push_back<ID>(&mut pools, pool_id_1);
            vector::push_back<ID>(&mut pools, pool_id_2);
            vector::push_back<ID>(&mut pools, pool_id_3);
            vector::push_back<ID>(&mut pools, pool_id_4);

            let maturity_epoch = epoch(&mut system_state)+VAULT_MATURE_IN;
            let initial_apy = 30000000; // APY = 3%

            vault::new_vault(&mut managercap, JAN_2024 {},  string::utf8(b"Test Vault"), string::utf8(b"TEST"), initial_apy, pools , maturity_epoch,  ctx(test));

            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

    }

    fun whitelist_users(test: &mut Scenario, admin_address:address) {
        next_tx(test, admin_address);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);

            vault::add_user(&mut vault, &mut managercap, STAKER_ADDR_1 );
            vault::add_user(&mut vault, &mut managercap, STAKER_ADDR_2 );

            test::return_to_sender(test, managercap);
            test::return_shared(vault);
        };
    }

    fun validator_addrs() : vector<address> {
        vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4]
    }

    fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }

}