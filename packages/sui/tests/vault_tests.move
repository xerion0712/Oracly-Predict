

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
        mint_pt
    };

    use legato::vault::{Self, Global, PT_TOKEN, ManagerCap };
    use legato::vault_token_name::{  MAR_2024, JUN_2024 };

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;
    const STAKER_ADDR_3: address = @0x44;
    const STAKER_ADDR_4: address = @0x45;
    const STAKER_ADDR_5: address = @0x45;
    const STAKER_ADDR_6: address = @0x45;

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

        // mint PT for all users
        mint_pt<MAR_2024>(test, STAKER_ADDR_1, 100 * MIST_PER_SUI);
        mint_pt<JUN_2024>(test, STAKER_ADDR_1, 100 * MIST_PER_SUI);

        mint_pt<MAR_2024>(test, STAKER_ADDR_2, 200 * MIST_PER_SUI);
        mint_pt<JUN_2024>(test, STAKER_ADDR_2, 300 * MIST_PER_SUI);

        mint_pt<MAR_2024>(test, STAKER_ADDR_3, 50 * MIST_PER_SUI);
        mint_pt<MAR_2024>(test, STAKER_ADDR_4, 100 * MIST_PER_SUI);
        mint_pt<MAR_2024>(test, STAKER_ADDR_5, 77 * MIST_PER_SUI); 
        mint_pt<MAR_2024>(test, STAKER_ADDR_6, 134 * MIST_PER_SUI); 

        // Verify
        next_tx(test, STAKER_ADDR_1);
        {
            let pt_token_1 = test::take_from_sender<Coin<PT_TOKEN<MAR_2024>>>(test);
            let pt_token_2 = test::take_from_sender<Coin<PT_TOKEN<JUN_2024>>>(test); 

            assert!( coin::value(&pt_token_1) == 100699420903, 0); // 100.699420903 PT
            assert!( coin::value(&pt_token_2) == 101757735247, 1); // 101.757735247 PT
 
            test::return_to_sender(test, pt_token_1);
            test::return_to_sender(test, pt_token_2);

        };

        advance_epoch(test, 61);

        // Redeem with the amount that requires unstaking only a single locked asset.
        next_tx(test, STAKER_ADDR_1);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test); 
            let pt_token = test::take_from_sender<Coin<PT_TOKEN<MAR_2024>>>(test);
            
            let redeem_coin = coin::split(&mut pt_token, 100*MIST_PER_SUI, ctx(test));

            vault::redeem<MAR_2024>(&mut system_state, &mut global, redeem_coin , ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);
            test::return_to_sender(test, pt_token);
        };

        // Cleaning up remaining SUI in the pending withdrawal pool
        next_tx(test, ADMIN_ADDR);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let global = test::take_shared<Global>(test); 

            let remaining_amount = vault::get_pending_withdrawal_amount(&global);   

            assert!( remaining_amount == 498148547, 2); // 0.498148547 SUI

            vault::withdraw_redemption_pool(&mut global, &mut managercap, remaining_amount, ctx(test) );

            test::return_to_sender(test, managercap);
            test::return_shared(global);
        };

        // Redeem the larger amount which may require unstaking from multiple locked assets.
        next_tx(test, STAKER_ADDR_2);
        {
            let system_state = test::take_shared<SuiSystemState>(test);
            let global = test::take_shared<Global>(test); 

            vault::redeem<MAR_2024>(&mut system_state, &mut global, coin::mint_for_testing<PT_TOKEN<MAR_2024>>( 400*MIST_PER_SUI , ctx(test)) , ctx(test));

            test::return_shared(global);
            test::return_shared(system_state);  
        };

    }

}