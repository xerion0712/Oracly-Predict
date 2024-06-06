// Test launching new tokens (LEGATO) on LBP when using USDC as the settlement assets

#[test_only]
module legato_addr::lbp_usdc_tests {

    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self};

    use legato_addr::mock_usdc::{Self, USDC_TOKEN};
    use legato_addr::mock_legato::{Self, LEGATO_TOKEN};
    use legato_addr::amm::{Self, LP};

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
        mock_usdc::init_module_for_testing(deployer);
        mock_legato::init_module_for_testing(deployer);

        let deployer_address = signer::address_of(deployer);
        let lp_provider_address = signer::address_of(lp_provider);
        let user_address = signer::address_of(user);

        account::create_account_for_test(lp_provider_address);  
        account::create_account_for_test(deployer_address); 
        account::create_account_for_test(user_address); 
        account::create_account_for_test( amm::get_config_object_address() ); 

        // USDC
        mock_usdc::mint( deployer , USDC_AMOUNT  ); 
        assert!( (coin::balance<USDC_TOKEN>(  deployer_address )) == USDC_AMOUNT, 0 );

        // LEGATO 
        mock_legato::mint( deployer , LEGATO_AMOUNT ); 
        assert!( (coin::balance<LEGATO_TOKEN>(  deployer_address )) == LEGATO_AMOUNT, 0 );
    
        amm::register_lbp_pool<USDC_TOKEN, LEGATO_TOKEN >( 
            deployer, 
            false, // LEGATO is on Y
            9000,
            6000, 
            false,
            50000_000000 // 50,000 USDC
        );

        amm::add_liquidity<USDC_TOKEN, LEGATO_TOKEN>(
            deployer,
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

        mock_usdc::mint( user, 50000_000000 ); // 50,000 USDC

        while ( counter < 50) {
            amm::swap<USDC_TOKEN, LEGATO_TOKEN>(user, 1000_000000, 0); // 1,000 USDC
            let current_balance = coin::balance<LEGATO_TOKEN>(signer::address_of(user));
            mock_legato::burn( user, current_balance );

            // Check weights
            let (weight_usdc, weight_legato, _, _ ) = amm::lbp_info<USDC_TOKEN, LEGATO_TOKEN>();
            // Keep lowering
            assert!( current_weight_legato >= weight_legato, counter );
            assert!( current_weight_usdc <= weight_usdc, counter );

            current_weight_legato = weight_legato;
            current_weight_usdc = weight_usdc;

            counter = counter+1;
        };

        // Check final weights
        let (weight_usdc, weight_legato, _, _ ) = amm::lbp_info<USDC_TOKEN, LEGATO_TOKEN>();
        assert!( weight_usdc == 4000, 0 );
        assert!( weight_legato == 6000, 1 );

    }

}