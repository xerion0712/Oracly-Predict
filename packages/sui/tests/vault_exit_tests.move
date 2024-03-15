
// testing vault exits with PT and YT. should be disabled by default.

#[test_only]
module legato::vault_exit_tests {

 
    use sui::test_scenario::{Self as test, Scenario, next_tx };
    use sui_system::sui_system::{ SuiSystemState };

    use legato::vault_utils::{
        scenario, 
        advance_epoch, 
        set_up_sui_system_state,
        setup_vault,
        setup_yt,
        stake_and_mint,
        buy_yt,
        vault_exit
    };
    use legato::vault::{ Self, Global, ManagerCap};
    use legato::vault_template::{JAN_2024 }; 

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
    public fun test_vault_exit() {
        let scenario = scenario();
        test_vault_exit_(&mut scenario);
        test::end(scenario);
    }

    fun test_vault_exit_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR);

        // setup YT 
        setup_yt(test, ADMIN_ADDR);

        // mint PT on 1st vault
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 10 * MIST_PER_SUI, VALIDATOR_ADDR_1);

        // enables exit
        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let managercap = test::take_from_sender<ManagerCap>(test); 

            vault::enable_exit<JAN_2024>(&mut global, &mut managercap);
            // 1 SUI = 1 USDC
            vault::set_exit_conversion_rate<JAN_2024>(&mut global, &mut managercap, 1_000_000_000);

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, managercap);
        };

        advance_epoch(test, 30);

        // buy YT /w 3 USDC
        buy_yt( test, 3_000_000_000, STAKER_ADDR_1 );

        // exit prior to the vault's maturity for 30 epochs
        vault_exit<JAN_2024>(test, STAKER_ADDR_1);
        

    }

}