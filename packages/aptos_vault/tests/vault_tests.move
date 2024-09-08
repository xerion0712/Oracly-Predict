

#[test_only]
module legato_vault_addr::vault_tests {

    use std::features;
    use std::signer;

    use aptos_std::bls12381;
    use aptos_std::stake;
    use aptos_std::vector;

    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::reconfiguration;
    use aptos_framework::delegation_pool as dp;
    use aptos_framework::timestamp;
    use aptos_framework::primary_fungible_store;

    use legato_vault_addr::vault;

    #[test_only]
    const EPOCH_DURATION: u64 = 86400;

    #[test_only]
    const ONE_APT: u64 = 100000000; // 1x10**8

    #[test_only]
    const LOCKUP_CYCLE_SECONDS: u64 = 3600;

    #[test_only]
    const DELEGATION_POOLS: u64 = 11;

    #[test_only]
    const MODULE_EVENT: u64 = 26;
 
    #[test_only]
    const OPERATOR_BENEFICIARY_CHANGE: u64 = 39;

    #[test_only]
    const COMMISSION_CHANGE_DELEGATION_POOL: u64 = 42;

    #[test_only]
    const COIN_TO_FUNGIBLE_ASSET_MIGRATION: u64 = 60;

    #[test(deployer = @legato_vault_addr,aptos_framework = @aptos_framework, validator_1 = @0xdead, validator_2 = @0x1111, user_1 = @0xbeef, user_2 = @0xfeed)]
    fun test_mint_redeem(
        deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2);
        
        // Setup the system
        setup_vaults(deployer, signer::address_of(validator_1), signer::address_of(validator_2));
    
        // Prepare test accounts
        create_test_accounts( deployer, user_1, user_2);

        // Mint APT for user accounts for staking
        stake::mint(user_1, 100 * ONE_APT);
        stake::mint(user_2, 100 * ONE_APT); 

        // Mint VAULT tokens by staking APT
        vault::mint( user_1, 100 * ONE_APT);
        vault::mint( user_2, 100 * ONE_APT);
 
        // Check the VAULT token balance for both users
        let metadata = vault::get_vault_metadata(); 
        assert!( (primary_fungible_store::balance( signer::address_of(user_1), metadata )) == 99_99999000, 2); // 99.999 VAULT
        assert!( (primary_fungible_store::balance( signer::address_of(user_2), metadata )) == 100_09999999, 3); // 100.099 VAULT

        // Fast forward 100 days to simulate staking duration
        let i:u64=1;  
        while(i <= 100) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };
        
        // User 2 requests to redeem VAULT tokens
        vault::request_redeem( user_2, 100_09999999 );
        
        // Wait for another 3 days to complete the redemption process 
        i=1;  
        while(i <= 3) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        // Fulfill the redemption request
        vault::fulfil_request();

        // Check the APT balance after redemption
        assert!(coin::balance<AptosCoin>(signer::address_of(user_2)) == 110_45634154, 4 );  // User 2 received 110.456 APT
    }

    #[test(deployer = @legato_vault_addr,aptos_framework = @aptos_framework, validator_1 = @0xdead, validator_2 = @0x1111, user_1 = @0xbeef, user_2 = @0xfeed, user_3 = @0x8888, user_4 = @9999)]
    fun test_priority_list(
        deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        user_1: &signer,
        user_2: &signer,
        user_3: &signer,
        user_4: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2);
        
        // Setup the system
        setup_vaults(deployer, signer::address_of(validator_1), signer::address_of(validator_2));
    
        // Prepare test accounts
        create_test_accounts( deployer, user_1, user_2);

        account::create_account_for_test(signer::address_of(user_3));
        account::create_account_for_test(signer::address_of(user_4)); 

        vault::add_priority(deployer, signer::address_of(validator_1), 20_00000000);
        vault::add_priority(deployer, signer::address_of(validator_2), 20_00000000);

        // Mint APT for user accounts for staking
        stake::mint(user_1, 20 * ONE_APT);
        stake::mint(user_2, 10 * ONE_APT); 
        stake::mint(user_3, 10 * ONE_APT);
        stake::mint(user_4, 20 * ONE_APT); 

        // Mint VAULT tokens by staking APT
        vault::mint( user_1, 20 * ONE_APT);
        vault::mint( user_2, 10 * ONE_APT);
        vault::mint( user_3, 10 * ONE_APT);
        vault::mint( user_4, 20 * ONE_APT);
 
        // Check the staked amount on all pools
        let pool_address_1 = dp::get_owned_pool_address(signer::address_of(validator_1) );
        let pool_address_2 = dp::get_owned_pool_address(signer::address_of(validator_2) );

        let (pool_1_amount,_,_) = dp::get_stake(pool_address_1 , vault::get_config_object_address() );
        let (pool_2_amount,_,_) = dp::get_stake(pool_address_2 , vault::get_config_object_address() );

        assert!( pool_1_amount == 39_96003998, 0); // ~40 APT
        assert!( pool_2_amount == 19_98001999, 1); // ~20 APT

        stake::mint(user_4, 10 * ONE_APT); 
        vault::mint( user_4, 10 * ONE_APT);

        // Check the VAULT token balance for only user 4
        let metadata = vault::get_vault_metadata();  
        assert!( (primary_fungible_store::balance( signer::address_of(user_4), metadata )) == 33_81003245, 3); // 33.81 VAULT
        
        stake::mint(user_1, 10 * ONE_APT); 
        vault::mint( user_1, 10 * ONE_APT);
        
        // Fast forward 100 days to simulate staking duration
        let i:u64=1;  
        while(i <= 100) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };
        
        // User 4 requests to redeem VAULT tokens
        vault::request_redeem( user_4, 33_81003245 );
        
        // Wait for another 3 days to complete the redemption process 
        i=1;  
        while(i <= 3) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        // Fulfill the redemption request
        vault::fulfil_request();

        // Check the APT balance after redemption 
        assert!(coin::balance<AptosCoin>(signer::address_of(user_4)) == 32_46037972, 4 );  // User 4 received 32.46 APT
    }
 
    #[test_only]
    public fun initialize_for_test(
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer
    ) {
        initialize_for_test_custom(
            aptos_framework,
            100 * ONE_APT,
            10000 * ONE_APT,
            LOCKUP_CYCLE_SECONDS,
            true,
            1,
            1000,
            1000000
        );
        let (_sk_1, pk_1, pop_1) = generate_identity();
        initialize_test_validator(&pk_1, &pop_1, validator_1, 1000 * ONE_APT, true, false);
        let (_sk_2, pk_2, pop_2) = generate_identity();
        initialize_test_validator(&pk_2, &pop_2, validator_2, 2000 * ONE_APT, true, true);
    }

    // Convenient function for setting up the mock system
    #[test_only]
    public fun initialize_for_test_custom(
        aptos_framework: &signer,
        minimum_stake: u64,
        maximum_stake: u64,
        recurring_lockup_secs: u64,
        allow_validator_set_change: bool,
        rewards_rate_numerator: u64,
        rewards_rate_denominator: u64,
        voting_power_increase_limit: u64
    ) {
        account::create_account_for_test(signer::address_of(aptos_framework));
        
        features::change_feature_flags_for_testing(aptos_framework, vector[
            COIN_TO_FUNGIBLE_ASSET_MIGRATION,
            DELEGATION_POOLS,
            MODULE_EVENT,
            OPERATOR_BENEFICIARY_CHANGE,
            COMMISSION_CHANGE_DELEGATION_POOL
        ], vector[ ]);

        reconfiguration::initialize_for_test(aptos_framework);
        stake::initialize_for_test_custom(
            aptos_framework,
            minimum_stake,
            maximum_stake,
            recurring_lockup_secs,
            allow_validator_set_change,
            rewards_rate_numerator,
            rewards_rate_denominator,
            voting_power_increase_limit
        );
    }



    #[test_only]
    public fun end_epoch() {
        stake::end_epoch();
        reconfiguration::reconfigure_for_test_custom();
    }

    #[test_only]
    public fun generate_identity(): (bls12381::SecretKey, bls12381::PublicKey, bls12381::ProofOfPossession) {
        let (sk, pkpop) = bls12381::generate_keys();
        let pop = bls12381::generate_proof_of_possession(&sk);
        let unvalidated_pk = bls12381::public_key_with_pop_to_normal(&pkpop);
        (sk, unvalidated_pk, pop)
    }

    #[test_only]
    public fun initialize_test_validator(
        public_key: &bls12381::PublicKey,
        proof_of_possession: &bls12381::ProofOfPossession,
        validator: &signer,
        amount: u64,
        should_join_validator_set: bool,
        should_end_epoch: bool
    ) {
        let validator_address = signer::address_of(validator);
        if (!account::exists_at(signer::address_of(validator))) {
            account::create_account_for_test(validator_address);
        };

        dp::initialize_delegation_pool(validator, 0, vector::empty<u8>());
        validator_address = dp::get_owned_pool_address(validator_address);

        let pk_bytes = bls12381::public_key_to_bytes(public_key);
        let pop_bytes = bls12381::proof_of_possession_to_bytes(proof_of_possession);
        stake::rotate_consensus_key(validator, validator_address, pk_bytes, pop_bytes);

        if (amount > 0) {
            mint_and_add_stake(validator, amount);
        };

        if (should_join_validator_set) {
            stake::join_validator_set(validator, validator_address);
        };
        if (should_end_epoch) {
            end_epoch();
        };
    }

    #[test_only]
    public fun create_test_accounts(
        deployer: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        account::create_account_for_test(signer::address_of(user_1));
        account::create_account_for_test(signer::address_of(user_2)); 
        account::create_account_for_test(signer::address_of(deployer)); 
        account::create_account_for_test( vault::get_config_object_address() ); 
    }

    #[test_only]
    public fun setup_vaults(sender: &signer , validator_1: address, validator_2: address) {
        
        vault::init_module_for_testing(sender);

        // Add the validators to the whitelist.
        vault::attach_pool(sender, validator_1);
        vault::attach_pool(sender, validator_2);

    }

    #[test_only]
    public fun mint_and_add_stake(account: &signer, amount: u64) {
        stake::mint(account, amount);
        dp::add_stake(account, dp::get_owned_pool_address(signer::address_of(account)), amount);
    }
}