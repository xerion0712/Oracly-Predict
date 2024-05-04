#[test_only]
module legato::vault_utils {

    use sui::test_scenario::{Self as test, Scenario , next_tx, ctx};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::random::{Self, update_randomness_state_for_testing, Random};
    use sui::tx_context::{Self};
 
    use sui_system::sui_system::{  SuiSystemState, validator_staking_pool_id };
    use sui_system::governance_test_utils::{ 
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };
 
    use legato::vault::{Self, ManagerCap, Global  };
    use legato::vault_token_name::{  MAR_2024, JUN_2024};
 
    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    struct USDC {}

    public fun advance_epoch(test: &mut Scenario, value: u64) {
        let i = 0;
        while (i < value) {
            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };
    }

    public fun set_up_sui_system_state() {
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

    public fun setup_vault(test: &mut Scenario, admin_address: address ) {

        next_tx(test, admin_address);
        {
            vault::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);

            let pool_id_1 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_1);
            let pool_id_2 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_2);
            let pool_id_3 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_3);
            let pool_id_4 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_4);

            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_1, pool_id_1 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_2, pool_id_2 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_3, pool_id_3 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_4, pool_id_4 );

            vault::set_first_epoch( &mut global, &mut managercap, tx_context::epoch( ctx(test) )-30 );

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

        register_vault<MAR_2024>(test, admin_address, 1);
        register_vault<JUN_2024>(test, admin_address, 2); 

    }

    fun register_vault<P>(test: &mut Scenario, admin_address: address, q: u64) {

        next_tx(test, admin_address);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);  

            vault::new_vault<P>(
                &mut global,
                &mut managercap,
                q,
                424, // 4.24% APY
                10000,
                ctx(test)
            );

            test::return_shared(global); 
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };
 
    }

    public fun check_usdc_balance(test: &mut Scenario, _amount: u64) {
        let usdc_token = test::take_from_sender<Coin<USDC>>(test);  
        test::return_to_sender(test, usdc_token);
    }

    public fun set_up_random(test: &mut Scenario) {
        // Setup randomness
        next_tx(test, @0x0);
        {
            random::create_for_testing(ctx(test)); 
        };

        next_tx(test, @0x0);
        {
            let random_state = test::take_shared<Random>(test);  

            update_randomness_state_for_testing(
                &mut random_state,
                0,
                x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
                ctx(test),
            );

            test::return_shared(random_state);
        };
    }

    public fun mint_pt<P>(test: &mut Scenario, staker_address: address, amount: u64) {
        
        next_tx(test, staker_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test); 
            let random_state = test::take_shared<Random>(test);    

            vault::mint_from_sui<P>(&mut system_state, &mut global, &random_state, coin::mint_for_testing<SUI>( amount , ctx(test)), ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_shared(random_state);
        };

    }

    public fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }
}