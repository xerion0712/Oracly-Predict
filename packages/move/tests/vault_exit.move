
// testing vault exits with a combination of YT and PT, disabled by default
#[test_only]
module legato::vault_exit {

    // use std::debug;

    use sui::coin::{ Self, Coin};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
    use sui_system::sui_system::{ SuiSystemState };
    use sui::sui::SUI;

    use legato::vault_utils::{
        scenario, 
        advance_epoch, 
        set_up_sui_system_state,
        setup_vault,
        stake_and_mint
    };
    use legato::vault::{ Self, Global, YT_TOKEN, PT_TOKEN, ManagerCap};
    use legato::vault_template::{JAN_2024 };
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

    #[test]
    public fun test_vault_migration() {
        let scenario = scenario();
        test_vault_exit_(&mut scenario);
        test::end(scenario);
    }

    fun test_vault_exit_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR);

        // mint PT on 1st vault
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 10 * MIST_PER_SUI, VALIDATOR_ADDR_1);


        // enables exit
        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let managercap = test::take_from_sender<ManagerCap>(test); 

            vault::enable_exit<JAN_2024>(&mut global, &mut managercap);

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

        advance_epoch(test, 30);
    
        // acquire some YT
        next_tx(test, STAKER_ADDR_1);
        {
            let global = test::take_shared<AMMGlobal>(test);
            amm::swap<SUI, YT_TOKEN<JAN_2024>>(&mut global, coin::mint_for_testing<SUI>( MIST_PER_SUI, ctx(test)) , 1, ctx(test));
            test::return_shared(global);
        };

        // exit prior to the vault's maturity for 30 epochs
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let amm_global = test::take_shared<AMMGlobal>(test);

            let pt_token = test::take_from_sender<Coin<PT_TOKEN<JAN_2024>>>(test);
            let yt_token = test::take_from_sender<Coin<YT_TOKEN<JAN_2024>>>(test);

            vault::exit<JAN_2024>( &mut system_state, &mut global, &mut amm_global, 0, pt_token, yt_token, ctx(test) );

            test::return_shared(global);
            test::return_shared(amm_global);
            test::return_shared(system_state);  
        };


    }

}