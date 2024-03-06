#[test_only]
module legato::vault_utils {

    use sui::test_scenario::{Self as test, Scenario , next_tx, ctx};
    use sui::sui::SUI;
    use sui::coin::{Self};

    use sui_system::staking_pool::{ StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState, validator_staking_pool_id };
    use sui_system::governance_test_utils::{ 
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };

    use legato::marketplace::{Self, Marketplace };
    // use legato::vusd::{Self, PositionManager};
    use legato::vault::{Self, ManagerCap, Global, YT_TOKEN}; 
    use legato::amm::{ Self, AMMGlobal };
    use legato::lp_staking::{Self, Staking};
    use legato::vault_template::{JAN_2024, FEB_2024, MAR_2024};

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

    public fun advance_epoch_with_snapshot<P>(test: &mut Scenario, admin_address: address, value: u64) {
        let i = 0;
        while (i < value) {
            // next_tx(test, admin_address);
            // {
            //     let global = test::take_shared<Staking>(test);
            //     lp_staking::snapshot<YT_TOKEN<P>>(&mut global, ctx(test));
            //     test::return_shared(global); 
            // };

            next_tx(test, admin_address);
            {
                let system_state = test::take_shared<SuiSystemState>(test);
                let managercap = test::take_from_sender<ManagerCap>(test);
                let global = test::take_shared<Global>(test);
                let staking_global = test::take_shared<Staking>(test);

                lp_staking::vault_snapshot<P>(&mut system_state, &mut staking_global, &mut global, &mut managercap, ctx(test));
                
                test::return_shared(staking_global); 
                test::return_shared(global);
                test::return_to_sender(test, managercap);
                test::return_shared(system_state);

            };

            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };
    }

    // public fun set_up_sui_system_state() {
    //     let scenario_val = test::begin(@0x0);
    //     let scenario = &mut scenario_val;
    //     let ctx = test::ctx(scenario);

    //     let validators = vector[
    //         create_validator_for_testing(VALIDATOR_ADDR_1, 1000000, ctx),
    //         create_validator_for_testing(VALIDATOR_ADDR_2, 1000000, ctx),
    //         create_validator_for_testing(VALIDATOR_ADDR_3, 1000000, ctx),
    //         create_validator_for_testing(VALIDATOR_ADDR_4, 1000000, ctx),
    //     ];
    //     create_sui_system_state_for_testing(validators, 40000000, 0, ctx);

    //     test::end(scenario_val);
    // }

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

    public fun setup_marketplace(test: &mut Scenario, admin_address: address) {

        next_tx(test, admin_address);
        {
            marketplace::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let global = test::take_shared<Marketplace>(test);
            let managercap = test::take_from_sender<marketplace::ManagerCap>(test);
            marketplace::setup_quote<USDC>(&mut global, &mut managercap,  ctx(test));
            test::return_shared(global);
            test::return_to_sender(test, managercap);
        };

        // listing SUI for USDC
        next_tx(test, admin_address);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::sell_and_listing<SUI, USDC>(&mut global,  coin::mint_for_testing<SUI>( 300 * MIST_PER_SUI, ctx(test)), 500_000_000 , ctx(test));
            marketplace::sell_and_listing<SUI, USDC>(&mut global, coin::mint_for_testing<SUI>( 200 * MIST_PER_SUI, ctx(test)), 550_000_000 , ctx(test));
            marketplace::sell_and_listing<SUI, USDC>(&mut global, coin::mint_for_testing<SUI>( 100 * MIST_PER_SUI, ctx(test)), 600_000_000 , ctx(test));
            marketplace::sell_and_listing<SUI, USDC>(&mut global,coin::mint_for_testing<SUI>( 50 * MIST_PER_SUI, ctx(test)), 650_000_000 , ctx(test));
            test::return_shared(global);
        };

    }

    // public fun setup_vusd(test: &mut Scenario, admin_address: address) {
    //     next_tx(test, admin_address);
    //     {
    //         vusd::test_init(ctx(test));
    //     };

    //     next_tx(test, admin_address);
    //     { 
    //         let system_state = test::take_shared<SuiSystemState>(test);
    //         let global = test::take_shared<PositionManager>(test);
    //         let managercap = test::take_from_sender<vusd::ManagerCap>(test);

    //         let pool_id_1 = validator_staking_pool_id(&mut system_state,  VALIDATOR_ADDR_1);
    //         let pool_id_2 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_2);
    //         let pool_id_3 = validator_staking_pool_id(&mut system_state,  VALIDATOR_ADDR_3);
    //         let pool_id_4 = validator_staking_pool_id(&mut system_state,   VALIDATOR_ADDR_4);

    //         vusd::attach_pool( &mut global, &mut managercap,VALIDATOR_ADDR_1 , pool_id_1);
    //         vusd::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_2 , pool_id_2);
    //         vusd::attach_pool( &mut global, &mut managercap,VALIDATOR_ADDR_3, pool_id_3 );
    //         vusd::attach_pool( &mut global,&mut managercap, VALIDATOR_ADDR_4, pool_id_4 );

    //         vusd::register_stablecoin<USDC>( &mut global, 950_000_000 , &mut managercap);

    //         test::return_shared(global); 
    //         test::return_to_sender(test, managercap);
    //         test::return_shared(system_state);
    //     };
    // }

    public fun setup_vault(test: &mut Scenario, admin_address: address) {

        next_tx(test, admin_address);
        {
            vault::test_init(ctx(test));
            lp_staking::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            amm::init_for_testing(ctx(test));
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

    fun register_vault<P>(test: &mut Scenario, admin_address: address, start_epoch: u64, end_epoch: u64) {

        next_tx(test, admin_address);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let amm_global = test::take_shared<AMMGlobal>(test);
            let initial_apy = 30000000; // APY = 3%

            vault::new_vault<P>(
                &mut global,  
                &mut amm_global,
                &mut managercap,
                start_epoch,
                end_epoch,
                initial_apy,
                coin::mint_for_testing<SUI>(INIT_LIQUIDITY, ctx(test)),
                ctx(test)
            );

            test::return_shared(global);
            test::return_shared(amm_global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };
 
    }

    public fun buy_yt(test: &mut Scenario, amount: u64, recipient_address: address) {
        next_tx(test, recipient_address);
        {
            let amm_global = test::take_shared<AMMGlobal>(test);
            amm::swap<SUI, YT_TOKEN<JAN_2024>>(&mut amm_global, coin::mint_for_testing<SUI>(amount, ctx(test)), 1, ctx(test));
            test::return_shared(amm_global);
        };
    }

    public fun stake_and_mint<P>(test: &mut Scenario, staker_address: address, amount : u64, validator_address: address) {

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

            vault::mint<P>(&mut system_state, &mut global, staked_sui, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
        };

    }


    public fun scenario(): Scenario { test::begin(VALIDATOR_ADDR_1) }
}