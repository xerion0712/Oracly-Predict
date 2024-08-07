#[test_only]
module legato::vault_utils {

    use sui::test_scenario::{Self as test, Scenario , next_tx, ctx};
    use sui::sui::SUI;
    use sui::coin::{Self};  
 
    use sui_system::sui_system::{  SuiSystemState, validator_staking_pool_id };
    use sui_system::governance_test_utils::{ 
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };
 
    use legato::vault::{Self, ManagerCap, VaultGlobal  }; 

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    public fun advance_epoch(test: &mut Scenario, value: u64) {
        let mut i = 0;
        while (i < value) {
            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };
    }

    public fun set_up_sui_system_state() {
        let mut scenario_val = test::begin(@0x0);
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
            let mut managercap = test::take_from_sender<ManagerCap>(test);
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut global = test::take_shared<VaultGlobal>(test);

            let pool_id_1 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_1);
            let pool_id_2 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_2);
            let pool_id_3 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_3);
            let pool_id_4 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_4);

            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_1, pool_id_1 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_2, pool_id_2 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_3, pool_id_3 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_4, pool_id_4 );
 
            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };
 

    }

    public fun mint(test: &mut Scenario, staker_address: address, amount: u64) {

        next_tx(test, staker_address);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut global = test::take_shared<VaultGlobal>(test);  

            vault::mint_from_sui(&mut system_state, &mut global, coin::mint_for_testing<SUI>( amount , ctx(test)), ctx(test));

            test::return_shared(global);
            test::return_shared(system_state); 
        };

    }

    public fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }





}