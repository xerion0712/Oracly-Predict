// Test launching new tokens (LEGATO) on LBP when using USDC as the settlement assets

#[test_only]
module legato_addr::lbp_usdc_tests {

    use std::signer;

    use aptos_framework::account;
    use aptos_framework::primary_fungible_store;

    use legato_addr::mock_usdc_fa::{Self};
    use legato_addr::mock_legato_fa::{Self}; 
    use legato_addr::amm::{Self};

    const LEGATO_AMOUNT: u64 = 60000000_00000000; // 60 mil. LEGATO
    const USDC_AMOUNT: u64 = 500_000_000; // 500 USDC for bootstrap LP

    // Registering pools
    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_trade_until_stabilized(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        trade_until_stabilized(user);
    }

    #[test_only]
    public fun register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        
        amm::init_module_for_testing(deployer);
        mock_usdc_fa::init_module_for_testing(deployer);
        mock_legato_fa::init_module_for_testing(deployer); 
    
        let deployer_address = signer::address_of(deployer);
        let lp_provider_address = signer::address_of(lp_provider);
        let user_address = signer::address_of(user);

        account::create_account_for_test(lp_provider_address);  
        account::create_account_for_test(deployer_address); 
        account::create_account_for_test(user_address); 
        account::create_account_for_test( amm::get_config_object_address() ); 

        // USDC
        mock_usdc_fa::mint( lp_provider_address, USDC_AMOUNT );

        // LEGATO 
        mock_legato_fa::mint( lp_provider_address, LEGATO_AMOUNT );
 
        // Setup a 50/50 pool

        amm::register_lbp_pool(
            deployer,
            false,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata(),
            9000,
            6000, 
            false,
            50000_000000 // 50,000 USDC
        );

        amm::add_liquidity(
            lp_provider,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata(),
            USDC_AMOUNT,
            1,
            LEGATO_AMOUNT,
            1
        );
 

    }

    #[test_only]
    public fun trade_until_stabilized( user: &signer) {
        
        // Buy LEGATO with 1000 USDC for 50 times
        let counter=  0;
        let current_weight_legato = 9000;
        let current_weight_usdc = 1000;

        let user_address = signer::address_of(user);

        mock_usdc_fa::mint( user_address, 50000_000000 ); // 50,000 USDC


        while ( counter < 50) {

            amm::swap(user, mock_usdc_fa::get_metadata(), mock_legato_fa::get_metadata(), 1000_000000, 1 );  // 1,000 USDC
            let current_balance =  primary_fungible_store::balance( user_address, mock_legato_fa::get_metadata());
            mock_legato_fa::burn( user_address, current_balance );

            // Check weights
            let (weight_usdc, weight_legato, _, _ ) = amm::lbp_info( mock_usdc_fa::get_metadata(), mock_legato_fa::get_metadata());
            // Keep lowering
            assert!( current_weight_legato >= weight_legato, counter );
            assert!( current_weight_usdc <= weight_usdc, counter );

            current_weight_legato = weight_legato;
            current_weight_usdc = weight_usdc;

            counter = counter+1;
        };

        // Check final weights
        let (weight_usdc, weight_legato, _, _ ) = amm::lbp_info( mock_usdc_fa::get_metadata(), mock_legato_fa::get_metadata());
        assert!( weight_usdc == 4000, 0 );
        assert!( weight_legato == 6000, 1 );

    }


}