
// #[test_only]
// module legato_addr::delegation_pool_tests {

//     use std::features;
//     use std::signer;

//     use aptos_std::bls12381;
//     use aptos_framework::stake;
//     use aptos_std::vector;

//     use aptos_framework::account;
//     use aptos_framework::aptos_coin::AptosCoin;
//     use aptos_framework::coin;
//     use aptos_framework::reconfiguration;
//     use aptos_framework::delegation_pool as dp;
//     use aptos_framework::timestamp;

//     #[test_only]
//     const EPOCH_DURATION: u64 = 60;

//     #[test_only]
//     const LOCKUP_CYCLE_SECONDS: u64 = 3600;

//     #[test_only]
//     const MODULE_EVENT: u64 = 26;

//     #[test_only]
//     const DELEGATION_POOLS: u64 = 11;

//     #[test_only]
//     const OPERATOR_BENEFICIARY_CHANGE: u64 = 39;

//     #[test_only]
//     const COMMISSION_CHANGE_DELEGATION_POOL: u64 = 42;
    
//     #[test_only]
//     const COIN_TO_FUNGIBLE_ASSET_MIGRATION: u64 = 60;

//     #[test_only]
//     const ONE_APT: u64 = 100000000; // 1x10**8

//     #[test_only]
//     const VALIDATOR_STATUS_PENDING_ACTIVE: u64 = 1;
//     const VALIDATOR_STATUS_ACTIVE: u64 = 2;
//     const VALIDATOR_STATUS_PENDING_INACTIVE: u64 = 3;
//     const VALIDATOR_STATUS_INACTIVE: u64 = 4;

//     #[test(aptos_framework = @aptos_framework, validator = @0x123)]
//     public entry fun test_validator_staking(
//         aptos_framework: &signer,
//         validator: &signer,
//     ) {
//         initialize_for_test(aptos_framework);
//         let (_sk, pk, pop) = generate_identity();
//         initialize_test_validator(&pk, &pop, validator, 100 * ONE_APT, true, true);

//         // Validator has a lockup now that they've joined the validator set.
//         let validator_address = signer::address_of(validator);
//         let pool_address = dp::get_owned_pool_address(validator_address);
//         assert!(stake::get_remaining_lockup_secs(pool_address) == LOCKUP_CYCLE_SECONDS, 1);

//         // Validator adds more stake while already being active.
//         // The added stake should go to pending_active to wait for activation when next epoch starts.
//         stake::mint(validator, 900 * ONE_APT);
//         dp::add_stake(validator, pool_address, 100 * ONE_APT);
//         assert!(coin::balance<AptosCoin>(validator_address) == 800 * ONE_APT, 2);
//         stake::assert_validator_state(pool_address, 100 * ONE_APT, 0, 100 * ONE_APT, 0, 0);

//         // Pending_active stake is activated in the new epoch.
//         // Rewards of 1 coin are also distributed for the existing active stake of 100 coins.
//         end_epoch();
//         assert!(stake::get_validator_state(pool_address) == VALIDATOR_STATUS_ACTIVE, 3);
//         stake::assert_validator_state(pool_address, 201 * ONE_APT, 0, 0, 0, 0);

//         // Request unlock of 100 coins. These 100 coins are moved to pending_inactive and will be unlocked when the
//         // current lockup expires.
//         dp::unlock(validator, pool_address, 100 * ONE_APT);
//         stake::assert_validator_state(pool_address, 10100000001, 0, 0, 9999999999, 0);

//         // Enough time has passed so the current lockup cycle should have ended.
//         // The first epoch after the lockup cycle ended should automatically move unlocked (pending_inactive) stake
//         // to inactive.
//         timestamp::fast_forward_seconds(LOCKUP_CYCLE_SECONDS);
//         end_epoch();
//         // Rewards were also minted to pending_inactive, which got all moved to inactive.
//         stake::assert_validator_state(pool_address, 10201000001, 10099999998, 0, 0, 0);
//         // Lockup is renewed and validator is still active.
//         assert!(stake::get_validator_state(pool_address) == VALIDATOR_STATUS_ACTIVE, 4);
//         assert!(stake::get_remaining_lockup_secs(pool_address) == LOCKUP_CYCLE_SECONDS, 5);

//         // Validator withdraws from inactive stake multiple times.
//         dp::withdraw(validator, pool_address, 50 * ONE_APT);
//         assert!(coin::balance<AptosCoin>(validator_address) == 84999999999, 6);
//         stake::assert_validator_state(pool_address, 10201000001, 5099999999, 0, 0, 0);
//         dp::withdraw(validator, pool_address, 51 * ONE_APT);
//         assert!(coin::balance<AptosCoin>(validator_address) == 90099999998, 7);
//         stake::assert_validator_state(pool_address, 10201000001, 0, 0, 0, 0);

//         // Enough time has passed again and the validator's lockup is renewed once more. Validator is still active.
//         timestamp::fast_forward_seconds(LOCKUP_CYCLE_SECONDS);
//         end_epoch();

//         assert!(stake::get_validator_state(pool_address) == VALIDATOR_STATUS_ACTIVE, 8);
//         assert!(stake::get_remaining_lockup_secs(pool_address) == LOCKUP_CYCLE_SECONDS, 9);
//     }

//     #[test_only]
//     public fun initialize_for_test(aptos_framework: &signer) {
//         initialize_for_test_custom(
//             aptos_framework,
//             100 * ONE_APT,
//             10000 * ONE_APT,
//             LOCKUP_CYCLE_SECONDS,
//             true,
//             1,
//             100,
//             1000000
//         );
//     }

//     #[test_only]
//     public fun end_epoch() {
//         stake::end_epoch();
//         reconfiguration::reconfigure_for_test_custom();
//     }

//     // Convenient function for setting up all required stake initializations.
//     #[test_only]
//     public fun initialize_for_test_custom(
//         aptos_framework: &signer,
//         minimum_stake: u64,
//         maximum_stake: u64,
//         recurring_lockup_secs: u64,
//         allow_validator_set_change: bool,
//         rewards_rate_numerator: u64,
//         rewards_rate_denominator: u64,
//         voting_power_increase_limit: u64,
//     ) {
//         account::create_account_for_test(signer::address_of(aptos_framework));

//         features::change_feature_flags_for_testing(aptos_framework, vector[
//             COIN_TO_FUNGIBLE_ASSET_MIGRATION,
//             DELEGATION_POOLS,
//             MODULE_EVENT,
//             OPERATOR_BENEFICIARY_CHANGE,
//             COMMISSION_CHANGE_DELEGATION_POOL
//         ], vector[ ]);

//         reconfiguration::initialize_for_test(aptos_framework); 
//         stake::initialize_for_test_custom(
//             aptos_framework,
//             minimum_stake,
//             maximum_stake,
//             recurring_lockup_secs,
//             allow_validator_set_change,
//             rewards_rate_numerator,
//             rewards_rate_denominator,
//             voting_power_increase_limit
//         );
        
//     }

//     #[test_only]
//     public fun generate_identity(): (bls12381::SecretKey, bls12381::PublicKey, bls12381::ProofOfPossession) {
//         let (sk, pkpop) = bls12381::generate_keys();
//         let pop = bls12381::generate_proof_of_possession(&sk);
//         let unvalidated_pk = bls12381::public_key_with_pop_to_normal(&pkpop);
//         (sk, unvalidated_pk, pop)
//     }

//     #[test_only]
//     public fun initialize_test_validator(
//         public_key: &bls12381::PublicKey,
//         proof_of_possession: &bls12381::ProofOfPossession,
//         validator: &signer,
//         amount: u64,
//         should_join_validator_set: bool,
//         should_end_epoch: bool
//     ) {
//         let validator_address = signer::address_of(validator);
//         if (!account::exists_at(signer::address_of(validator))) {
//             account::create_account_for_test(validator_address);
//         };

//         dp::initialize_delegation_pool(validator, 0, vector::empty<u8>());
//         validator_address = dp::get_owned_pool_address(validator_address);

//         let pk_bytes = bls12381::public_key_to_bytes(public_key);
//         let pop_bytes = bls12381::proof_of_possession_to_bytes(proof_of_possession);
//         stake::rotate_consensus_key(validator, validator_address, pk_bytes, pop_bytes);

//         if (amount > 0) {
//             mint_and_add_stake(validator, amount);
//         };

//         if (should_join_validator_set) {
//             stake::join_validator_set(validator, validator_address);
//         };
//         if (should_end_epoch) {
//             end_epoch();
//         };
//     }

//     #[test_only]
//     public fun mint_and_add_stake(account: &signer, amount: u64) {
//         stake::mint(account, amount);
//         dp::add_stake(account, dp::get_owned_pool_address(signer::address_of(account)), amount);
//     }

// }