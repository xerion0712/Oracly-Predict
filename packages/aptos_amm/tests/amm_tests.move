
#[test_only]
module legato_amm_addr::amm_tests {

    use std::string::utf8;
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::primary_fungible_store;

    use legato_amm_addr::mock_usdc_fa::{Self};
    use legato_amm_addr::mock_legato_fa::{Self}; 
    use legato_amm_addr::amm::{Self};

    // Initial allocation at 1 LEGATO = 50,000 USDC
    const LEGATO_AMOUNT_90_10: u64 = 180_000_000; // 90% at 1.8 LEGATO
    const USDC_AMOUNT_90_10: u64 = 10000_000000;  // 10% at 10,000 USDC
    
    // Registering pools
    #[test(deployer = @legato_amm_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);
    }

    // Swapping tokens
    #[test(deployer = @legato_amm_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_usdc_for_legato(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);

        mock_usdc_fa::mint( user_address, 100_000000 ); // 100 USDC
        amm::swap(user, mock_usdc_fa::get_metadata(), mock_legato_fa::get_metadata(), 100_000000, 1 );

        assert!( primary_fungible_store::balance( user_address, mock_legato_fa::get_metadata()) == 197_906, 1 ); // 0.00197906 LEGATO at a rate of 1 LEGATO = 52405 USDT
    }

    #[test(deployer = @legato_amm_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_legato_for_usdc(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);

        mock_legato_fa::mint( user_address, 100000 ); // 0.001 LEGATO
        amm::swap(user, mock_legato_fa::get_metadata(), mock_usdc_fa::get_metadata(), 100000, 1 );

        assert!( primary_fungible_store::balance( user_address, mock_usdc_fa::get_metadata()) == 49_613272 , 2 ); // 49.613272 USDC at a rate of 1 LEGATO = 51465 USDT
    }

    #[test(deployer = @legato_amm_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_remove_liquidity(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        let lp_provider_address = signer::address_of(lp_provider);

        mock_usdc_fa::mint( lp_provider_address,  5000_000000); // 5000 USDC
        mock_legato_fa::mint( lp_provider_address,  15000000); // 0.15 LEGATO

        amm::add_liquidity(
            lp_provider,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata(),
            5000_000000,
            1,
            15000000,
            1
        );

        let lp_metadata =  amm::get_lp_metadata( mock_usdc_fa::get_metadata(), mock_legato_fa::get_metadata() );
        let lp_balance =  primary_fungible_store::balance( lp_provider_address,lp_metadata );

        amm::remove_liquidity(
            lp_provider,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata(),
            lp_balance
        );
        
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
        mock_usdc_fa::mint( lp_provider_address, USDC_AMOUNT_90_10 );

        // LEGATO 
        mock_legato_fa::mint( lp_provider_address, LEGATO_AMOUNT_90_10 );

        // Setup a 10/90 pool

        amm::register_pool(
            deployer,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata(),
            1000,
            9000
        );

        amm::add_liquidity(
            lp_provider,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata(),
            USDC_AMOUNT_90_10,
            1,
            LEGATO_AMOUNT_90_10,
            1
        );

        let lp_metadata_90_10 = amm::get_lp_metadata( mock_usdc_fa::get_metadata(), mock_legato_fa::get_metadata() );
        // first LP transfers to the deployer
        let lp_amount_90_10 = primary_fungible_store::balance( deployer_address, lp_metadata_90_10);

        assert!( lp_amount_90_10 == 268994649, 0 );
    }

}