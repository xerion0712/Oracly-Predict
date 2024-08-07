

#[test_only]
module legato::stake_data_provider_tests {

    use std::vector;

    use sui::coin;
    use sui::object::{  ID }; 
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx }; 
    use sui_system::sui_system::{ Self, SuiSystemState, validator_staking_pool_id };
    use sui_system::staking_pool::{ StakedSui};
    use sui::tx_context::{Self};  

    use sui_system::governance_test_utils::{  
        Self,
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };

    use legato::stake_data_provider;

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    #[test]
    public fun test_check_apy() {
        let mut scenario = scenario();
        check_apy(&mut scenario);
        test::end(scenario);
    }

    fun check_apy(test: &mut Scenario) {
        set_up_sui_system_state(); 
 
        // Stake 100 SUI for Staker#1
        next_tx(test, STAKER_ADDR_1);
        { 
            let mut system_state = test::take_shared<SuiSystemState>(test);  
            sui_system::request_add_stake(&mut system_state, coin::mint_for_testing(100 * MIST_PER_SUI, ctx(test)), VALIDATOR_ADDR_1, ctx(test)); 
            test::return_shared(system_state);
        };

        // Stake 100 SUI for Staker#2
        next_tx(test, STAKER_ADDR_2);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);  
            sui_system::request_add_stake(&mut system_state, coin::mint_for_testing(100 * MIST_PER_SUI, ctx(test)), VALIDATOR_ADDR_1, ctx(test)); 
            test::return_shared(system_state);
        };

        governance_test_utils::advance_epoch(test);

        // forwards 100 epoch
        let mut i = 0;
        while (i < 100) {
            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };

        // Checking APY
        next_tx(test, STAKER_ADDR_1);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test); 
            let current_epoch = tx_context::epoch(ctx(test));

            let mut pool_ids = vector::empty<ID>();
            vector::push_back<ID>(&mut pool_ids, validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_1));
            vector::push_back<ID>(&mut pool_ids, validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_2));
            vector::push_back<ID>(&mut pool_ids, validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_3));
            vector::push_back<ID>(&mut pool_ids, validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_4));

            while (vector::length(&pool_ids) != 0) {
                let pool_id = vector::pop_back(&mut pool_ids);
                let pool_apy = stake_data_provider::pool_apy(&mut system_state, &pool_id, current_epoch);

                assert!( pool_apy/ 100000 == 451, 0 ); // ~4.51%
            };

            test::return_shared(system_state);
        };

        // Estimate the rewards to be received
        next_tx(test, STAKER_ADDR_1);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let staked_sui = test::take_from_sender<StakedSui>(test);

            let current_epoch = tx_context::epoch(ctx(test));
            let rewards = stake_data_provider::earnings_from_staked_sui(&mut system_state, &staked_sui, current_epoch);

            assert!( rewards== 1249750049, 1);

            test::return_to_sender(test, staked_sui);
            test::return_shared(system_state);
        };

    } 

    fun set_up_sui_system_state() {
        let mut scenario_val = test::begin(@0x0);
        let scenario = &mut scenario_val;
        let ctx = test::ctx(scenario);

        let validators = vector[ 
            create_validator_for_testing(VALIDATOR_ADDR_1, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_2, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_3, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_4, 1000000, ctx)
        ];

        create_sui_system_state_for_testing(validators, 40000000, 0, ctx);

        test::end(scenario_val);
    }
    
 
    fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }

}