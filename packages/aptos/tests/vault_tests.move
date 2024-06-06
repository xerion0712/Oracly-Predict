 
#[test_only]
module legato_addr::vault_tests {

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
 
    use legato_addr::vault;
    use legato_addr::vault_token_name::{MAR_2024, JUN_2024};
    
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

    #[test(deployer = @legato_addr,aptos_framework = @aptos_framework, validator_1 = @0xdead, validator_2 = @0x1111, user_1 = @0xbeef, user_2 = @0xfeed)]
    fun test_mint_redeem(
        deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2);
        
        // Setup Legato vaults
        setup_vaults(deployer, signer::address_of(validator_1), signer::address_of(validator_2));

        // Prepare test accounts
        create_test_accounts( deployer, user_1, user_2);

        // Mint APT tokens
        stake::mint(user_1, 100 * ONE_APT);
        stake::mint(user_2, 200 * ONE_APT); 

        assert!(coin::balance<AptosCoin>(signer::address_of(user_1)) == 100 * ONE_APT, 0);
        assert!(coin::balance<AptosCoin>(signer::address_of(user_2)) == 200 * ONE_APT, 1);
    
        // Stake PT tokens.
        vault::mint<MAR_2024>( user_1, 100 * ONE_APT);
        vault::mint<MAR_2024>( user_2, 200 * ONE_APT);

        // Check PT token balances.
        let pt_amount_1 = vault::get_pt_balance<MAR_2024>(signer::address_of(user_1));
        let pt_amount_2 = vault::get_pt_balance<MAR_2024>(signer::address_of(user_2));
        assert!( pt_amount_1 == 101_37836771, 2); // 101.378 PT
        assert!( pt_amount_2 == 202_75673543, 3); // 202.756 PT

        // Fast forward 100 epochs.
        let i:u64=1;  
        while(i <= 100) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        // Check the staked amount.
        let pool_address = dp::get_owned_pool_address(signer::address_of(validator_1) );
        let (pool_staked_amount,_,_) = dp::get_stake(pool_address , vault::get_config_object_address() );

        assert!( pool_staked_amount == 331_20350570, 4); // 331.203 APT 

        // Request redemption of PT tokens.
        vault::request_redeem<MAR_2024>( user_1, 101_37836771 ); 

        // Perform admin tasks.
        vault::admin_proceed_unstake(deployer, signer::address_of(validator_1)  );
        
        // Fast forward one epoch.
        timestamp::fast_forward_seconds(EPOCH_DURATION);
        end_epoch();

        vault::admin_proceed_withdrawal( deployer , signer::address_of(validator_1));

        // Verify has the correct amount of APT tokens after redemption.
        let apt_amount = coin::balance<AptosCoin>(signer::address_of(user_1)); 
        assert!( apt_amount == 101_37836770, 5);
    }

    #[test(deployer = @legato_addr,aptos_framework = @aptos_framework, validator_1 = @0xdead, validator_2 = @0x1111, user_1 = @0xbeef, user_2 = @0xfeed)]
    fun test_mint_exit(
        deployer: &signer,
        aptos_framework: &signer,
        validator_1: &signer, 
        validator_2: &signer,
        user_1: &signer,
        user_2: &signer
    ) {
        initialize_for_test(aptos_framework, validator_1, validator_2); 

        // Setup Legato vaults
        setup_vaults(deployer, signer::address_of(validator_1), signer::address_of(validator_2));

        // Prepare test accounts
        create_test_accounts( deployer, user_1, user_2);

        // Stake PT tokens.
        stake::mint(user_1, 100 * ONE_APT);
        stake::mint(user_2, 200 * ONE_APT); 

        vault::mint<MAR_2024>( user_1, 100 * ONE_APT);
        vault::mint<MAR_2024>( user_2, 200 * ONE_APT);

        // Fast forward 10 epochs.
        let i:u64=1;  
        while(i <= 10) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        let amount_before = vault::get_pt_balance<MAR_2024>(signer::address_of(user_1));
        assert!( amount_before == 101_37836771, 0); // 101.378 PT
        
        // Request exit
        vault::request_exit<MAR_2024>( user_1, amount_before ); 

        // Perform admin tasks.
        vault::admin_proceed_unstake(deployer, signer::address_of(validator_1)  );
        
        // Fast forward one epoch.
        timestamp::fast_forward_seconds(EPOCH_DURATION);
        end_epoch();

        vault::admin_proceed_withdrawal( deployer , signer::address_of(validator_1));

        let apt_amount = coin::balance<AptosCoin>(signer::address_of(user_1)); 
        assert!( apt_amount == 100_13708438, 0); // 100.137 PT
        
    }

    #[test_only]
    public fun setup_vaults(sender: &signer, validator_1: address, validator_2: address) {

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

    // Convenient function for setting up all required stake initializations.
    #[test_only]
    public fun initialize_for_test_custom(
        aptos_framework: &signer,
        minimum_stake: u64,
        maximum_stake: u64,
        recurring_lockup_secs: u64,
        allow_validator_set_change: bool,
        rewards_rate_numerator: u64,
        rewards_rate_denominator: u64,
        voting_power_increase_limit: u64,
    ) {
        account::create_account_for_test(signer::address_of(aptos_framework));
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
        reconfiguration::initialize_for_test(aptos_framework);
        // features::change_feature_flags(aptos_framework, vector[DELEGATION_POOLS, MODULE_EVENT], vector[]);
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
    public fun mint_and_add_stake(account: &signer, amount: u64) {
        stake::mint(account, amount);
        dp::add_stake(account, dp::get_owned_pool_address(signer::address_of(account)), amount);
    }

}