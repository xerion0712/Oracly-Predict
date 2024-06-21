#[test_only]
module legato_addr::amm_tests {

    use std::string::utf8;
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::primary_fungible_store;

    use legato_addr::mock_usdc_fa::{Self};
    use legato_addr::mock_legato_fa::{Self};
    use legato_addr::mock_xyz_fa::{Self};
    use legato_addr::amm::{Self};
    
    // When setting up a 50/50 pool of ~$100k
    // Initial allocation at 1 LEGATO = 0.001 USDC
    const LEGATO_AMOUNT_50_50: u64  = 50000000_00000000; // 50,000,000 LEGATO
    const USDC_AMOUNT_50_50: u64 = 50000_000000; // 50,000 USDC

    // Initial allocation at 1 XYZ = 50,000 USDC
    const USDC_AMOUNT_90_10: u64 = 10000_000000;  // 10% at 10,000 USDC
    const XYZ_AMOUNT_90_10: u64 = 180_000_000; // 90% at 1.8 XYZ

    // Registering pools
    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);
    }

    #[test_only]
    public fun register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        
        amm::init_module_for_testing(deployer);
        mock_usdc_fa::init_module_for_testing(deployer);
        mock_legato_fa::init_module_for_testing(deployer);
        mock_xyz_fa::init_module_for_testing(deployer);
    
        let deployer_address = signer::address_of(deployer);
        let lp_provider_address = signer::address_of(lp_provider);
        let user_address = signer::address_of(user);

        account::create_account_for_test(lp_provider_address);  
        account::create_account_for_test(deployer_address); 
        account::create_account_for_test(user_address); 
        account::create_account_for_test( amm::get_config_object_address() ); 

        // USDC
        mock_usdc_fa::mint( lp_provider_address, USDC_AMOUNT_50_50+USDC_AMOUNT_90_10 );

        // LEGATO 
        mock_legato_fa::mint( lp_provider_address, LEGATO_AMOUNT_50_50 );

        // XYZ
        mock_xyz_fa::mint( lp_provider_address, XYZ_AMOUNT_90_10 );

        // Setup a 50/50 pool

        amm::register_stable_pool(
            deployer,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata()
        );

        amm::add_liquidity(
            lp_provider,
            mock_usdc_fa::get_metadata(),
            mock_legato_fa::get_metadata(),
            USDC_AMOUNT_50_50,
            1,
            LEGATO_AMOUNT_50_50,
            1
        );

        let lp_metadata_50_50 = amm::get_lp_metadata( mock_usdc_fa::get_metadata(), mock_legato_fa::get_metadata() );
        // first LP transfers to the deployer
        let lp_amount_50_50 = primary_fungible_store::balance( deployer_address, lp_metadata_50_50);

        assert!( lp_amount_50_50 == 158113_88299841, 0 );

        // Setup a 10/90 pool

        amm::register_pool(
            deployer,
            mock_usdc_fa::get_metadata(),
            mock_xyz_fa::get_metadata(),
            1000,
            9000
        );

        amm::add_liquidity(
            lp_provider,
            mock_usdc_fa::get_metadata(),
            mock_xyz_fa::get_metadata(),
            USDC_AMOUNT_90_10,
            1,
            XYZ_AMOUNT_90_10,
            1
        );

    }

    

}