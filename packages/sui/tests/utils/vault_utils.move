#[test_only]
module legato::vault_utils {

    // use std::debug;

    use sui::test_scenario::{Self as test, Scenario , next_tx, ctx};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};

    // use sui_system::staking_pool::{ StakedSui};
    use sui_system::sui_system::{  SuiSystemState, validator_staking_pool_id };
    use sui_system::governance_test_utils::{ 
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };
 
    use legato::vault::{Self, ManagerCap, Global, VAULT, PT_TOKEN };
    use legato::vault_template::{JAN_2024, FEB_2024, MAR_2024};
    use legato::amm::{Self, AMMGlobal};

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;
    const STAKER_ADDR_3: address = @0x44;

    const MIST_PER_SUI: u64 = 1_000_000_000;
    const INIT_LIQUIDITY: u64 = 10_000_000_000;

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

    public fun setup_vault(test: &mut Scenario, admin_address: address) {

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

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

        register_vault<JAN_2024>(test, admin_address, 40, 100);
        register_vault<FEB_2024>(test, admin_address, 60, 110);
        register_vault<MAR_2024>(test, admin_address, 80, 140);

    }

    public fun setup_yt(test: &mut Scenario, admin_address: address) {
    
        next_tx(test, admin_address);
        {
            amm::init_for_testing(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let global = test::take_shared<Global>(test);
            let amm_global = test::take_shared<AMMGlobal>(test);
            let managercap = test::take_from_sender<ManagerCap>(test);

            // 1 YT = 0.01 USDC
            vault::add_yt_circulation<USDC>(
                &mut global,
                &mut amm_global,
                &mut managercap,
                coin::mint_for_testing<USDC>(100_000_000_000, ctx(test)),
                10000_000_000_000,
                ctx(test)
            );
        
            test::return_shared(amm_global);
            test::return_shared(global);
            test::return_to_sender(test, managercap);
        };

    }

    public fun rebalance(test: &mut Scenario, admin_address: address) {

        next_tx(test, admin_address);
        {
            let global = test::take_shared<Global>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let amm_global = test::take_shared<AMMGlobal>(test);
            let managercap = test::take_from_sender<ManagerCap>(test);
            
            vault::rebalance<JAN_2024, USDC>( 
                &mut system_state,
                &mut global,
                &mut amm_global,
                &mut managercap,
                coin::mint_for_testing<USDC>(10_000_000_000, ctx(test)),
                1_500_000_000, // 1.5 SUI/USDC
                ctx(test)
            );

            test::return_shared(amm_global);
            test::return_shared(global);
            test::return_to_sender(test, managercap);
            test::return_shared(system_state);
        };

    }

    fun register_vault<P>(test: &mut Scenario, admin_address: address, start_epoch: u64, end_epoch: u64) {

        next_tx(test, admin_address);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test); 
            let initial_apy = 30000000; // APY = 3%

            vault::new_vault<P>(
                &mut global,
                &mut managercap,
                start_epoch,
                end_epoch,
                initial_apy,
                ctx(test)
            );

            test::return_shared(global); 
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };
 
    }

    public fun stake_and_mint<P>(test: &mut Scenario, staker_address: address, amount : u64, validator_address: address) {

        next_tx(test, staker_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test); 

            vault::mint_from_sui<P>(&mut system_state, &mut global, coin::mint_for_testing<SUI>(amount, ctx(test)), validator_address, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
        };

    }

    public fun buy_yt(test: &mut Scenario, amount: u64, recipient_address: address) {
        next_tx(test, recipient_address);
        {
            let amm_global = test::take_shared<AMMGlobal>(test);
            amm::swap<USDC, VAULT>(&mut amm_global, coin::mint_for_testing<USDC>(amount, ctx(test)), 1, ctx(test));
            test::return_shared(amm_global);
        };
    }

    public fun sell_yt(test: &mut Scenario, amount: u64, recipient_address: address) {
        next_tx(test, recipient_address);
        {
            let amm_global = test::take_shared<AMMGlobal>(test);
            amm::swap<VAULT, USDC>(&mut amm_global, coin::mint_for_testing<VAULT>(amount, ctx(test)), 1, ctx(test));
            test::return_shared(amm_global);
        };
    }

    public fun check_usdc_balance(test: &mut Scenario, _amount: u64) {
        let usdc_token = test::take_from_sender<Coin<USDC>>(test); 
        // assert!( coin::value(&usdc_token) == 104_120_399, 1234);
        test::return_to_sender(test, usdc_token);
    }

    public fun vault_exit<P>(test: &mut Scenario, staker_address: address) {
        next_tx(test, staker_address);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let amm_global = test::take_shared<AMMGlobal>(test);

            let pt_token = test::take_from_sender<Coin<PT_TOKEN<P>>>(test);
            let yt_token = test::take_from_sender<Coin<VAULT>>(test);

            vault::exit<P, USDC>( &mut system_state, &mut global, &mut amm_global, 0, pt_token, yt_token, ctx(test) );

            test::return_shared(global);
            test::return_shared(amm_global);
            test::return_shared(system_state);  
        };
    }


    public fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }
}