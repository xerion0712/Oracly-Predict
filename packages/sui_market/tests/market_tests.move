
#[test_only]
module legato_market::market_tests {

    use sui::coin::{ Self, Coin, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, next_epoch, ctx, end};
    use sui::sui::SUI;  
    use sui::tx_context::{Self};
 
    use sui_system::sui_system::{  SuiSystemState, validator_staking_pool_id };
    use sui_system::governance_test_utils::{ 
        create_sui_system_state_for_testing,
        create_validator_for_testing,
        advance_epoch_with_reward_amounts
    };
 
    use legato::vault::{Self, ManagerCap, VaultGlobal  }; 
    use legato_market::market::{Self, MarketGlobal};

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;

    const USER_ADDR_1: address = @0x61;
    const USER_ADDR_2: address = @0x62;

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;
 
    #[test]
    public fun test_market_btc_flow() {
        let mut scenario = scenario();
        market_btc_flow(&mut scenario);
        test_scenario::end(scenario);
    }

    fun market_btc_flow(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR );

        // setup market system
        setup_market(test, ADMIN_ADDR );

        // Provide liquidity
        next_tx(test, STAKER_ADDR_1);
        { 
            let mut system_state = test_scenario::take_shared<SuiSystemState>(test);
            let mut vault_global = test_scenario::take_shared<VaultGlobal>(test);
            let mut global = test_scenario::take_shared<MarketGlobal>(test);

            market::provide( 
                &mut system_state,
                &mut global,
                &mut vault_global,
                coin::mint_for_testing<SUI>( 50_000000000 , ctx(test)),
                ctx(test)
            );

            test_scenario::return_shared(vault_global);
            test_scenario::return_shared(global);
            test_scenario::return_shared(system_state); 
        };
        
        // Place bets
        next_tx(test, USER_ADDR_1);
        {
            let mut global = test_scenario::take_shared<MarketGlobal>(test);
            let mut vault_global = test_scenario::take_shared<VaultGlobal>(test);

            market::place_bet(&mut global, &mut vault_global, 1, 0, 1, coin::mint_for_testing<SUI>( 1_000000000 , ctx(test)), ctx(test));
            market::place_bet(&mut global, &mut vault_global, 1, 0, 2, coin::mint_for_testing<SUI>( 1_000000000 , ctx(test)), ctx(test));
            market::place_bet(&mut global, &mut vault_global, 1, 0, 3, coin::mint_for_testing<SUI>( 1_000000000 , ctx(test)), ctx(test));
            market::place_bet(&mut global, &mut vault_global, 1, 0, 4, coin::mint_for_testing<SUI>( 1_000000000 , ctx(test)), ctx(test));

            test_scenario::return_shared(vault_global);
            test_scenario::return_shared(global);
        };

        // Resolves the market and top up rewards
        next_tx(test, ADMIN_ADDR);
        {
            let mut global = test_scenario::take_shared<MarketGlobal>(test); 
            market::resolve_market(&mut global, 1, 0, 2 , ctx(test));
            market::topup_fulfilment_pool( &mut global, coin::mint_for_testing<SUI>( 10_000000000 , ctx(test)) );

            test_scenario::return_shared(global);
        };

        advance_epoch(test, 3);

        // Payout winners
        next_tx(test, USER_ADDR_1);
        {
            let mut global = test_scenario::take_shared<MarketGlobal>(test); 
            market::payout_winners(&mut global, 1, 0, 0, 100, ctx(test));
            test_scenario::return_shared(global);
        };

        // Verify
        next_tx(test, USER_ADDR_1);
        {
            let sui_token = test_scenario::take_from_sender<Coin<SUI>>(test);
            assert!( coin::value(&sui_token) == 1_302390000, 0); // Received 1.3 SUI
            test_scenario::return_to_sender(test, sui_token);
        };

    }


    public fun advance_epoch(test: &mut Scenario, value: u64) {
        let mut i = 0;
        while (i < value) {
            advance_epoch_with_reward_amounts(0, 500, test);
            i = i + 1;
        };
    }

    public fun set_up_sui_system_state() {
        let mut scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;
        let ctx = test_scenario::ctx(scenario);

        let validators = vector[
            create_validator_for_testing(VALIDATOR_ADDR_1, 1000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_2, 1500000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_3, 2000000, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_4, 2500000, ctx),
        ];
        create_sui_system_state_for_testing(validators, 70000000, 0, ctx);

        test_scenario::end(scenario_val);
    } 

    public fun setup_market(test: &mut Scenario, admin_address: address) {

        next_tx(test, admin_address);
        {
            market::test_init(ctx(test));
        };

        // Setup BTC market
        next_tx(test, admin_address);
        {
            let mut global = test_scenario::take_shared<MarketGlobal>(test);

            market::add_market(
                &mut global,
                1,
                0,
                1500,
                3500,
                3500,
                1500,
                tx_context::epoch( ctx(test) )+2,
                ctx(test)
            );

            test_scenario::return_shared(global);
        };

        // Setup SUI market
        next_tx(test, admin_address);
        {
            let mut global = test_scenario::take_shared<MarketGlobal>(test);

            market::add_market(
                &mut global,
                1,
                1,
                5000,
                5000,
                0,
                0,
                tx_context::epoch( ctx(test) )+2,
                ctx(test)
            );

            test_scenario::return_shared(global);
        };

    }

    public fun setup_vault(test: &mut Scenario, admin_address: address ) {

        next_tx(test, admin_address);
        {
            vault::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let mut managercap = test_scenario::take_from_sender<ManagerCap>(test);
            let mut system_state = test_scenario::take_shared<SuiSystemState>(test);
            let mut global = test_scenario::take_shared<VaultGlobal>(test);

            let pool_id_1 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_1);
            let pool_id_2 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_2);
            let pool_id_3 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_3);
            let pool_id_4 = validator_staking_pool_id(&mut system_state, VALIDATOR_ADDR_4);

            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_1, pool_id_1 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_2, pool_id_2 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_3, pool_id_3 );
            vault::attach_pool( &mut global, &mut managercap, VALIDATOR_ADDR_4, pool_id_4 );
 
            vault::enable_auto_stake( &mut global, &mut managercap, true );

            test_scenario::return_shared(global);
            test_scenario::return_shared(system_state);
            test_scenario::return_to_sender(test, managercap);
        };
 

    }

    public fun scenario(): Scenario { test_scenario::begin(VALIDATOR_ADDR_1) }

}