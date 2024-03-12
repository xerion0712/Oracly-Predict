// test when migrating PT tokens to the newly created vault and minting additional PT
#[test_only]
module legato::vault_migration_tests {

    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui_system::sui_system::{ SuiSystemState };

    use legato::vault_utils::{
        scenario, 
        advance_epoch, 
        set_up_sui_system_state,
        setup_vault,
        stake_and_mint
    };
    use legato::vault_template::{JAN_2024 , FEB_2024, MAR_2024 };
    use legato::vault::{Self, Global, PT_TOKEN};

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;
    const STAKER_ADDR_3: address = @0x44;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    // ======== Asserts ========
    const ASSERT_CHECK_VALUE: u64 = 1;
    const ASSERT_CHECK_EPOCH: u64 = 2;


    #[test]
    public fun test_vault_migration() {
        let scenario = scenario();
        test_vault_migration_(&mut scenario);
        test::end(scenario);
    }

    fun test_vault_migration_(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR);

        // mint PT on 1st vault
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 10 * MIST_PER_SUI, VALIDATOR_ADDR_1);
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 20 * MIST_PER_SUI, VALIDATOR_ADDR_2);
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 30 * MIST_PER_SUI, VALIDATOR_ADDR_1);
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_1, 100 * MIST_PER_SUI, VALIDATOR_ADDR_3);
        stake_and_mint<JAN_2024>(test, STAKER_ADDR_3, 200 * MIST_PER_SUI, VALIDATOR_ADDR_4);

        // forward 20 epochs to allow staking on the 2nd vault
        advance_epoch(test, 20);

        // mint PT on 2nd vault
        stake_and_mint<FEB_2024>(test, STAKER_ADDR_2, 200 * MIST_PER_SUI, VALIDATOR_ADDR_2);
        stake_and_mint<FEB_2024>(test, STAKER_ADDR_3, 300 * MIST_PER_SUI, VALIDATOR_ADDR_3); 

        // migrate PT from 1st vault to 2nd vault
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test);
            let pt_token = test::take_from_sender<Coin<PT_TOKEN<JAN_2024>>>(test);

            vault::migrate<JAN_2024, FEB_2024>( &mut global, pt_token, ctx(test));

            test::return_shared(global);
            test::return_shared(system_state); 
        };

        advance_epoch(test, 41);

        // migrate PT from 2nd vault to 3rd vault
        next_tx(test, STAKER_ADDR_2);
        {
            let global = test::take_shared<Global>(test);
            let pt_token = test::take_from_sender<Coin<PT_TOKEN<FEB_2024>>>(test);
            let token_value = coin::value(&pt_token); 
            
            assert!(token_value == 200821917808, ASSERT_CHECK_VALUE);

            vault::migrate<FEB_2024, MAR_2024>( &mut global, pt_token, ctx(test));

            test::return_shared(global);
        };

    }

}