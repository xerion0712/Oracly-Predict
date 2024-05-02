

#[test_only]
module legato::vault_tests {

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
    use sui::random::{  Random};
    use sui_system::sui_system::{ SuiSystemState  };
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use legato::vault_utils::{
        scenario, 
        advance_epoch,
        set_up_sui_system_state,
        setup_vault,
        set_up_random,
    };

    use legato::vault::{Self, Global, PT_TOKEN };
    use legato::vault_token_name::{  MAR_2024, JUN_2024 };


    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    #[test]
    public fun test_mint_redeem_flow() {
        let scenario = scenario();
        mint_redeem_flow(&mut scenario);
        test::end(scenario);
    }

    fun mint_redeem_flow( test: &mut Scenario ) {
        set_up_sui_system_state();
        set_up_random(test);
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR);

        // mint PT for STAKER#1
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test); 
            let random_state = test::take_shared<Random>(test);    

            vault::mint_from_sui<MAR_2024>(&mut system_state, &mut global, &random_state, coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, ctx(test)), ctx(test));
            vault::mint_from_sui<JUN_2024>(&mut system_state, &mut global, &random_state, coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, ctx(test)), ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_shared(random_state);
        };

        // mint PT for STAKER#2
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test); 
            let random_state = test::take_shared<Random>(test);    

            vault::mint_from_sui<MAR_2024>(&mut system_state, &mut global, &random_state, coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, ctx(test)), ctx(test));
            vault::mint_from_sui<JUN_2024>(&mut system_state, &mut global, &random_state, coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, ctx(test)), ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_shared(random_state);
        };

        // Verify
        next_tx(test, STAKER_ADDR_1);
        {
            let pt_token_1 = test::take_from_sender<Coin<PT_TOKEN<MAR_2024>>>(test);
            let pt_token_2 = test::take_from_sender<Coin<PT_TOKEN<JUN_2024>>>(test); 

            assert!( coin::value(&pt_token_1) == 101050963683, 0); // 101.050963683 PT
            assert!( coin::value(&pt_token_2) == 102112972614, 1); // 102.112972614 PT
 
            test::return_to_sender(test, pt_token_1);
            test::return_to_sender(test, pt_token_2);

        };

    }

}