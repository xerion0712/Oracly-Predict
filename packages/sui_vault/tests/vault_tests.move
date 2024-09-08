

#[test_only]
module legato::vault_tests {

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx  }; 
    use sui_system::sui_system::{ SuiSystemState, validator_stake_amount  };
    use sui::coin::{Self, Coin};
    use sui::sui::SUI; 
 
    use legato::vault_utils::{
        scenario, 
        advance_epoch,
        set_up_sui_system_state,
        setup_vault,
        mint
    };

    use legato::vault::{Self, VaultGlobal, VAULT, ManagerCap };

    const ADMIN_ADDR: address = @0x21;

    const STAKER_ADDR_1: address = @0x42;
    const STAKER_ADDR_2: address = @0x43;
    const STAKER_ADDR_3: address = @0x44;
    const STAKER_ADDR_4: address = @0x45;
    const STAKER_ADDR_5: address = @0x45;
    const STAKER_ADDR_6: address = @0x45;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    // Tests the mint and redeem flow
    #[test]
    public fun test_mint_redeem_flow() {
        let mut scenario = scenario();
        mint_redeem_flow(&mut scenario);
        test::end(scenario);
    }

    // Test the priority list functionality
    #[test]
    public fun test_priority_list() {
        let mut scenario = scenario();
        priority_list(&mut scenario);
        test::end(scenario);
    }

    // Test at high volumes
    // #[test]
    // public fun test_high_volumes() {
    //     let mut scenario = scenario();
    //     high_volumes(&mut scenario);
    //     test::end(scenario);
    // }

    fun mint_redeem_flow( test: &mut Scenario ) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR );

        // Mint VAULT tokens from all users
        mint( test, STAKER_ADDR_1, 100 * MIST_PER_SUI); 
        mint( test, STAKER_ADDR_2, 200 * MIST_PER_SUI); 
        mint( test, STAKER_ADDR_3, 50 * MIST_PER_SUI); 
        mint( test, STAKER_ADDR_4, 100 * MIST_PER_SUI); 
        mint( test, STAKER_ADDR_5, 77 * MIST_PER_SUI); 
        mint( test, STAKER_ADDR_6, 134 * MIST_PER_SUI); 

        // Check the balance
        next_tx(test, STAKER_ADDR_2);
        {
            let vault_token = test::take_from_sender<Coin<VAULT>>(test);  
            assert!( coin::value(&vault_token) == 200_000000000, 0); // 200 VAULT
            test::return_to_sender(test, vault_token);
        };

        // Forward 61 epochs
        advance_epoch(test, 61);

        // Requests to redeem VAULT tokens that requires unstaking only a single locked asset.
        next_tx(test, STAKER_ADDR_1);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 
            let vault_token = test::take_from_sender<Coin<VAULT>>(test); 
            vault::request_redeem(&mut system_state, &mut global, vault_token , ctx(test)); 
            test::return_shared(global);
            test::return_shared(system_state); 
        };

        // Clean up remaining SUI in the pending withdrawal pool
        next_tx(test, ADMIN_ADDR);
        {
            let mut managercap = test::take_from_sender<ManagerCap>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 
            let remaining_amount = vault::get_pending_withdrawal_amount(&global);   
 
            assert!( remaining_amount == 1007, 1); // 1007 MIST

            vault::withdraw_redemption_pool(&mut global, &mut managercap, remaining_amount, ctx(test) );

            test::return_to_sender(test, managercap);
            test::return_shared(global);
        };

        // Redeem the larger amount which requires unstaking from multiple locked assets
        next_tx(test, STAKER_ADDR_2);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 
            vault::request_redeem(&mut system_state, &mut global, coin::mint_for_testing<VAULT>( 220_000000000 , ctx(test)) , ctx(test)); 
            test::return_shared(global);
            test::return_shared(system_state); 
        };

        advance_epoch(test, 1);

        // Fulfill pending redemption requests to distribute SUI to users
        next_tx(test, STAKER_ADDR_1);
        { 
            let mut global = test::take_shared<VaultGlobal>(test); 
            vault::fulfil_request( &mut global , ctx(test)); 
            test::return_shared(global); 
        };

        // Check the balances
        next_tx(test, STAKER_ADDR_1);
        { 
            let sui_token = test::take_from_sender<Coin<SUI>>(test);  
            assert!( coin::value( &sui_token ) ==  100_745684456, 2 ); // Stake 100 SUI and redeem at 100.7456 SUI
            test::return_to_sender( test, sui_token );
        };
        next_tx(test, STAKER_ADDR_2);
        {
            let sui_token = test::take_from_sender<Coin<SUI>>(test);  
            assert!( coin::value( &sui_token ) ==  221_640507624, 3 ); // Stake 220 SUI and redeem at 221.6405 SUI
            test::return_to_sender( test, sui_token );
        };

        // Restake remaining SUI 
        next_tx(test, ADMIN_ADDR);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut managercap = test::take_from_sender<ManagerCap>(test);
            let mut global = test::take_shared<VaultGlobal>(test);  

            let remaining_amount = vault::get_pending_withdrawal_amount(&global);   
            assert!( remaining_amount == 14_104396359, 5); // 14.104 SUI 
            vault::restake(&mut system_state, &mut global, &mut managercap, remaining_amount, ctx(test));

            test::return_to_sender(test, managercap);
            test::return_shared(global); 
            test::return_shared(system_state);
        };

    }

    fun priority_list(test: &mut Scenario ) {
        set_up_sui_system_state();
        advance_epoch(test, 40); // <-- overflow when less than 40

        // setup vaults
        setup_vault(test, ADMIN_ADDR );

        next_tx(test, ADMIN_ADDR);
        {
            let mut managercap = test::take_from_sender<ManagerCap>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 

            vault::add_priority( &mut global,  &mut managercap,  @0x1, 100_000000000);
            vault::add_priority( &mut global,  &mut managercap,  @0x2, 100_000000000);

            test::return_to_sender(test, managercap);
            test::return_shared(global);
        };

        mint( test, STAKER_ADDR_1, 50 * MIST_PER_SUI); 
        mint( test, STAKER_ADDR_2, 100 * MIST_PER_SUI); 
        mint( test, STAKER_ADDR_3, 150 * MIST_PER_SUI); 
        
        advance_epoch(test, 1);

        // Checking validator staking amount
        next_tx(test, STAKER_ADDR_1);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);
            
            let pool_1_amount = validator_stake_amount(&mut system_state, @0x1);
            let pool_2_amount = validator_stake_amount(&mut system_state, @0x2); 
            
            assert!( pool_1_amount == 1005275000000000, 7 );
            assert!( pool_2_amount == 1505275000000000, 8 );

            test::return_shared(system_state); 
        };

        // Forward 20 epochs
        advance_epoch(test, 20);

        // Requests to redeem VAULT tokens that requires unstaking only a single locked asset.
        next_tx(test, STAKER_ADDR_1);
        {
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 
            let vault_token = test::take_from_sender<Coin<VAULT>>(test);  
            vault::request_redeem(&mut system_state, &mut global, vault_token , ctx(test)); 
            test::return_shared(global);
            test::return_shared(system_state); 
        };

        advance_epoch(test, 1);

        // Fulfill pending redemption requests to distribute SUI to users
        next_tx(test, STAKER_ADDR_1);
        { 
            let mut global = test::take_shared<VaultGlobal>(test); 
            vault::fulfil_request( &mut global , ctx(test)); 
            test::return_shared(global); 
        };

        next_tx(test, STAKER_ADDR_1);
        { 
            let sui_token = test::take_from_sender<Coin<SUI>>(test);   
            assert!( coin::value( &sui_token ) ==  50_103691692, 2 ); // Stake 100 SUI and redeem at 50.1036 SUI
            test::return_to_sender( test, sui_token );
        };

    }

    // Simulates high-volume transactions 
    fun high_volumes(test: &mut Scenario) {
        set_up_sui_system_state();
        advance_epoch(test, 20); 

        // Initialize and configure the vaults
        setup_vault(test, ADMIN_ADDR );

        next_tx(test, ADMIN_ADDR);
        {
            let mut managercap = test::take_from_sender<ManagerCap>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 

            // Add priority pools with specified quotas
            vault::add_priority( &mut global, &mut managercap,  @0x1, 2500_000000000);
            vault::add_priority( &mut global, &mut managercap,  @0x2, 2500_000000000);

            test::return_to_sender(test, managercap);
            test::return_shared(global);
        };

        let mut count = 0; 

        // Mint and stake tokens for different stakers
        while ( count < 100) {
            let amount_to_stake = count+1; 
            let staker_address = get_random_staker(count);
            mint( test, staker_address, amount_to_stake * MIST_PER_SUI); 
            count = count +1;
        };

        // Fast forward 20 epochs
        advance_epoch(test, 20);

        next_tx(test, STAKER_ADDR_1);
        {   
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 
            vault::request_redeem(&mut system_state, &mut global, coin::mint_for_testing<VAULT>( 5_000000000 , ctx(test)) , ctx(test)); 
            test::return_shared(global);
            test::return_shared(system_state); 
        };

        next_tx(test, STAKER_ADDR_2);
        {   
            let mut system_state = test::take_shared<SuiSystemState>(test);
            let mut global = test::take_shared<VaultGlobal>(test); 
            vault::request_redeem(&mut system_state, &mut global, coin::mint_for_testing<VAULT>( 5_000000000 , ctx(test)) , ctx(test)); 
            test::return_shared(global);
            test::return_shared(system_state); 
        };

        advance_epoch(test, 1);

        // Fulfill pending redemption requests to distribute SUI to users
        next_tx(test, STAKER_ADDR_1);
        { 
            let mut global = test::take_shared<VaultGlobal>(test); 
            vault::fulfil_request( &mut global, ctx(test)); 
            test::return_shared(global); 
        };

        // Verify the SUI balance
        next_tx(test, STAKER_ADDR_1);
        { 
            let sui_token = test::take_from_sender<Coin<SUI>>(test);    
            assert!( coin::value( &sui_token ) ==  5_009875856, 3 );  
            test::return_to_sender( test, sui_token );
        };

    }

    fun get_random_staker(seed: u64) : address {
        let id = seed % 5;
        if (id == 0) 
            STAKER_ADDR_1
        else if (id == 1) 
            STAKER_ADDR_2
        else if (id == 2)
            STAKER_ADDR_3
        else if (id == 3)
            STAKER_ADDR_4
        else if (id == 3)
            STAKER_ADDR_5
        else STAKER_ADDR_6 
    }

}