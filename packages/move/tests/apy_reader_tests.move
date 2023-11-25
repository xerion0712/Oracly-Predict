#[test_only]
module legato::apy_reader_tests {

    // use std::debug;
    use sui::coin;
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui_system::sui_system::{Self, SuiSystemState, validator_staking_pool_id};
    use sui::tx_context::{Self};
    // use sui_system::staking_pool::{ Self };
    // use sui::table::{Self };

    use sui_system::governance_test_utils::{  
        Self,
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };

    use legato::apy_reader::{Self};

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    #[test]
    public fun test_calculate_apy() {
        let scenario = scenario();

        test_calculate_apy_(&mut scenario);

        test::end(scenario);
    }

    fun test_calculate_apy_(test: &mut Scenario) {
        set_up_sui_system_state();

        // Stake 10 SUI on VALIDATOR_ADDR_1 for STAKER_ADDR_1
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let system_state_mut_ref = &mut system_state;
            
            sui_system::request_add_stake(system_state_mut_ref, coin::mint_for_testing(100 * MIST_PER_SUI, ctx(test)), VALIDATOR_ADDR_1, ctx(test));

            test::return_shared(system_state);
        };

        // Stake 10 SUI on VALIDATOR_ADDR_2 for STAKER_ADDR_2
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let system_state_mut_ref = &mut system_state;
            
            sui_system::request_add_stake(system_state_mut_ref, coin::mint_for_testing(100 * MIST_PER_SUI, ctx(test)), VALIDATOR_ADDR_2, ctx(test));

            test::return_shared(system_state);
        };

        governance_test_utils::advance_epoch(test);

        // forwards 100 epoch
        let i = 0;
        while (i < 100) {
            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };

        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let system_state_mut_ref = &mut system_state;

            let pool_id = validator_staking_pool_id(system_state_mut_ref, VALIDATOR_ADDR_1);
            let current_epoch = tx_context::epoch(ctx(test));

            // debug::print(&apy_reader::pool_apy(system_state_mut_ref, &pool_id, current_epoch));
            assert!(apy_reader::pool_apy(system_state_mut_ref, &pool_id, current_epoch) > 10000000 , 1);

            test::return_shared(system_state);
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