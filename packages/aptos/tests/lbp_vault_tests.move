// Test launching new tokens (LEGATO) on LBP when pairing with vault tokens

#[test_only]
module legato_addr::lbp_vault_tests {

    use std::features;
    use std::signer;

    use aptos_std::bls12381;
    use aptos_std::stake;
    use aptos_std::vector;

    use aptos_framework::account;
    use aptos_framework::aptos_coin::{AptosCoin, Self};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::coin;
    use aptos_framework::reconfiguration;
    use aptos_framework::delegation_pool as dp;
    use aptos_framework::timestamp; 
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object;

    use legato_addr::vault;
    use legato_addr::vault_token_name::{MAR_2024, JUN_2024};
    use legato_addr::mock_legato_fa::{Self}; 
    use legato_addr::amm::{Self};

    const LEGATO_AMOUNT: u64 = 60000000_00000000; // 60 mil. LEGATO
    const APTOS_AMOUNT: u64 = 300_00000000; // 300 APT for bootstrap

    const TARGET_AMOUNT: u64 = 30000_00000000; 

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

    #[test(deployer = @legato_addr,aptos_framework = @aptos_framework, validator_1 = @0xdead, validator_2 = @0x1111, lp_provider = @0xdead, user = @0xbeef )]
    fun test_stake_for_legato(
        deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        lp_provider: &signer, 
        user: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2);

        // Setup Legato vaults
        setup_vaults(deployer, signer::address_of(validator_1), signer::address_of(validator_2));

        register_pools(deployer, lp_provider, user);

        // Prepare test accounts
        create_test_accounts( deployer, lp_provider, user);

        // Mint APT tokens
        stake::mint(user, 100 * ONE_APT);

        assert!(coin::balance<AptosCoin>(signer::address_of(user)) == 100 * ONE_APT, 0);

        amm::future_swap<MAR_2024>(user, 100 * ONE_APT, mock_legato_fa::get_metadata() );

        // Check balances
        assert!(primary_fungible_store::balance( signer::address_of(user), vault::get_vault_metadata<MAR_2024>() ) == 10000000000, 1 );
        assert!(primary_fungible_store::balance( signer::address_of(user), mock_legato_fa::get_metadata()) == 3055201718178, 2 );

        let apt_fa_metadata = object::address_to_object<Metadata>(@aptos_fungible_asset); 
        let (weight_apt, weight_legato, _, _ ) = amm::lbp_info( apt_fa_metadata, mock_legato_fa::get_metadata());

        assert!( weight_apt == 1020 , 3);
        assert!( weight_legato == 8980 , 4);

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

    #[test_only]
    public fun end_epoch() {
        stake::end_epoch();
        reconfiguration::reconfigure_for_test_custom();
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
    public fun register_pools(deployer: &signer, lp_provider: &signer, user: &signer) {
        
        let apt_metadata = object::address_to_object<Metadata>(@aptos_fungible_asset);

        amm::init_module_for_testing(deployer);
        mock_legato_fa::init_module_for_testing(deployer); 
    
        let deployer_address = signer::address_of(deployer);
        let lp_provider_address = signer::address_of(lp_provider);
        let user_address = signer::address_of(user);

        account::create_account_for_test(lp_provider_address);  
        account::create_account_for_test(deployer_address); 
        account::create_account_for_test(user_address); 
        account::create_account_for_test( amm::get_config_object_address() ); 

        // FA PT 
        let fa_asset = aptos_coin::mint_apt_fa_for_test( APTOS_AMOUNT );
        
        primary_fungible_store::ensure_primary_store_exists(lp_provider_address, apt_metadata);
        let store = primary_fungible_store::primary_store(lp_provider_address, apt_metadata);
        fungible_asset::deposit(store, fa_asset);

        // LEGATO 
        mock_legato_fa::mint( lp_provider_address, LEGATO_AMOUNT );
 
        amm::register_lbp_pool(
            deployer,
            false,
            apt_metadata,
            mock_legato_fa::get_metadata(), 
            9000,
            6000, 
            true,
            TARGET_AMOUNT
        );

        amm::add_liquidity(
            lp_provider,
            apt_metadata,
            mock_legato_fa::get_metadata(), 
            APTOS_AMOUNT,
            1,
            LEGATO_AMOUNT,
            1
        );
 

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

        // Update the batch amount to 200 APT.
        vault::update_batch_amount(sender, 200 * ONE_APT );

        // Add the validators to the whitelist.
        vault::add_whitelist(sender, validator_1);
        vault::add_whitelist(sender, validator_2);

        // Vault #1 matures in 100 epochs.
        let maturity_1 = timestamp::now_seconds()+(100*EPOCH_DURATION);

        // Create Vault #1 with an APY of 5%.
        vault::new_vault<MAR_2024>(sender, maturity_1, 5, 100);

        // Vault #2 matures in 200 epochs.
        let maturity_2 = timestamp::now_seconds()+(200*EPOCH_DURATION);

        // Create Vault #2 with an APY of 4%.
        vault::new_vault<JUN_2024>(sender, maturity_2, 4, 100);
    }

    #[test_only]
    public fun mint_and_add_stake(account: &signer, amount: u64) {
        stake::mint(account, amount);
        dp::add_stake(account, dp::get_owned_pool_address(signer::address_of(account)), amount);
    }

}