// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// New Legato's Vault allows liquid staking on a supported random validator
// and removes the complexity of a quarterly expiration schedule,
// making its behavior similar to other liquid staking protocols.

module legato_vault_addr::vault {

    use std::signer;  
    use std::string::{ String, utf8};
    use std::option::{  Self, Option};
    use std::vector;

    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object, ExtendRef, ConstructorRef};
    use aptos_framework::fungible_asset::{ Self, FungibleStore, Metadata, MintRef, BurnRef, TransferRef };
    use aptos_framework::primary_fungible_store::{Self};
    use aptos_framework::delegation_pool as dp;
    use aptos_framework::coin::{Self}; 
  
    use aptos_std::fixed_point64::{Self, FixedPoint64}; 

    // ======== Constants ========

    const MIN_AMOUNT: u64 = 1_00000000; // 1 APT
    const BATCH_AMOUNT: u64 = 1200000000; // 12 APT 
    const UNSTAKE_DELAY: u64 = 259200; // Default delay for unstaking, set to 3 days
    // Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000; 

    // ======== Errors ========

    const ERR_UNAUTHORIZED: u64 = 1;
    const ERR_MIN_THRESHOLD: u64 = 2;
    const ERR_INVALID_VALUE: u64 = 3;
    const ERR_UNAUTHORIZED_POOL: u64 = 4;
    const ERR_INVALID_ADDRESS: u64 = 5;
    const ERR_ZERO_VALUE: u64 = 6;
    const ERR_DISABLED: u64 = 7;
    const ERR_DEPOSIT_CAP: u64 = 8;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 9;
    const ERR_INSUFFICIENT_AMOUNT: u64 = 10;
    const ERR_NONE_POOL_WITHDRAWN: u64 = 11;
    const ERR_TOO_LARGE: u64 = 12;
    const ERR_EMPTY_LIST: u64 = 13;

    
    // ======== Structs =========


    // Represents a prioritized delegator pool with a specific quota
    struct Priority has store, drop {
        delegator_pool: address, // Address of the staking pool
        quota_amount: u64 // Quota amount allocated for staking in this pool
    }

    // Represents a request to unstake APT from the vault
    struct Request has store, drop {
        sender: address, // Address of the user making the request
        amount: u64, // APT amount to be sent out when available 
        timestamp: u64 // Timestamp at which the request was made
    }

    // Stores the metadata and references required for managing vault liquidity
    struct VaultReserve has store {
        lp_metadata: Object<Metadata>,
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
        min_liquidity: Object<FungibleStore>
    }

    // Configuration settings for the vault
    struct VaultConfig has store {
        delegator_pools: vector<address>, // List of supported staking pools
        priority_list: vector<Priority>, // List of prioritized delegator pools and quotas to be staked
        deposit_cap: Option<u64>, // Optional cap on the total deposits allowed in the vault
        min_amount: u64, // Minimum amount required to stake/unstake
        unstake_delay: u64, // Delay period for unstaking, specified in epochs
        batch_amount: u64, // Amount required to trigger a batch processing
        enable_mint: bool, 
        enable_redeem: bool,
        enable_auto_stake: bool // Stake APT from the pool when batch amount is reached
    } 

    // Global state
    struct VaultGlobal has key {
        config: VaultConfig,
        reserve: VaultReserve,
        extend_ref: ExtendRef,
        pending_stake: u64,
        pending_withdrawal: u64,
        pending_fulfil: u64,
        request_list: vector<Request>,
        current_balance_with_rewards: u64, // Need to call update_amounts() on a regular basis to update it
        total_lp_amount: u64 // Same to above
    }

    #[event]
    struct MintEvent has drop, store {
        input_amount: u64,
        vault_share: u64,
        sender: address,
        timestamp: u64
    }

    #[event]
    struct RequestRedeem has drop, store {
        vault_amount: u64,
        withdraw_amount: u64,
        sender: address,
        timestamp: u64
    }

    #[event]
    struct Redeem has drop, store { 
        withdraw_amount: u64,
        sender: address,
        timestamp: u64
    }

    // Constructor
    fun init_module(sender: &signer) {

        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        
        let config_object_signer = object::generate_signer_for_extending(&extend_ref);

        // Initialize vault's token 
        let vault_token_ref = &object::create_named_object(&config_object_signer,  b"VAULT");

        lp_initialize(
            vault_token_ref,
            0, /* maximum_supply. 0 means no maximum */
            utf8(b"Legato Vault Token"), /* name */
            utf8(b"VAULT"), /* symbol */
            8, /* decimals */
            utf8(b"https://img.tamago.finance/legato-logo-icon.png"), /* icon */
            utf8(b"https://legato.finance"), /* project */
        );

        let lp_metadata = object::object_from_constructor_ref<Metadata>(vault_token_ref);

        move_to(sender, VaultGlobal {
            config: VaultConfig {
                delegator_pools: vector::empty(),
                priority_list: vector::empty(),
                deposit_cap: option::none<u64>(),
                min_amount: MIN_AMOUNT,
                unstake_delay: UNSTAKE_DELAY,
                batch_amount: BATCH_AMOUNT,
                enable_mint: true,
                enable_redeem: true,
                enable_auto_stake: true
            },
            reserve: VaultReserve {
                lp_metadata,
                mint_ref: fungible_asset::generate_mint_ref(vault_token_ref),
                burn_ref: fungible_asset::generate_burn_ref(vault_token_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(vault_token_ref),
                min_liquidity: create_token_store(&config_object_signer, lp_metadata)
            },
            extend_ref,
            pending_stake: 0,
            pending_withdrawal: 0,
            pending_fulfil: 0,
            request_list: vector::empty<Request>(),
            current_balance_with_rewards: 0,
            total_lp_amount: 0
        });

    }

    // ======== Entry Functions =========

    // Stake APT to receive liquid VAULT tokens and earn staking rewards 
    // with a minimum stake of 1 APT instead of 11 APT
    public entry fun mint(sender: &signer, input_amount: u64) acquires VaultGlobal {
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr); 
        assert!(global.config.enable_mint == true, ERR_DISABLED);
        assert!(coin::balance<AptosCoin>(signer::address_of(sender)) >= global.config.min_amount, ERR_MIN_THRESHOLD);

        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        // Transfer APT to the object.
        let input_coin = coin::withdraw<AptosCoin>(sender, input_amount);
        if (!coin::is_account_registered<AptosCoin>(signer::address_of(&config_object_signer))) {
            coin::register<AptosCoin>(&config_object_signer);
        };
        
        coin::deposit(signer::address_of(&config_object_signer), input_coin);

        // Update the pending stake amount
        global.pending_stake = global.pending_stake+input_amount;

        // Apply deposit cap if defined
        if (option::is_some(&global.config.deposit_cap)) {
            assert!( *option::borrow(&global.config.deposit_cap) >= input_amount, ERR_DEPOSIT_CAP);
            *option::borrow_mut(&mut global.config.deposit_cap) = *option::borrow(&global.config.deposit_cap)-input_amount;
        };

        let lp_supply = option::destroy_some(fungible_asset::supply(global.reserve.lp_metadata));
        let current_balance = current_balance_with_rewards(signer::address_of(&config_object_signer) , global.config.delegator_pools );

        // Calculate the amount of LP tokens to mint
        let lp_amount_to_mint = if (lp_supply == 0) {
            // Check if initial liquidity is sufficient.
            assert!(input_amount > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

            let min_lp_tokens = fungible_asset::mint(&global.reserve.mint_ref, MINIMAL_LIQUIDITY);
            fungible_asset::deposit(global.reserve.min_liquidity, min_lp_tokens);

            input_amount - MINIMAL_LIQUIDITY
        } else { 
            let ratio = fixed_point64::create_from_rational((input_amount as u128) , (current_balance as u128));
            let total_share = fixed_point64::multiply_u128( (lp_supply as u128) , ratio);
            (total_share as u64)
        };

        // Mint VAULT tokens and deposit them into the sender's account 
        let lp_tokens = fungible_asset::mint(&global.reserve.mint_ref, lp_amount_to_mint);

        primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), global.reserve.lp_metadata );
        let lp_store = primary_fungible_store::primary_store(signer::address_of(sender), global.reserve.lp_metadata );
        fungible_asset::deposit(lp_store, lp_tokens);
        
        if (global.config.enable_auto_stake == true) {
            transfer_stake();
        };

        // Update amounts
        update_amounts();

        event::emit(
            MintEvent {
                vault_share: lp_amount_to_mint,
                input_amount, 
                sender: signer::address_of(sender),
                timestamp: timestamp::now_seconds()
            }
        )
    }

    // Allows a user to request the redemption of their staked assets
    public entry fun request_redeem(sender: &signer, lp_amount: u64) acquires VaultGlobal {
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr); 
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        assert!(global.config.enable_redeem == true, ERR_DISABLED);
        assert!( primary_fungible_store::balance( signer::address_of(sender) , global.reserve.lp_metadata ) >= lp_amount , ERR_INSUFFICIENT_AMOUNT );

        let lp_supply = option::destroy_some(fungible_asset::supply(global.reserve.lp_metadata));
        let current_balance = current_balance_with_rewards(signer::address_of(&config_object_signer) , global.config.delegator_pools );

        // Calculate the withdrawal amount from the given vault token 
        let multiplier = fixed_point64::create_from_rational( (current_balance as u128), ( lp_supply as u128));
        let withdrawal_amount = (fixed_point64::multiply_u128( (lp_amount as u128), multiplier) as u64);

        // Initiate withdrawal by unlocking staked assets from 
        // one or more delegator pools to cover the withdrawal amount
        prepare_withdrawal( &config_object_signer, &global.config, withdrawal_amount );

        global.pending_fulfil = global.pending_fulfil+withdrawal_amount;

        vector::push_back( &mut global.request_list, Request {
            sender: signer::address_of(sender), 
            amount: withdrawal_amount,
            timestamp: timestamp::now_seconds()
        });

        // Burn vault tokens on the sender's account 
        let lp_store = ensure_lp_token_store( &global.reserve, signer::address_of(sender));
        fungible_asset::burn_from(&global.reserve.burn_ref, lp_store, lp_amount);

        // Update amounts
        update_amounts();
 
        // Emit an event 
        event::emit(
            RequestRedeem {
                vault_amount: lp_amount,
                withdraw_amount: withdrawal_amount, 
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    }

    // Fulfil unstaking requests for everyone in the list
    public entry fun fulfil_request() acquires VaultGlobal {
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr); 
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        assert!( vector::length(&global.request_list) > 0, ERR_EMPTY_LIST );

        let count = 0;
        let withdraw_ids = vector::empty<u64>();

        let total_amount_to_withdraw = 0;

        // Identify requests eligible for fulfilment
        while ( count < vector::length(&global.request_list)) {  
            let this_request = vector::borrow( &global.request_list, count);
            if ( timestamp::now_seconds() >= this_request.timestamp+global.config.unstake_delay ) {
                vector::push_back( &mut withdraw_ids, count );
                total_amount_to_withdraw = total_amount_to_withdraw+this_request.amount;
            };
            count = count+1;
        };

        withdraw_inactive_stake( &config_object_signer, &global.config, total_amount_to_withdraw);

        global.pending_fulfil = if (global.pending_fulfil > total_amount_to_withdraw) {
            global.pending_fulfil-total_amount_to_withdraw
        } else {
            0
        };

        // Fulfil each eligible request
        while (vector::length(&withdraw_ids) > 0) {
            let request_id = vector::pop_back(&mut withdraw_ids);
            let this_request = vector::swap_remove(&mut global.request_list, request_id);
            let current_balance = coin::balance<AptosCoin>(signer::address_of(&config_object_signer));

            let withdraw_amount = if (current_balance >= this_request.amount) {
                this_request.amount
            } else {
                current_balance
            };

            let apt_coin = coin::withdraw<AptosCoin>(&config_object_signer, withdraw_amount);
            coin::deposit(this_request.sender, apt_coin);
        
            // Emit an event
            event::emit(
                Redeem { 
                    withdraw_amount, 
                    timestamp: timestamp::now_seconds(),  
                    sender: this_request.sender
                }
            )

        };
    
    }


    public entry fun update_amounts() acquires VaultGlobal {
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr); 
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        global.current_balance_with_rewards = current_balance_with_rewards(signer::address_of(&config_object_signer) , global.config.delegator_pools );
        global.total_lp_amount = (option::destroy_some(fungible_asset::supply(global.reserve.lp_metadata)) as u64);
        global.pending_withdrawal = current_unlocked_balance(signer::address_of(&config_object_signer) , &global.config.delegator_pools);
    }

    // Check if the APT in pending_stake meets the BATCH_AMOUNT, then use it to stake on a randomly supported validator.
    public entry fun transfer_stake() acquires VaultGlobal {
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);

        if (global.pending_stake >= global.config.batch_amount) { 
            
            let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
            let validator_address = next_validator(  &mut global.config , global.pending_stake );
            let pool_address = dp::get_owned_pool_address(validator_address);
            dp::add_stake(&config_object_signer, pool_address, global.pending_stake);

            global.pending_stake = 0;
        };
    }
    
    // ======== Public Functions =========

    #[view]    
    public fun get_config_object_address(): address acquires VaultGlobal {
        let global = borrow_global<VaultGlobal>(@legato_vault_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        signer::address_of(&config_object_signer)
    }
    
    // Return the address of vault's token metadata
    #[view]
    public fun get_vault_metadata(): Object<Metadata> acquires VaultGlobal {
        let global = borrow_global<VaultGlobal>(@legato_vault_addr); 
        global.reserve.lp_metadata
    }

    #[view] 
    public fun get_amounts(): (u64, u64) acquires VaultGlobal {
        let global = borrow_global<VaultGlobal>(@legato_vault_addr);
        ( global.current_balance_with_rewards, global.total_lp_amount )
    }

    // ======== Only Governance =========

    // Enable/Disable auto stake
    public entry fun enable_auto_stake(sender: &signer, is_enable: bool) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        global.config.enable_auto_stake = is_enable;
    }

    // Enable/Disable minting vault tokens
    public entry fun enable_mint(sender: &signer, is_enable: bool) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        global.config.enable_mint = is_enable;
    }

    // Enable/Disable redeeming vault tokens
    public entry fun enable_redeem(sender: &signer, is_enable: bool) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        global.config.enable_redeem = is_enable;
    } 

    // Update the batch amount for staking.
    public entry fun update_batch_amount(sender: &signer, new_amount: u64) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        global.config.batch_amount = new_amount;
    }

    // To set the deposit cap. Put amount as zero to ignore
    public entry fun set_deposit_cap(sender: &signer, amount: u64) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        // Check if the amount is zero
        if (amount == 0)
            // Set deposit cap to none
            global.config.deposit_cap = option::none<u64>()
        // Set deposit cap to the specified amount
        else global.config.deposit_cap = option::some<u64>(amount);
    }

    // Updates the delay period for unstaking in the vault
    public entry fun update_unstake_delay(sender: &signer, new_value: u64) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr , ERR_UNAUTHORIZED);
        assert!( 30 >= new_value, ERR_INVALID_VALUE );
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        global.config.unstake_delay = new_value;
    }


    // Updates the minimum amount required to stake and unstake 
    public entry fun update_min_amount(sender: &signer, new_value: u64 )  acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr , ERR_UNAUTHORIZED);
        assert!( new_value > 0, ERR_ZERO_VALUE );
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        global.config.min_amount = new_value;
    }

    // Add a validator to the whitelist.
    public entry fun attach_pool(sender: &signer, whitelist_address: address) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        vector::push_back(&mut global.config.delegator_pools, whitelist_address);
    }

    // Remove a validator from the whitelist.
    public entry fun detach_pool(sender: &signer, whitelist_address: address) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        let (found, idx) = vector::index_of<address>(&global.config.delegator_pools, &whitelist_address);
        assert!(  found , ERR_INVALID_ADDRESS);
        vector::swap_remove<address>(&mut global.config.delegator_pools, idx );
    }

    // Adds a new prioritized staking pool
    public entry fun add_priority(sender: &signer, pool_address: address, quota_amount: u64) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        // Ensure that the pool address is in the list
        assert!(vector::contains(&global.config.delegator_pools, &pool_address), ERR_UNAUTHORIZED_POOL);
        assert!( quota_amount >= MIN_AMOUNT, ERR_MIN_THRESHOLD );

        vector::push_back( 
            &mut global.config.priority_list,
            Priority {
                delegator_pool: pool_address,
                quota_amount
            }
        );
    }

    // Removes a prioritized staking pool
    public entry fun remove_priority(sender: &signer, priority_id: u64) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        
        assert!( vector::length( &global.config.priority_list ) > priority_id, ERR_INVALID_VALUE );
        vector::swap_remove( &mut global.config.priority_list, priority_id );
    }

    // Manually stake assets to a specific pool
    public entry fun admin_proceed_stake(sender: &signer, input_amount: u64, validator_address: address) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref); 
        let pool_address = dp::get_owned_pool_address(validator_address);
        dp::add_stake(&config_object_signer, pool_address, input_amount);
    }

    // Manually unlock staked assets from a specific pool
    public entry fun admin_proceed_unlock(sender: &signer, unlock_amount: u64, validator_address: address) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref); 
        let pool_address = dp::get_owned_pool_address(validator_address);
        let (active,_,_) = dp::get_stake( pool_address, signer::address_of( &config_object_signer ) );
        assert!( active >= unlock_amount, ERR_INSUFFICIENT_AMOUNT);
        dp::unlock(&config_object_signer, pool_address, unlock_amount);
    }

    // Manually deposit pending stakes
    public entry fun admin_deposit_pending_stake(sender: &signer, input_amount: u64) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref); 
        
        // Transfer APT to the object.
        let input_coin = coin::withdraw<AptosCoin>(sender, input_amount);
        if (!coin::is_account_registered<AptosCoin>(signer::address_of(&config_object_signer))) {
            coin::register<AptosCoin>(&config_object_signer);
        };
        
        coin::deposit(signer::address_of(&config_object_signer), input_coin);

        // Update the pending stake amount
        global.pending_stake = global.pending_stake+input_amount;
    }

    // Manually withdraw pending stakes
    public entry fun admin_withdraw_pending_stake(sender: &signer, withdraw_amount: u64,  is_update: bool) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref); 
        let apt_coin = coin::withdraw<AptosCoin>(&config_object_signer, withdraw_amount);
        coin::deposit( @legato_vault_addr , apt_coin);

        if (is_update) {
            global.pending_stake = global.pending_stake-withdraw_amount;
        };

    }

    // Manually withdraw pending fulfil
    public entry fun admin_withdraw_pending_fulfil(sender: &signer, withdraw_amount: u64, validator_address: address, is_update: bool) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED);
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref); 
        let pool_address = dp::get_owned_pool_address(validator_address);

        dp::withdraw(&config_object_signer, pool_address, withdraw_amount);
        
        if (is_update) {
            global.pending_stake = global.pending_stake-withdraw_amount;
        };

    }

    // Manually remove a user's withdrawal request
    public entry fun admin_remove_request(sender: &signer, request_id: u64) acquires VaultGlobal {
        assert!( signer::address_of(sender) == @legato_vault_addr, ERR_UNAUTHORIZED); 
        let global = borrow_global_mut<VaultGlobal>(@legato_vault_addr);
        assert!( vector::length( &global.request_list ) > request_id, ERR_INVALID_VALUE);
        vector::swap_remove(&mut global.request_list, request_id);
    }
    
    // ======== Internal Functions =========

    inline fun create_token_store(vault_signer: &signer, token: Object<Metadata>): Object<FungibleStore> {
        let constructor_ref = &object::create_object_from_object(vault_signer);
        fungible_asset::create_store(constructor_ref, token)
    }

    // Determines the next validator to stake to based on priority list or randomly if no priorities 
    fun next_validator(config: &mut VaultConfig, stake_amount: u64) : address {
        // Check if there are any entries in the priority list
        if (vector::length( &config.priority_list ) > 0 ) {
            let first_entry = vector::borrow_mut( &mut config.priority_list, 0);
            let staking_pool_address = first_entry.delegator_pool;
            let new_amount = if ( first_entry.quota_amount > stake_amount) {
                first_entry.quota_amount - stake_amount
            } else {
                0
            };

            first_entry.quota_amount = new_amount;

            if (new_amount == 0) {
                vector::swap_remove( &mut config.priority_list, 0);
            };

            // Return the address of the staking pool from the priority list
            staking_pool_address
        } else { 
            // If no priority list entries, select a random validator address
            random_validator_address( &config.delegator_pools )
        }
    }

    fun random_validator_address(delegator_pools: &vector<address>) : address {
        let validator_index = timestamp::now_seconds() % vector::length( delegator_pools );
        *vector::borrow( delegator_pools, validator_index )
    }

    fun current_balance_with_rewards(vault_address: address, pool_list: vector<address>): u64 {
         
        let count = 0;
        let total_amount = 0;

        while ( count < vector::length(&pool_list) ) { 
            let validator_address = *vector::borrow( &pool_list, count ); 
            let pool_address = dp::get_owned_pool_address(validator_address);  
            let (active, _, pending) = dp::get_stake( pool_address, vault_address);
            total_amount = total_amount+active+pending;
            count = count+1;
        };

        total_amount
    }

    fun current_unlocked_balance(vault_address: address, pool_list: &vector<address>): u64 {
        
        let count = 0;
        let total_amount = 0;

        while ( count < vector::length(pool_list) ) {
            let validator_address = *vector::borrow( pool_list, count );
            let pool_address = dp::get_owned_pool_address(validator_address); 
            let (_, inactive, _) = dp::get_stake( pool_address, vault_address);
            total_amount = total_amount+inactive;
            count = count+1;
        };

        total_amount
    }

    fun ensure_lp_token_store(reserve: &VaultReserve, recipient: address ): Object<FungibleStore> {
        primary_fungible_store::ensure_primary_store_exists(recipient,  reserve.lp_metadata);
        let store = primary_fungible_store::primary_store(recipient,  reserve.lp_metadata);
        store
    }

    fun lp_initialize(
        constructor_ref: &ConstructorRef,
        maximum_supply: u128,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String
    ) {
        let supply = if (maximum_supply != 0) {
            option::some(maximum_supply)
        } else {
            option::none()
        };
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            supply,
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri,
        );
    }

    fun prepare_withdrawal(pool_signer: &signer, config: &VaultConfig, withdraw_amount: u64) {

        let unlocked_amount = current_unlocked_balance( signer::address_of(pool_signer), &config.delegator_pools );

        // Ignore if there is a sufficient amount of APT staked in an inactive state
        if (withdraw_amount > unlocked_amount) {

            let remaining_amount = withdraw_amount-unlocked_amount;

            // Look for unlocking staked assets from a single pool first
            let pool_address = find_one_with_minimal_excess(pool_signer, config, remaining_amount);

            if (option::is_none<address>(&pool_address)) { 
                // If no single pool fits, then look for unlocking from multiple pools.
                let pool_ids = find_combination(pool_signer, config, remaining_amount);
                assert!( vector::length( &pool_ids ) > 0 , ERR_NONE_POOL_WITHDRAWN  );
                unlock_stake( pool_signer, pool_ids, remaining_amount );
            } else { 
                let pool_ids = vector::empty<address>();
                vector::push_back( &mut pool_ids, *option::borrow( &pool_address ) );
                unlock_stake( pool_signer, pool_ids, remaining_amount );
            };

        };

    }

    fun withdraw_inactive_stake(pool_signer: &signer, config: &VaultConfig, withdraw_amount: u64) {

        let count = 0;
        let remaining_withdraw = withdraw_amount;

        while ( count < vector::length(  &config.delegator_pools )) {
            let delegator_address = *vector::borrow( &config.delegator_pools, count );
            let pool_address = dp::get_owned_pool_address(delegator_address); 
            
            let (_,inactive_amount,_) = dp::get_stake( pool_address, signer::address_of( pool_signer ) );

            if (remaining_withdraw != 0 && inactive_amount > 0) {
                let amount_to_withdraw = if (inactive_amount >= remaining_withdraw) {
                    remaining_withdraw
                } else {
                    inactive_amount
                };
                remaining_withdraw = remaining_withdraw-amount_to_withdraw;  
                dp::withdraw(pool_signer, pool_address, amount_to_withdraw);
            };
            
            count = count +1;
        };

    }

    fun unlock_stake(pool_signer: &signer, pools: vector<address>, withdraw_amount: u64) {

        let remaining_unlock = withdraw_amount;
        let pool_count = 0;

        while ( pool_count < vector::length(&pools)) {
            
            let pool_address = *vector::borrow( &pools, pool_count );
            let (active,_,_) = dp::get_stake( pool_address, signer::address_of( pool_signer ) );

            if (remaining_unlock != 0 && active > 0) {
                let amount_to_unlock = if (active >= remaining_unlock) {
                    remaining_unlock
                } else {
                    active
                };
                remaining_unlock = remaining_unlock-amount_to_unlock;
                dp::unlock(pool_signer, pool_address, amount_to_unlock);
            };

            pool_count = pool_count+1;
        };

        assert!( remaining_unlock == 0, ERR_TOO_LARGE );
    }

    fun find_one_with_minimal_excess(pool_signer: &signer, config: &VaultConfig, withdraw_amount: u64) : Option<address> {

        let length = vector::length(&config.delegator_pools);

        let count = 0;
        let output_address = option::none<address>();
        let ref_ratio = fixed_point64::create_from_rational(1, 2);

        while ( count < length ) {

            let delegator_address = *vector::borrow( &config.delegator_pools, count );
            let pool_address = dp::get_owned_pool_address(delegator_address); 
            let (active,_,_) = dp::get_stake( pool_address, signer::address_of( pool_signer ) );

            // Find the first pool with sufficient balance that does not exceed 50% limit 
            if (active > 0) {
                let current_ratio = fixed_point64::create_from_rational( (withdraw_amount as u128) , (active as u128));
                if (fixed_point64::greater_or_equal( ref_ratio , current_ratio )) {
                    output_address = option::some<address>( pool_address );
                    count = length;
                    break
                };
            };

            count = count+1;
        };

        output_address
    }

    fun find_combination(pool_signer: &signer, config: &VaultConfig, withdraw_amount: u64) : vector<address> {

        // Normalizing the value into the ratio
        let (ratio, ratio_to_address) = normalize_into_ratio(pool_signer, config, withdraw_amount);

        let ouput_pools = vector::empty<address>();
        let ratio_count = 0; // Tracks the total ratio

        // Looking for the pool that has 0.5 ratio first
        let target_ratio = fixed_point64::create_from_rational(1, 2);

        // Iterate until ratio > 10000
        while ( ratio_count <= 10000 ) {
            // Finds a pool with a ratio close to the target ratio
            let (value, id) = find_closest_ratio_pool(&ratio, target_ratio );

            if (option::is_some( &id )) {
                let current_value = *option::borrow(&value);
                let current_id = *option::borrow(&id);

                if (fixed_point64::greater_or_equal(fixed_point64::create_from_u128(1), current_value )) {
                    // set new target
                    target_ratio = fixed_point64::sub( fixed_point64::create_from_u128(1), current_value );
                    vector::swap_remove( &mut ratio, current_id );
                    let pool_address = vector::swap_remove( &mut ratio_to_address, current_id );
                    vector::push_back(&mut ouput_pools, pool_address);

                    // increase ratio count 
                    ratio_count = ratio_count+fixed_point64::multiply_u128(10000, current_value);
                } else {
                    vector::swap_remove( &mut ratio, current_id );
                    let pool_address = vector::swap_remove( &mut ratio_to_address, current_id );
                    vector::push_back(&mut ouput_pools, pool_address);
                    ratio_count = 10001;
                };  

            } else {
                break
            }

        };

        ouput_pools
    }

    fun normalize_into_ratio(pool_signer: &signer, config: &VaultConfig, withdraw_amount: u64) : (vector<FixedPoint64>, vector<address>) {

        let ratio = vector::empty<FixedPoint64>();
        let ratio_to_address = vector::empty<address>();
        let count = 0;

        while (count < vector::length( &config.delegator_pools )) {
            
            let delegator_address = *vector::borrow( &config.delegator_pools, count );
            let pool_address = dp::get_owned_pool_address(delegator_address); 
            let (active,_,_) = dp::get_stake( pool_address, signer::address_of( pool_signer ) );

            if (active > 0) {
                let this_ratio = fixed_point64::create_from_rational( (withdraw_amount as u128) , (active as u128));
                vector::push_back(&mut ratio, this_ratio );
                vector::push_back(&mut ratio_to_address, pool_address);
            };

            count = count+1;
        };

        ( ratio, ratio_to_address )
    }

    fun find_closest_ratio_pool( ratio_list: &vector<FixedPoint64>, target_ratio: FixedPoint64 ) : (Option<FixedPoint64>, Option<u64>) {

        let output_value = option::none<FixedPoint64>();
        let output_id = option::none<u64>();

        let precision = 1; // Initialize precision from 0.05 to 1

        // Iterate over different precision values
        while ( precision <= 20) {

            let p = fixed_point64::create_from_rational(precision, 20);  // Create fixed-point precision value

            let item_count = 0;

            // Iterate over each ratio in the ratio list
            while (item_count < vector::length(ratio_list)) {
                
                let current_ratio = *vector::borrow( ratio_list, item_count );

                // Check if the current ratio is close to the target ratio within the given precision
                if (fixed_point64::almost_equal( current_ratio, target_ratio, p)) {
                    // If found, update output variables and break the loop
                    output_value = option::some<FixedPoint64>( current_ratio );
                    output_id = option::some<u64>( item_count ); 
                    precision = 21; // break main loop
                    break
                };

                item_count = item_count + 1;
            };

            precision = precision+1;
        };
        
        ( output_value, output_id )
    }

    #[test_only]
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}