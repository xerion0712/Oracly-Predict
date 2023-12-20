#[test_only]
module legato::vault_tests {

    use std::vector;
    use std::string::{Self};
    use sui::coin::{Self };
    use sui::object::{ID};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
    use sui_system::sui_system::{  Self, SuiSystemState, validator_staking_pool_id, epoch };
    use sui_system::staking_pool::{ StakedSui};

    use legato::vault::{Self, ManagerCap, Vault };
    
    

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
    const ASSERT_CHECK_LOCKED_AMOUNT: u64 = 5;

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
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup a vault
        next_tx(test, ADMIN_ADDR);
        {
            vault::test_init(ctx(test));
        };

        // vault matures in 60 epochs
        next_tx(test, ADMIN_ADDR);
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

            vault::new_vault(&mut managercap, JAN_2024 {},  string::utf8(b"Test Vault"), string::utf8(b"TEST"), pools , maturity_epoch,  ctx(test));

            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

        // whitelisting users
        next_tx(test, ADMIN_ADDR);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);

            vault::add_user(&mut vault, &mut managercap, STAKER_ADDR_1 );
            vault::add_user(&mut vault, &mut managercap, STAKER_ADDR_2 );

            test::return_to_sender(test, managercap);
            test::return_shared(vault);
        };

        // Stake 100 SUI for Staker#1
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            sui_system::request_add_stake(&mut system_state, coin::mint_for_testing(100 * MIST_PER_SUI, ctx(test)), VALIDATOR_ADDR_1, ctx(test));
            test::return_shared(system_state);
        };

        // Mint PT for Staker#1
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);
            let staked_sui = test::take_from_sender<StakedSui>(test);

            vault::mint<JAN_2024>(&mut system_state, &mut vault, staked_sui, ctx(test));

            test::return_shared(system_state);
            test::return_shared(vault);
        };

        // Staked 200 SUI for Staker#2
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            sui_system::request_add_stake(&mut system_state, coin::mint_for_testing(200 * MIST_PER_SUI, ctx(test)), VALIDATOR_ADDR_2, ctx(test));
            test::return_shared(system_state);
        };

        // Mint PT for Staker#2
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let vault = test::take_shared<Vault<JAN_2024>>(test);
            let staked_sui = test::take_from_sender<StakedSui>(test);

            vault::mint<JAN_2024>(&mut system_state, &mut vault, staked_sui, ctx(test));

            test::return_shared(system_state);
            test::return_shared(vault);
        };

        advance_epoch(test, 60);

        // Redeem after the vault matures
        

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

    fun validator_addrs() : vector<address> {
        vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4]
    }

    fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }
}