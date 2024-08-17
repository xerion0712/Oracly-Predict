// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// New Legato's Vault allows liquid staking on a supported random validator
// and removes the complexity of a quarterly expiration schedule,
// making its behavior similar to other liquid staking protocols.

module legato::vault {

    use sui::url;
    use sui::sui::SUI; 
    use sui::transfer; 
    use sui::balance::{ Self, Supply, Balance}; 
    use sui::tx_context::{ Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::object::{ Self, ID, UID };
    use sui_system::staking_pool::{ Self, StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState }; 
 
    use std::option::{  Self, Option};
    use std::vector; 

    use legato_math::fixed_point64::{Self, FixedPoint64};
    use legato::stake_data_provider::{Self};
    use legato::vault_lib::{  find_combination, find_one_with_minimal_excess, get_amount_with_rewards, sort_items, sort_u64 };
    use legato::event::{ mint_event, request_redeem_event, redeem_event };

    // ======== Constants ========

    const MIN_AMOUNT: u64 = 1_000_000_000; // Minimum amount required to stake and unstake
    const UNSTAKE_DELAY: u64 = 1; // Default delay for unstaking, set to 1 epoch 
    const MINIMAL_LIQUIDITY: u64 = 1000; // Minimal liquidity.

    // ======== Errors ========

    const ERR_ZERO_VALUE: u64 = 1;
    const ERR_INVALID_VALUE: u64 = 2;
    const ERR_DUPLICATED_ENTRY: u64 = 3;
    const ERR_NOT_FOUND: u64 = 4;
    const ERR_MIN_THRESHOLD: u64 = 5;
    const ERR_INSUFFICIENT: u64 = 6;
    const ERR_NOT_ENABLED: u64 = 7;
    const ERR_UNAUTHORIZED_POOL: u64 = 8;
    const ERR_DEPOSIT_CAP: u64 = 9;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 10;
    const ERR_NONE_ASSET_WITHDRAWN: u64 = 11;
    const ERR_EMPTY_LIST: u64 = 12;

    // ======== Structs =========

    // Yield-bearing token representing shares in the staking pool
    public struct VAULT has drop {}

    // Using ManagerCap for admin permission
    public struct ManagerCap has key {
        id: UID
    }

    // Representing an unstaking request
    public struct Request has store, drop {
        sender: address, // Address of the user making the request
        amount: u64, // SUI amount to be sent out when available
        epoch: u64 // Epoch at which the request was made
    }

    // Represents a prioritized staking pool with a specific quota
    public struct Priority has store, drop {
        staking_pool: address, // Address of the staking pool
        quota_amount: u64 // Quota amount allocated for staking in this pool
    }

    // Representing the reserve
    public struct VaultReserve has store {
        lp_supply: Supply<VAULT>, // Supply of vault tokens (LP)
        staked_sui: vector<StakedSui>, // Storage for staked SUI objects
        min_liquidity: Balance<VAULT>
    }

    // Representing the configuration
    public struct VaultConfig has store {
        staking_pools: vector<address>,  // List of supported staking pools (addresses)
        staking_pool_ids: vector<ID>, // List of supported staking pools (IDs)
        priority_list: vector<Priority>, // List of prioritized staking pools and quotas to be staked
        deposit_cap: Option<u64>, // Optional cap on the total deposits allowed in the vault
        min_amount: u64, // Minimum amount required to unstake
        unstake_delay: u64, // Delay period for unstaking, specified in epochs
        enable_mint: bool,
        enable_redeem: bool
    }

    // Global state
    public struct VaultGlobal has key {
        id: UID,
        config: VaultConfig,
        reserve: VaultReserve,
        pending_withdrawal: Balance<SUI>, // Balance of SUI pending withdrawal
        pending_fulfil: Balance<SUI>,  // Balance of SUI pending to be sent out
        request_list: vector<Request>, // List of unstaking requests
        current_balance_with_rewards: u64, // Need to call update_amounts() on a regular basis to update it
        total_lp_amount: u64 // Same to above
    }

    fun init(witness: VAULT, ctx: &mut TxContext) {

        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        let (treasury_cap, metadata) = coin::create_currency<VAULT>(witness, 9, b"LV-SUI", b"Legato Vault Token", b"", option::some(url::new_unsafe_from_bytes(b"https://img.tamago.finance/legato-logo-icon.png")), ctx);
        transfer::public_freeze_object(metadata);
        
        transfer::share_object(VaultGlobal {
            id: object::new(ctx),
            config: VaultConfig {
                staking_pools: vector::empty<address>(),
                staking_pool_ids: vector::empty<ID>(), 
                priority_list: vector::empty<Priority>(),
                deposit_cap: option::none<u64>(),
                min_amount: MIN_AMOUNT,
                unstake_delay: UNSTAKE_DELAY, 
                enable_mint: true,
                enable_redeem: true
            },
            reserve: VaultReserve {
                lp_supply: coin::treasury_into_supply<VAULT>(treasury_cap),
                staked_sui: vector::empty<StakedSui>(), 
                min_liquidity: balance::zero<VAULT>()
            },
            pending_withdrawal: balance::zero<SUI>(),
            pending_fulfil: balance::zero<SUI>(),
            request_list:  vector::empty<Request>(),
            current_balance_with_rewards: 0,
            total_lp_amount: 0
        })
    }

    // ======== Entry Functions =========

    // Mints VAULT tokens for the provided SUI coins
    public entry fun mint_from_sui(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, sui: Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(&sui) >= MIN_AMOUNT, ERR_MIN_THRESHOLD);
        let validator_address = next_validator( global, coin::value(&sui), ctx);
        let staked_sui = sui_system::request_add_stake_non_entry(wrapper, sui, validator_address, ctx);
        mint(wrapper, global, staked_sui , ctx);
    }

    // Mints VAULT tokens for the provided staked SUI.
    public entry fun mint(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, staked_sui: StakedSui, ctx: &mut TxContext) {

        let input_amount = staking_pool::staked_sui_amount(&staked_sui);
        let lp_token = mint_non_entry( wrapper, global, staked_sui, ctx );
        let lp_amount = coin::value(&lp_token);

        // Transfer LP to the user
        transfer::public_transfer( lp_token , tx_context::sender(ctx));

        mint_event( object::id(global), input_amount, lp_amount, tx_context::sender(ctx), tx_context::epoch(ctx))
    }

    // Allows a user to request the redemption of their staked assets
    public entry fun request_redeem(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, vault_token: Coin<VAULT>, ctx: &mut TxContext) {
        assert!(coin::value(&vault_token) >= global.config.min_amount, ERR_MIN_THRESHOLD);
        assert!(global.config.enable_redeem == true, ERR_NOT_ENABLED);
        
        let lp_amount = coin::value<VAULT>(&vault_token);
        let lp_supply = balance::supply_value(&global.reserve.lp_supply);
        let current_balance = current_balance_with_rewards(wrapper, &global.reserve.staked_sui, tx_context::epoch(ctx));
        
        // Calculate the withdrawal amount from the given vault token
        let multiplier = fixed_point64::create_from_rational( (current_balance as u128), ( lp_supply as u128));
        let withdrawal_amount = (fixed_point64::multiply_u128( (lp_amount as u128), multiplier) as u64);

        // Initiate withdrawal by unstaking locked Staked SUI items close to the withdrawal amount
        // and move them into the shared pool
        prepare_withdrawal(wrapper, global, withdrawal_amount, ctx);

        // Add the request to the request list
        let withdrawn_sui = withdraw_sui(global, withdrawal_amount, ctx);

        balance::join<SUI>(&mut global.pending_fulfil, coin::into_balance(withdrawn_sui));

        vector::push_back( &mut global.request_list, Request {
            sender: tx_context::sender(ctx), 
            amount: withdrawal_amount,
            epoch: tx_context::epoch(ctx)
        });

        // Burn the VAULT tokens
        balance::decrease_supply(&mut global.reserve.lp_supply, coin::into_balance(vault_token));
 
        request_redeem_event( object::id(global), lp_amount, withdrawal_amount, tx_context::sender(ctx), tx_context::epoch(ctx)  )
    }

    // Fulfil unstaking requests
    public entry fun fulfil_request(global: &mut VaultGlobal, ctx: &mut TxContext) {
        assert!( vector::length(&global.request_list) > 0, ERR_EMPTY_LIST );

        let mut count = 0;
        let mut withdraw_ids = vector::empty<u64>();

        // Identify requests eligible for fulfilment
        while ( count < vector::length(&global.request_list)) {  
            let this_request = vector::borrow( &global.request_list, count);
            if ( tx_context::epoch(ctx) >= this_request.epoch+global.config.unstake_delay ) {
                vector::push_back( &mut withdraw_ids, count );
            };
            count = count+1;
        };

        // Fulfil each eligible request
        while (vector::length(&withdraw_ids) > 0) {
            let request_id = vector::pop_back(&mut withdraw_ids);
            let this_request = vector::swap_remove(&mut global.request_list, request_id);

            let withdrawn_balance = balance::split<SUI>(&mut global.pending_fulfil, this_request.amount);
            transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), this_request.sender);

            redeem_event( object::id(global), this_request.amount, this_request.sender, tx_context::epoch(ctx)  )
        };
    
    }

    public entry fun update_amounts(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, ctx: &mut TxContext) { 
        global.current_balance_with_rewards = current_balance_with_rewards(wrapper, &global.reserve.staked_sui, tx_context::epoch(ctx));
        global.total_lp_amount = balance::supply_value(&global.reserve.lp_supply);
    }
 
    // ======== Public Functions =========

    public fun mint_non_entry(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, staked_sui: StakedSui, ctx: &mut TxContext) : Coin<VAULT> {
        // Ensure minting is enabled for the vault
        assert!(global.config.enable_mint == true, ERR_NOT_ENABLED);
        // Ensure staked SUI amount is above the minimum threshold
        assert!(staking_pool::staked_sui_amount(&staked_sui) >= MIN_AMOUNT, ERR_MIN_THRESHOLD);

        // Check if the staked SUI is staked on a valid staking pool
        let pool_id = staking_pool::pool_id(&staked_sui);
        assert!(vector::contains(&global.config.staking_pool_ids, &pool_id), ERR_UNAUTHORIZED_POOL);

        // Extract principal amount of staked SUI
        let principal_amount = staking_pool::staked_sui_amount(&staked_sui);

        // Apply deposit cap if defined
        if (option::is_some(&global.config.deposit_cap)) {
            assert!( *option::borrow(&global.config.deposit_cap) >= principal_amount, ERR_DEPOSIT_CAP);
            *option::borrow_mut(&mut global.config.deposit_cap) = *option::borrow(&global.config.deposit_cap)-principal_amount;
        };

        // Calculate total earned amount until current epoch
        let total_earned = 
            if (tx_context::epoch(ctx) > staking_pool::stake_activation_epoch(&staked_sui))
                stake_data_provider::earnings_from_staked_sui(wrapper, &staked_sui, tx_context::epoch(ctx))
            else 0;

        let input_value = principal_amount+total_earned;
        let lp_supply = balance::supply_value(&global.reserve.lp_supply);
        let current_balance = current_balance_with_rewards(wrapper, &global.reserve.staked_sui, tx_context::epoch(ctx));

        // Calculate the amount of LP tokens to mint
        let lp_amount_to_mint = if (lp_supply == 0) {
            // Check if initial liquidity is sufficient.
            assert!(input_value > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

            let minimal_liquidity = balance::increase_supply(
                &mut global.reserve.lp_supply,
                MINIMAL_LIQUIDITY
            );
            balance::join(&mut global.reserve.min_liquidity, minimal_liquidity);
            // Calculate the initial LP amount
            input_value - MINIMAL_LIQUIDITY
        } else {
            let ratio = fixed_point64::create_from_rational((input_value as u128) , (current_balance as u128));
            let total_share = fixed_point64::multiply_u128( (lp_supply as u128) , ratio);
            (total_share as u64)
        };

        // Lock Staked SUI
        vector::push_back<StakedSui>(&mut global.reserve.staked_sui, staked_sui); 
        if (vector::length(&global.reserve.staked_sui) > 1) sort_items(&mut global.reserve.staked_sui);

        // Update balances for the frontend to fetch
        global.current_balance_with_rewards = current_balance+input_value;
        global.total_lp_amount = lp_supply+lp_amount_to_mint;

        (mint_lp( &mut global.reserve, lp_amount_to_mint, ctx))
    }

    // Retrieve the amount of pending withdrawals
    public fun get_pending_withdrawal_amount(global: &VaultGlobal) : u64 {
        balance::value(&global.pending_withdrawal)
    }

    public fun staking_pools(global: &VaultGlobal) : vector<address> {
        global.config.staking_pools
    }

    // ======== Only Governance =========

    // Updates the minimum amount required to stake and unstake 
    public entry fun update_min_amount(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, new_value: u64 ) {
        assert!( new_value > 0, ERR_ZERO_VALUE );
        global.config.min_amount = new_value;
    }

    // Updates the delay period for unstaking in the vault
    public entry fun update_unstake_delay(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, new_value: u64) {
        assert!( 30 >= new_value, ERR_INVALID_VALUE );
        global.config.unstake_delay = new_value;
    }

    // To set the deposit cap. Put amount as zero to ignore
    public entry fun set_deposit_cap(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, amount: u64) {
        // Check if the amount is zero
        if (amount == 0)
            // Set deposit cap to none
            global.config.deposit_cap = option::none<u64>()
        // Set deposit cap to the specified amount
        else global.config.deposit_cap = option::some<u64>(amount);
    }

    // Enable or Disable Minting
    public entry fun enable_mint(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, is_enable: bool) {
        global.config.enable_mint = is_enable;
    }

    // Enable or Disable Redeeming
    public entry fun enable_redeem(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, is_enable: bool) {
        global.config.enable_redeem = is_enable;
    }

    // To add a supported staking pool
    public entry fun attach_pool(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, pool_address: address, pool_id: ID) {
        // Ensure that the pool address is not already in the list
        assert!(!vector::contains(&global.config.staking_pools, &pool_address), ERR_DUPLICATED_ENTRY);
        // Add the pool address and its ID to the respective lists
        vector::push_back<address>(&mut global.config.staking_pools, pool_address);
        vector::push_back<ID>(&mut global.config.staking_pool_ids, pool_id);
    }

    // To remove a staking pool from the list
    public entry fun detach_pool(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, pool_address: address) {
        let (contained, index) = vector::index_of<address>(&global.config.staking_pools, &pool_address);
        assert!(contained, ERR_NOT_FOUND);
        vector::remove<address>(&mut global.config.staking_pools, index);
        vector::remove<ID>(&mut global.config.staking_pool_ids, index);
    }

    // To top-up SUI into the redemption pool
    public entry fun topup_redemption_pool(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, coin: Coin<SUI>, _ctx: &mut TxContext) {
        let balance = coin::into_balance(coin);
        balance::join<SUI>(&mut global.pending_withdrawal, balance);
    }

    // To withdraw SUI from the redemption pool
    public entry fun withdraw_redemption_pool(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, amount: u64, ctx: &mut TxContext) {
        let withdrawn_balance = balance::split<SUI>(&mut global.pending_withdrawal, amount);
        transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), tx_context::sender(ctx));
    }


    // Restake SUI from the redemption pool to the staking pool 
    public entry fun restake(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, _manager_cap: &mut ManagerCap,  restake_amount: u64, ctx: &mut TxContext ) {
        assert!(restake_amount >= MIN_AMOUNT, ERR_MIN_THRESHOLD);
        assert!(balance::value( &global.pending_withdrawal ) >= restake_amount , ERR_INSUFFICIENT);
 
        let validator_address = next_validator( global, restake_amount, ctx );
        let restake_balance = balance::split<SUI>(&mut global.pending_withdrawal, restake_amount);

        // Request to add stake
        let staked_sui = sui_system::request_add_stake_non_entry(wrapper, coin::from_balance(restake_balance, ctx), validator_address, ctx);
        vector::push_back<StakedSui>(&mut global.reserve.staked_sui, staked_sui); 
    }

    // Adds a new prioritized staking pool
    public entry fun add_priority(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, pool_address: address, quota_amount: u64) {
        // Ensure that the pool address is in the list
        assert!(vector::contains(&global.config.staking_pools, &pool_address), ERR_UNAUTHORIZED_POOL);
        assert!( quota_amount >= MIN_AMOUNT, ERR_MIN_THRESHOLD );

        vector::push_back( 
            &mut global.config.priority_list,
            Priority {
                staking_pool: pool_address,
                quota_amount
            }
        );
    }

    // Removes a prioritized staking pool
    public entry fun remove_priority(global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, priority_id: u64) {
        assert!( vector::length( &global.config.priority_list ) > priority_id, ERR_INVALID_VALUE );
        vector::swap_remove( &mut global.config.priority_list, priority_id );
    }

    // ======== Internal Functions =========

    // Determines the next validator to stake to based on priority list or randomly if no priorities
    fun next_validator(global: &mut VaultGlobal, stake_amount: u64, ctx: &TxContext) : address {
        // Check if there are any entries in the priority list
        if (vector::length( &global.config.priority_list ) > 0 ) {
            let first_entry = vector::borrow_mut( &mut global.config.priority_list, 0);
            let staking_pool_address = first_entry.staking_pool;
            let new_amount = if ( first_entry.quota_amount > stake_amount) {
                first_entry.quota_amount - stake_amount
            } else {
                0
            };

            first_entry.quota_amount = new_amount;

            if (new_amount == 0) {
                vector::swap_remove( &mut global.config.priority_list, 0);
            };

            // Return the address of the staking pool from the priority list
            staking_pool_address
        } else { 
            // If no priority list entries, select a random validator address
            random_validator_address( global.config.staking_pools, ctx )
        }
    }

    fun random_validator_address(validator_list: vector<address>, ctx: &TxContext) : address {
        *vector::borrow( &validator_list, (100+tx_context::epoch(ctx)) % vector::length(&validator_list) )
    }

    fun mint_lp(vault_reserve: &mut VaultReserve, amount: u64, ctx: &mut TxContext )  : Coin<VAULT> {
        let minted_balance = balance::increase_supply(&mut vault_reserve.lp_supply, amount);
        coin::from_balance(minted_balance, ctx)
    }

    fun withdraw_sui(global: &mut VaultGlobal, amount: u64, ctx: &mut TxContext) : Coin<SUI>  {
        assert!( balance::value(&global.pending_withdrawal) >= amount, ERR_INVALID_VALUE);
        coin::from_balance(balance::split(&mut global.pending_withdrawal, amount), ctx) 
    }

    fun current_balance_with_rewards(wrapper: &mut SuiSystemState, staked_sui_list: &vector<StakedSui>, epoch: u64) : u64 {
        let count = vector::length(staked_sui_list);
        let mut i = 0;
        let mut total_sum = 0;

        while (i < count) {
            let staked_sui = vector::borrow(staked_sui_list, i);
            let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);
            if (epoch > activation_epoch) {
                total_sum = total_sum+staking_pool::staked_sui_amount(staked_sui)+stake_data_provider::earnings_from_staked_sui(wrapper, staked_sui, epoch);
            } else {
                total_sum = total_sum+staking_pool::staked_sui_amount(staked_sui);
            };
            i = i + 1;
        };

        total_sum
    }


    fun prepare_withdrawal(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, withdrawal_amount: u64, ctx: &mut TxContext) {
        // ignore if there are sufficient SUI to pay out
        if (withdrawal_amount > balance::value(&global.pending_withdrawal)) {
            // extract all asset IDs to be withdrawn
            let pending_withdrawal = balance::value(&global.pending_withdrawal);
            let remaining_amount = withdrawal_amount-pending_withdrawal;

            // Look for a single asset that cover first
            let asset_id = find_one_with_minimal_excess(wrapper, &global.reserve.staked_sui, remaining_amount, tx_context::epoch(ctx));

            if (option::is_none<u64>(&asset_id)) {
                // If no single asset fits, then we look for multiple assets. 
                let mut asset_ids = find_combination(wrapper, &global.reserve.staked_sui , remaining_amount, tx_context::epoch(ctx));
                assert!( vector::length( &asset_ids ) > 0 , ERR_NONE_ASSET_WITHDRAWN  );
                sort_u64(&mut asset_ids);
                let sui_balance = unstake_staked_sui(wrapper, global, &mut asset_ids, ctx); 
                balance::join<SUI>(&mut global.pending_withdrawal, sui_balance );
            } else {
                let mut asset_ids = vector::empty<u64>(); 
                vector::push_back<u64>( &mut asset_ids, *option::borrow(&asset_id)); 
                let sui_balance = unstake_staked_sui(wrapper, global, &mut asset_ids, ctx); 
                balance::join<SUI>(&mut global.pending_withdrawal, sui_balance );
            };

        };

    }

    // Unstake Staked SUI from the validator node
    fun unstake_staked_sui(wrapper: &mut SuiSystemState, global: &mut VaultGlobal, asset_ids: &mut vector<u64>, ctx: &mut TxContext): Balance<SUI> {
        let mut balance_sui = balance::zero();  

        while (vector::length<u64>(asset_ids) > 0) {
            let asset_id = vector::pop_back(asset_ids);
            let staked_sui = vector::swap_remove(&mut global.reserve.staked_sui, asset_id);
            let principal_amount = staking_pool::staked_sui_amount(&staked_sui);

            // Request to withdraw 
            let balance_each = sui_system::request_withdraw_stake_non_entry(wrapper, staked_sui, ctx);

            balance::join<SUI>(&mut balance_sui, balance_each);
        };

        balance_sui
    }

    // ======== Test-related Functions =========

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(VAULT {}, ctx)
    }

}