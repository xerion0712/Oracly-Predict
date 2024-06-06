

#[test_only]
module legato_addr::amm_tests {

    use std::string::utf8;
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, MintCapability};

    use legato_addr::mock_usdc::{Self, USDC_TOKEN};
    use legato_addr::mock_legato::{Self, LEGATO_TOKEN};
    use legato_addr::amm::{Self, LP};

    // When setting up a 90/10 pool of ~$100k
    // Initial allocation at 1 XBTC = 50,000 USDC
    const XBTC_AMOUNT: u64 = 180_000_000; // 90% at 1.8 BTC
    const USDC_AMOUNT_90_10: u64 = 10000_000000; // 10% at 10,000 USDC

    // When setting up a 50/50 pool of ~$100k
    // Initial allocation at 1 LEGATO = 0.001 USDC
    const LEGATO_AMOUNT: u64  = 50000000_00000000; // 50,000,000 LEGATO
    const USDC_AMOUNT_50_50: u64 = 50000_000000; // 50,000 USDC

    // test coins

    struct XBTC_TOKEN {}

    // Registering pools
    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);
    }

    // Swapping tokens
    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_usdc_for_xbtc(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        mock_usdc::mint( user , 100_000000 ); // 100 USDC
        amm::swap<USDC_TOKEN, XBTC_TOKEN>(user, 100_000000, 0); // 100 USDC
 
        assert!(coin::balance<XBTC_TOKEN>(signer::address_of(user)) == 197_906, 1); // 0.00197906 XBTC at a rate of 1 BTC = 52405 USDT
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_xbtc_for_usdc(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        amm::swap<XBTC_TOKEN, USDC_TOKEN>(lp_provider, 100000, 0);  // 0.001 XBTC

        assert!(coin::balance<USDC_TOKEN>(signer::address_of(lp_provider)) == 49_613272, 1); // 49.613272 USDC at a rate of 1 BTC = 51465 USDT
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_usdc_for_legato(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        mock_usdc::mint( user , 250_000000 ); // 250 USDC
        amm::swap<USDC_TOKEN, LEGATO_TOKEN>(user, 250_000000, 0); // 250 USDC

        assert!(coin::balance<LEGATO_TOKEN>(signer::address_of(user)) == 247518_59598004, 1); // 247,518 LEGATO at a rate of 0.001010028 LEGATO/USDC
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_swap_legato_for_usdc(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        mock_legato::mint( user, 100000_00000000 ); // 100,000 LEGATO
        amm::swap<LEGATO_TOKEN, USDC_TOKEN>(user, 100000_00000000, 0); // 100,000 LEGATO

        assert!(coin::balance<USDC_TOKEN>(signer::address_of(user)) == 99_302388, 1); // 99.302 USDC at a rate of 0.00099302 LEGATO/USDC
    }

    #[test(deployer = @legato_addr, lp_provider = @0xdead, user = @0xbeef )]
    fun test_remove_liquidity(deployer: &signer, lp_provider: &signer, user: &signer) {
        register_pools(deployer, lp_provider, user);

        mock_usdc::mint(lp_provider, 5000_000000);

        amm::add_liquidity<USDC_TOKEN, XBTC_TOKEN>(
            lp_provider,
            5000_000000, // 5000 USDC
            1,
            15000000, // 0.15 XBTC
            1
        );

        let lp_balance = coin::balance<LP<USDC_TOKEN, XBTC_TOKEN>>( signer::address_of(lp_provider) );

        amm::remove_liquidity<USDC_TOKEN, XBTC_TOKEN>(
            lp_provider,
            lp_balance
        );
        

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
        mock_usdc::mint( deployer , USDC_AMOUNT_50_50+USDC_AMOUNT_90_10 ); 
        assert!( (coin::balance<USDC_TOKEN>(  deployer_address )) == USDC_AMOUNT_50_50+USDC_AMOUNT_90_10, 0 );

        // LEGATO 
        mock_legato::mint( deployer , LEGATO_AMOUNT ); 
        assert!( (coin::balance<LEGATO_TOKEN>(  deployer_address )) == LEGATO_AMOUNT, 0 );

        // XBTC
        coin::register<XBTC_TOKEN>(deployer);
        coin::register<XBTC_TOKEN>(lp_provider);
        coin::register<XBTC_TOKEN>(user);
        let xbtc_mint_cap = register_coin<XBTC_TOKEN>(deployer, b"BTC", b"BTC", 8);
        coin::deposit(deployer_address, coin::mint<XBTC_TOKEN>(XBTC_AMOUNT, &xbtc_mint_cap));
        coin::deposit(lp_provider_address, coin::mint<XBTC_TOKEN>(XBTC_AMOUNT, &xbtc_mint_cap));
        coin::destroy_mint_cap(xbtc_mint_cap);
        assert!(coin::balance<XBTC_TOKEN>(deployer_address) == XBTC_AMOUNT, 1);

        // Setup a 10/90 pool
        amm::register_pool<USDC_TOKEN, XBTC_TOKEN>(deployer, 1000, 9000);

        amm::add_liquidity<USDC_TOKEN, XBTC_TOKEN>(
            deployer,
            USDC_AMOUNT_90_10,
            1,
            XBTC_AMOUNT,
            1
        );

        assert!(coin::balance<USDC_TOKEN>(deployer_address) == USDC_AMOUNT_50_50, 2);
        assert!(coin::balance<XBTC_TOKEN>(deployer_address) == 0, 3);

        assert!(coin::balance<LP<USDC_TOKEN, XBTC_TOKEN>>(deployer_address) == 2_68994649, 4);

        // Setup a 50/50 pool
        amm::register_pool<USDC_TOKEN, LEGATO_TOKEN>(deployer, 5000, 5000);

        amm::add_liquidity<USDC_TOKEN, LEGATO_TOKEN>(
            deployer,
            USDC_AMOUNT_50_50,
            1,
            LEGATO_AMOUNT,
            1
        );

        assert!(coin::balance<USDC_TOKEN>(deployer_address) == 0, 5);
        assert!(coin::balance<LEGATO_TOKEN>(deployer_address) == 0, 6);

    }


    #[test_only]
    fun register_coin<CoinType>(
        coin_admin: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8
    ): MintCapability<CoinType> {
        let (burn_cap, freeze_cap, mint_cap) =
            coin::initialize<CoinType>(
                coin_admin,
                utf8(name),
                utf8(symbol),
                decimals,
                true);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);

        mint_cap
    }

}