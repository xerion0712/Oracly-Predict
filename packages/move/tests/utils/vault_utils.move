

#[test_only]
module legato::vault_utils {

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::coin::{Self };

    use sui_system::staking_pool::{  StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState, validator_staking_pool_id, epoch };
    use sui_system::governance_test_utils::{ 
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };

    use legato::legato::{Self, Global, LEGATO};
    use legato::amm::{Self, AMMGlobal };
    use legato::vault_template::{JAN_2024};

    friend legato::vault_balanced_tests;
    friend legato::vault_deficit_tests;

    const VAULT_MATURE_IN : u64 = 60;

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;

    const MIST_PER_SUI: u64 = 1_000_000_000;
    const INIT_LIQUIDITY: u64 = 10_000_000_000;

    public(friend) fun setup_vault(test: &mut Scenario, admin_address: address) {

        next_tx(test, admin_address);
        {
            legato::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            amm::init_for_testing(ctx(test));
        };

        // vault matures in 60 epochs
        next_tx(test, admin_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let amm_global = test::take_shared<AMMGlobal>(test);

            let maturity_epoch = epoch(&mut system_state)+VAULT_MATURE_IN;
            let initial_apy = 30000000; // APY = 3%

            legato::new_vault<JAN_2024>(
                &mut global,  
                &mut amm_global,
                initial_apy,
                maturity_epoch,
                coin::mint_for_testing<LEGATO>(INIT_LIQUIDITY, ctx(test)),
                ctx(test)
            );

            test::return_shared(global);
            test::return_shared(amm_global);
            test::return_shared(system_state);
        };

        next_tx(test, admin_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);

            let pool_id_1 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_1);
            let pool_id_2 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_2);
            let pool_id_3 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_3);
            let pool_id_4 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_4);

            legato::add_pool<JAN_2024>( &mut global, pool_id_1, ctx(test));
            legato::add_pool<JAN_2024>( &mut global, pool_id_2, ctx(test));
            legato::add_pool<JAN_2024>( &mut global, pool_id_3, ctx(test));
            legato::add_pool<JAN_2024>( &mut global, pool_id_4, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
        };

    }

    public(friend) fun advance_epoch(test: &mut Scenario, value: u64) {
        let i = 0;
        while (i < value) {
            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };
    }

    public(friend) fun set_up_sui_system_state() {
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

    public(friend) fun set_up_sui_system_state_imbalance() {
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

    public(friend) fun stake_and_mint(test: &mut Scenario, staker_address: address, amount : u64, validator_address: address) {

        next_tx(test, staker_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            sui_system::request_add_stake(&mut system_state, coin::mint_for_testing(amount, ctx(test)), validator_address, ctx(test));
            test::return_shared(system_state);
        };

        next_tx(test, staker_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let staked_sui = test::take_from_sender<StakedSui>(test);

            legato::mint<JAN_2024>(&mut system_state, &mut global, staked_sui, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
        };

    }

    public(friend) fun validator_addrs() : vector<address> {
        vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4]
    }

    public(friend) fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }

}