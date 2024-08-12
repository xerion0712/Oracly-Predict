
#[test_only]
module legato_amm_addr::routes_tests {

    use std::string::utf8;
    use std::signer;
    use std::vector;

    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleStore};
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::account;
    use aptos_framework::primary_fungible_store;

    use legato_amm_addr::amm::{Self};
    use legato_amm_addr::base_fungible_asset::{Self};

    // Pool#A Allocation
    const AAA_AMOUNT_POOL_A: u64 = 233330_00000000; // 70%
    const USDC_AMOUNT_POOL_A: u64 = 10000_00000000; // 30%
    
    // Pool#B Allocation
    const USDC_AMOUNT_POOL_B: u64 = 100000_00000000; // 50%
    const SUI_AMOUNT_POOL_B: u64 = 200000_00000000; // 50%

    // Pool#C Allocation
    const SUI_AMOUNT_POOL_C: u64 = 10000_00000000; // 20%
    const DDD_AMOUNT_POOL_C: u64 = 400000_00000000; // 80%

    // Registering pools
    #[test(deployer = @legato_amm_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);
    }

    // Swapping tokens across 3 pools
    #[test(deployer = @legato_amm_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_aaa_for_ddd(deployer: &signer, lp_provider: &signer, user: &signer) {
        let token_metadata = register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);

        let metadata_aaa = *vector::borrow( &token_metadata, 0 );
        let metadata_usdc = *vector::borrow( &token_metadata, 1 );
        let metadata_sui = *vector::borrow( &token_metadata, 2 );
        let metadata_ddd = *vector::borrow( &token_metadata, 3 );

        base_fungible_asset::mint_to_primary_stores(  metadata_aaa, vector[user_address], vector[ 100_00000000 ]); // 100 AAA 
        amm::route_swap(user, vector[ metadata_aaa, metadata_usdc, metadata_sui, metadata_ddd ], 100_00000000, 0 );

        assert!( primary_fungible_store::balance( user_address, metadata_ddd ) == 196_28745556, 1 ); // 196.28 DDD 
    }

    #[test(deployer = @legato_amm_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_ddd_for_aaa(deployer: &signer, lp_provider: &signer, user: &signer) {
        let token_metadata = register_pools(deployer, lp_provider, user);

        let user_address = signer::address_of(user);

        let metadata_aaa = *vector::borrow( &token_metadata, 0 );
        let metadata_usdc = *vector::borrow( &token_metadata, 1 );
        let metadata_sui = *vector::borrow( &token_metadata, 2 );
        let metadata_ddd = *vector::borrow( &token_metadata, 3 );

        base_fungible_asset::mint_to_primary_stores(  metadata_ddd, vector[user_address], vector[ 200_00000000 ]); // 200 DDD 
        amm::route_swap(user, vector[ metadata_ddd, metadata_sui, metadata_usdc, metadata_aaa   ], 200_00000000, 0 );

        assert!( primary_fungible_store::balance( user_address, metadata_aaa ) == 114_67428594, 1 ); // 114.67 AAA 
    }
     
    #[test_only]
    public fun register_pools(deployer: &signer, lp_provider: &signer, user: &signer) : vector<Object<Metadata>> {
        
        let token_metadata = vector::empty<Object<Metadata>>();
    
        amm::init_module_for_testing(deployer);

        let deployer_address = signer::address_of(deployer);
        let lp_provider_address = signer::address_of(lp_provider);
        let user_address = signer::address_of(user);

        account::create_account_for_test(lp_provider_address);  
        account::create_account_for_test(deployer_address); 
        account::create_account_for_test(user_address); 
        account::create_account_for_test( amm::get_config_object_address() ); 

        let metadata_aaa = base_fungible_asset::create_custom_token(deployer, b"AAA");
        base_fungible_asset::mint_to_primary_stores(  metadata_aaa, vector[lp_provider_address], vector[ AAA_AMOUNT_POOL_A ]);

        let metadata_usdc = base_fungible_asset::create_custom_token(deployer, b"USDC");
        base_fungible_asset::mint_to_primary_stores(  metadata_usdc, vector[lp_provider_address], vector[ USDC_AMOUNT_POOL_A+USDC_AMOUNT_POOL_B ]);

        let metadata_sui = base_fungible_asset::create_custom_token(deployer, b"SUI");
        base_fungible_asset::mint_to_primary_stores(  metadata_sui, vector[lp_provider_address], vector[ SUI_AMOUNT_POOL_B+SUI_AMOUNT_POOL_C ]);

        let metadata_ddd = base_fungible_asset::create_custom_token(deployer, b"DDD");
        base_fungible_asset::mint_to_primary_stores(  metadata_ddd, vector[lp_provider_address], vector[ DDD_AMOUNT_POOL_C ]);

        vector::push_back( &mut token_metadata, metadata_aaa );
        vector::push_back( &mut token_metadata, metadata_usdc );
        vector::push_back( &mut token_metadata, metadata_sui );
        vector::push_back( &mut token_metadata, metadata_ddd );

        // Setup Pool#A

        amm::register_pool(
            deployer,
            metadata_aaa,
            metadata_usdc,
            7000,
            3000
        );

        amm::add_liquidity(
            lp_provider,
            metadata_aaa,
            metadata_usdc,
            AAA_AMOUNT_POOL_A,
            1,
            USDC_AMOUNT_POOL_A,
            1
        );

        // Setup Pool#B

        amm::register_pool(
            deployer,
            metadata_usdc,
            metadata_sui,
            5000,
            5000
        );

        amm::add_liquidity(
            lp_provider,
            metadata_usdc,
            metadata_sui,
            USDC_AMOUNT_POOL_B,
            1,
            SUI_AMOUNT_POOL_B,
            1
        );

        // Setup Pool#C

        amm::register_pool(
            deployer,
            metadata_sui,
            metadata_ddd,
            2000,
            8000
        );

        amm::add_liquidity(
            lp_provider,
            metadata_sui,
            metadata_ddd,
            SUI_AMOUNT_POOL_C,
            1,
            DDD_AMOUNT_POOL_C,
            1
        );

        token_metadata
    }




}