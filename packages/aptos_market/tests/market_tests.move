


#[test_only]
module market_addr::market_tests {

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
    use market_addr::market::{Self};

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

    #[test(vault_deployer = @legato_vault_addr, market_deployer = @market_addr, aptos_framework = @aptos_framework, validator_1 = @0x1111, validator_2 = @0x2222, lp_provider_1 = @0x3333, lp_provider_2 = @0x4444, user_1 = @0x5555, user_2 = @0x6666)]
    fun test_market_btc(
        vault_deployer: &signer,
        market_deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        lp_provider_1: &signer,
        lp_provider_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2);

        // Setup the system
        setup_systems(vault_deployer, market_deployer, signer::address_of(validator_1), signer::address_of(validator_2));

        // Prepare test accounts
        create_test_accounts( vault_deployer, market_deployer, lp_provider_1, lp_provider_2, user_1, user_2);

        // Add initial tokens
        add_initial_tokens(validator_1, validator_2);

        // Provide liquidity
        stake::mint(lp_provider_1, 10 * ONE_APT); 
        stake::mint(lp_provider_2, 10 * ONE_APT);

        market::provide(lp_provider_1, 10 * ONE_APT);
        market::provide(lp_provider_2, 10 * ONE_APT);

        let lp_metadata = market::get_lp_metadata(); 
        assert!( primary_fungible_store::balance( signer::address_of(lp_provider_1), lp_metadata ) == 9_99999000, 0);
        assert!( primary_fungible_store::balance( signer::address_of(lp_provider_2), lp_metadata ) == 10_48571527, 1);

        // Check betting capacity
        let available = market::check_betting_capacity(); 
        assert!( available == 16_35196086, 2 );

        // Check adjusted probabilities
        let adjusted_probabilities = market::get_market_adjusted_probabilities(1, 0);
        assert!(adjusted_probabilities == vector[ 1500, 3500, 3500, 1500 ], 3);

        // Place bets
        stake::mint(user_1, 40 * ONE_APT); 
        stake::mint(user_2, 12 * ONE_APT);

        market::place_bet(user_1, 1, 0, 1, 10 * ONE_APT );
        market::place_bet(user_1, 1, 0, 2, 10 * ONE_APT );
        market::place_bet(user_1, 1, 0, 3, 10 * ONE_APT );
        market::place_bet(user_1, 1, 0, 4, 10 * ONE_APT );

        available = market::check_betting_capacity(); 
        adjusted_probabilities = market::get_market_adjusted_probabilities(1, 0);

        assert!( available == 8_35196086, 4 );
        assert!(adjusted_probabilities == vector[ 3148, 5598, 5598, 3148 ], 5);

        market::place_bet(user_2, 1, 0, 1, 3 * ONE_APT );
        market::place_bet(user_2, 1, 0, 2, 3 * ONE_APT );
        market::place_bet(user_2, 1, 0, 3, 3 * ONE_APT );
        market::place_bet(user_2, 1, 0, 4, 3 * ONE_APT );
        
        // Checking bet positions
        assert!( market::get_bet_position_ids( 0, signer::address_of( user_1 ) ) == vector[ 0, 1, 2, 3 ] ,6);
        assert!( market::get_bet_position_ids( 0, signer::address_of( user_2 ) ) == vector[ 4, 5, 6, 7 ] ,7);

        let (_, placing_odds, bet_amount, predicted, _, _, is_open) = market::get_bet_position( 1 );
        assert!( placing_odds == 14471, 8); // at 1.44
        assert!( bet_amount == 10_00000000, 9); // 10 APT
        assert!( predicted == 2, 10); // Choice#2
        assert!( is_open == true, 11); 
        
        // Checking pool size
        let pool_size = market::get_total_vault_balance();
        assert!(pool_size == 72_43995108, 12);

        // Resolves the market and fast-forwards the system clock
        market::resolve_market( market_deployer, 1, 0, 2);

        timestamp::fast_forward_seconds(100*EPOCH_DURATION);
    
        let (total_winners, total_payout_amount) = market::check_payout_amount( 1, 0, 0, 100 );

        assert!( total_winners == 2, 13 );
        assert!( total_payout_amount == 19_67209998, 14);

        let available_for_pay = market::available_for_immediate_payout();
        assert!( available_for_pay == 52_00000000, 15 );
    
        market::payout_winners( user_2 , 1, 0, 0, 100  );
    
        // Checking final balances  
        assert!(coin::balance<AptosCoin>(signer::address_of(user_1)) == 13_02390000, 16); // Bets 10 APT and receives 13.02 APT
        assert!(coin::balance<AptosCoin>(signer::address_of(user_2)) == 4_68099000, 17);  // Bets 3 APT and receives 4.68 APT

    }

    #[test(vault_deployer = @legato_vault_addr, market_deployer = @market_addr, aptos_framework = @aptos_framework, validator_1 = @0x1111, validator_2 = @0x2222, lp_provider_1 = @0x3333, lp_provider_2 = @0x4444, user_1 = @0x5555, user_2 = @0x6666)]
    fun test_market_btc_deficit(
        vault_deployer: &signer,
        market_deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        lp_provider_1: &signer,
        lp_provider_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2);

        // Setup the system
        setup_systems(vault_deployer, market_deployer, signer::address_of(validator_1), signer::address_of(validator_2));

        // Prepare test accounts
        create_test_accounts( vault_deployer, market_deployer, lp_provider_1, lp_provider_2, user_1, user_2);

        // Add initial tokens
        add_initial_tokens(validator_1, validator_2);

        // Provide liquidity
        stake::mint(lp_provider_1, 100 * ONE_APT); 
        stake::mint(lp_provider_2, 100 * ONE_APT);

        market::provide(lp_provider_1, 100 * ONE_APT);
        market::provide(lp_provider_2, 100 * ONE_APT);

        // Place bets
        stake::mint(user_1, 10 * ONE_APT); 
        stake::mint(user_2, 10 * ONE_APT);

        market::place_bet(user_1, 1, 0, 1, 10 * ONE_APT );
        market::place_bet(user_2, 1, 0, 1, 10 * ONE_APT );
        
        market::resolve_market( market_deployer, 1, 0, 1);

        timestamp::fast_forward_seconds(100*EPOCH_DURATION);

        let (total_winners, total_payout_amount) = market::check_payout_amount( 1, 0, 0, 100 );

        assert!( total_winners == 2, 0 ); 
        assert!( total_payout_amount == 28_22799998, 1);

        let available_for_pay = market::available_for_immediate_payout();
        assert!( available_for_pay == 20_00000000, 2 ); 

        // Request unstake for 30 APT from the vault
        market::request_unstake_apt_from_legato_vault(market_deployer, 30_00000000 );
        
        // Wait for another 3 epochs to complete the redemption process 
        let i = 1;  
        while (i <= 3) {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        // Fulfill the redemption request
        vault::fulfil_request();

        available_for_pay = market::available_for_immediate_payout();

        market::payout_winners( user_2 , 1, 0, 0, 100  );

        // Checking final balances  
        assert!(coin::balance<AptosCoin>(signer::address_of(user_1)) == 12_70260000, 3); // Bets 10 APT and receives 12.70 APT
        assert!(coin::balance<AptosCoin>(signer::address_of(user_2)) == 12_70260000, 4);  // Bets 10 APT and receives 12.70 APT

    }

    #[test(vault_deployer = @legato_vault_addr, market_deployer = @market_addr, aptos_framework = @aptos_framework, validator_1 = @0x1111, validator_2 = @0x2222, lp_provider_1 = @0x3333, lp_provider_2 = @0x4444, user_1 = @0x5555, user_2 = @0x6666)]
    fun test_market_apt(
        vault_deployer: &signer,
        market_deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        lp_provider_1: &signer,
        lp_provider_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2);

        // Setup the system
        setup_systems(vault_deployer, market_deployer, signer::address_of(validator_1), signer::address_of(validator_2));

        // Prepare test accounts
        create_test_accounts( vault_deployer, market_deployer, lp_provider_1, lp_provider_2, user_1, user_2);

        // Add initial tokens
        add_initial_tokens(validator_1, validator_2);

        // Provide liquidity
        stake::mint(lp_provider_1, 100 * ONE_APT); 
        stake::mint(lp_provider_2, 100 * ONE_APT);

        market::provide(lp_provider_1, 100 * ONE_APT);
        market::provide(lp_provider_2, 100 * ONE_APT);

        // Place bets
        stake::mint(user_1, 10 * ONE_APT); 
        stake::mint(user_2, 10 * ONE_APT);

        market::place_bet(user_1, 1, 1, 1, 10 * ONE_APT );
        market::place_bet(user_2, 1, 1, 2, 10 * ONE_APT );

        market::resolve_market( market_deployer, 1, 1, 1);

        timestamp::fast_forward_seconds(100*EPOCH_DURATION);

        let (total_winners, total_payout_amount) = market::check_payout_amount( 1, 1, 0, 100 );

        assert!( total_winners == 1, 0 );
        assert!( total_payout_amount == 8_79199999, 1); 

        market::payout_winners( user_1 , 1, 1, 0, 100  );

        // Checking final balances   
        assert!(coin::balance<AptosCoin>(signer::address_of(user_1)) == 7_91280000, 3); // Bets 10 APT and receives 7.91 APT
    }

    #[test(vault_deployer = @legato_vault_addr, market_deployer = @market_addr, aptos_framework = @aptos_framework, validator_1 = @0x1111, validator_2 = @0x2222, lp_provider_1 = @0x3333, lp_provider_2 = @0x4444, user_1 = @0x5555, user_2 = @0x6666)]
    fun test_withdraw_lp(
        vault_deployer: &signer,
        market_deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        lp_provider_1: &signer,
        lp_provider_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {

        initialize_for_test(aptos_framework, validator_1, validator_2);

        // Setup the system
        setup_systems(vault_deployer, market_deployer, signer::address_of(validator_1), signer::address_of(validator_2));

        // Prepare test accounts
        create_test_accounts( vault_deployer, market_deployer, lp_provider_1, lp_provider_2, user_1, user_2);

        // Add initial tokens
        add_initial_tokens(validator_1, validator_2);

        // Provide liquidity
        stake::mint(lp_provider_1, 10 * ONE_APT); 
        stake::mint(lp_provider_2, 10 * ONE_APT);

        market::provide(lp_provider_1, 10 * ONE_APT);
        market::provide(lp_provider_2, 10 * ONE_APT);

        // Place bets on the second outcome
        stake::mint(user_1, 10 * ONE_APT); 
        stake::mint(user_2, 10 * ONE_APT);

        market::place_bet(user_1, 1, 1, 2, 10 * ONE_APT );
        market::place_bet(user_2, 1, 1, 2, 10 * ONE_APT );

        // Resolve the market by setting the winning outcome to outcome 1.
        market::resolve_market( market_deployer, 1, 1, 1);

        timestamp::fast_forward_seconds(100*EPOCH_DURATION);

        market::payout_winners( user_1 , 1, 1, 0, 100  );

        let lp_metadata = market::get_lp_metadata(); 
        let lp_share = primary_fungible_store::balance( signer::address_of(lp_provider_1), lp_metadata );

        market::request_withdraw(lp_provider_1 ,lp_share);

        let pending = market::pending_fulfil();
        let available = market::available_for_immediate_payout();

        assert!( available > pending, 0 );

        market::fulfil_request();

        // Checking final balances  
        assert!(coin::balance<AptosCoin>(signer::address_of(lp_provider_1)) == 19_74054120, 1);
    }

    #[test_only]
    public fun add_initial_tokens(user_1: &signer, user_2: &signer) {
        // Mint APT for user accounts for staking
        stake::mint(user_1, 100 * ONE_APT);
        stake::mint(user_2, 100 * ONE_APT); 

        // Mint VAULT tokens by staking APT
        vault::mint( user_1, 100 * ONE_APT);
        vault::mint( user_2, 100 * ONE_APT);

        // Fast forward 30 days to simulate staking duration
        let i:u64=1;  
        while(i <= 30) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };
    }

    #[test_only]
    public fun create_test_accounts(
        vault_deployer: &signer,
        market_deployer: &signer,
        lp_provider_1: &signer,
        lp_provider_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        account::create_account_for_test(signer::address_of(user_1));
        account::create_account_for_test(signer::address_of(user_2)); 
        account::create_account_for_test(signer::address_of(lp_provider_1));
        account::create_account_for_test(signer::address_of(lp_provider_2)); 
        account::create_account_for_test(signer::address_of(vault_deployer)); 
        account::create_account_for_test(signer::address_of(market_deployer)); 

        account::create_account_for_test( vault::get_config_object_address() ); 
        account::create_account_for_test( market::get_config_object_address() );

        coin::register<AptosCoin>(vault_deployer);
        coin::register<AptosCoin>(market_deployer);
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
    public fun setup_systems(vault_deployer: &signer , market_deployer: &signer, validator_1: address, validator_2: address) {
        
        vault::init_module_for_testing(vault_deployer);

        // Add the validators to the whitelist.
        vault::attach_pool(vault_deployer, validator_1);
        vault::attach_pool(vault_deployer, validator_2);

        market::init_module_for_testing(market_deployer);

        // Setup BTC market
        market::add_market(
            market_deployer,
            1,
            0,
            1500,
            3500,
            3500,
            1500,
            timestamp::now_seconds()+(100*EPOCH_DURATION)
        );

        // Setup APT market
        market::add_market(
            market_deployer,
            1,
            1,
            5000,
            5000,
            0,
            0,
            timestamp::now_seconds()+(100*EPOCH_DURATION)
        );

        market::update_commission_fee(market_deployer, 1000);
        


    }

    #[test_only]
    public fun mint_and_add_stake(account: &signer, amount: u64) {
        stake::mint(account, amount);
        dp::add_stake(account, dp::get_owned_pool_address(signer::address_of(account)), amount);
    }
}