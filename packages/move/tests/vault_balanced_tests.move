// the balanced state, where the debts equal the accumulated rewards.

#[test_only]
module legato::vault_balanced_tests {

    use sui::coin::{Self, Coin};
    use sui_system::sui_system::{ SuiSystemState, epoch };
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };

    use legato::legato::{Self, Global, TOKEN, PT};
    use legato::vault_utils::{
        scenario, 
        advance_epoch, 
        set_up_sui_system_state,
        setup_vault,
        stake_and_mint
    };
    use legato::vault_template::{JAN_2024};

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    // ======== Asserts ========
    const ASSERT_CHECK_APY: u64 = 1;

    #[test]
    public fun test_balanced_flow() {
        let scenario = scenario();
        test_balanced_flow_(&mut scenario);
        test::end(scenario);
    }

    fun test_balanced_flow_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup a vault
        setup_vault(test, ADMIN_ADDR);

        // Using median APY
        next_tx(test, ADMIN_ADDR);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            
            let current_epoch = epoch(&mut system_state);
            let median_apy = legato::median_apy<JAN_2024>(&mut system_state, &mut global, current_epoch);

            assert!(median_apy == 45485582, ASSERT_CHECK_APY);
            legato::update_vault_apy<JAN_2024>( &mut system_state,&mut global, median_apy, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
        };

        stake_and_mint(test, STAKER_ADDR_1, 100 * MIST_PER_SUI, VALIDATOR_ADDR_1);
        stake_and_mint(test, STAKER_ADDR_2, 200 * MIST_PER_SUI, VALIDATOR_ADDR_2);

        advance_epoch(test, 61);

        // Redeem across 2 locked Staked SUI
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let pt_token = test::take_from_sender<Coin<TOKEN<JAN_2024,PT>>>(test);

            // Split 150 PT for withdrawal
            let pt_to_withdraw = coin::split(&mut pt_token, 150 * MIST_PER_SUI, ctx(test));

            legato::redeem<JAN_2024>(&mut system_state, &mut global, pt_to_withdraw, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
            coin::burn_for_testing(pt_token);
        };

    }

}