// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// An extension to AMM for LBP pools allows automatic weight shifting triggered by liquidity inflow
// The pool can be paired with any tokens such as APT or USDC and even with staking rewards earned through Legato Vault

module legato_addr::lbp {

    use std::vector;
    use aptos_std::fixed_point64::{Self, FixedPoint64}; 
    use aptos_framework::fungible_asset::{ Metadata };
    use aptos_framework::object::{Self, Object};
    use aptos_std::table::{Self, Table};

    use legato_addr::weighted_math::{power};

    friend legato_addr::amm;

    /// The integer scaling setting for weights
    const WEIGHT_SCALE: u64 = 10000;

    // ======== Errors ========
 
    const ERR_INVALID_WEIGHT: u64 = 301;  
    const ERR_INVALID_SENDER: u64 = 302;
    const ERR_EMPTY: u64 = 303;
    const ERR_INVALID_POOL: u64 = 304;
    const ERR_INSUFFICIENT_AMOUNT : u64 = 305;
    const ERR_INVALID_AMOUNT: u64 = 306;
    const ERR_TOO_LOW_AMOUNT: u64 = 307;
    const ERR_BUY_DISABLED_WITH_TOKEN: u64 = 308;
    const ERR_BUY_DISABLED_WITH_VAULT: u64 = 309;

    // ======== Structs =========

    // Defines the settings for the LBP pool.
    struct LBPParams has store {
        is_proj_on_x: bool, // Indicates if the project token is on the X side of the pool.
        start_weight: u64,  // Initial weight of the project token.
        final_weight: u64, // The weight when the pool is stabilized.  
        is_vault: bool, // Accepts vault tokens
        target_amount: u64, // The target amount required to fully shift the weight.
        total_amount_collected: u64,  // Total amount accumulated in the pool.
        enable_buy_with_pair: bool, // Enable/Disable buy with pair tokens (SUI or USDC).
        enable_buy_with_vault: bool // Enable/Disable buy with vault tokens (PT).
    }

    // Storage for vault-related coins when accepting vault tokens
    struct LBPStorage has store {
        pending_in: vector<Object<Metadata>>, // List of coins pending to be added to the pool
        pending_in_amount: Table<Object<Metadata>, u64> //  Total amount of coins pending to be added to the pool
    }

    // Constructs initialization parameters for an Lpending_amountBP
    public(friend) fun construct_init_params(
        proj_on_x: bool, // Indicates whether the project token is on the X or Y side
        start_weight: u64, 
        final_weight: u64,  
        is_vault: bool, // Determines if accept vault tokens.
        target_amount: u64
    ) : LBPParams {

        // Check if weights and trigger amount are within valid ranges.
        assert!( start_weight >= 5000 && start_weight < WEIGHT_SCALE, ERR_INVALID_WEIGHT );
        assert!( final_weight >= 5000 && final_weight < WEIGHT_SCALE, ERR_INVALID_WEIGHT );
        assert!( start_weight > final_weight, ERR_INVALID_WEIGHT ); 

        LBPParams {
            is_proj_on_x: proj_on_x,
            start_weight,
            final_weight, 
            is_vault, 
            target_amount,
            total_amount_collected: 0,
            enable_buy_with_pair: true,
            enable_buy_with_vault: true
        }
    }

    public(friend) fun create_empty_storage() : LBPStorage {
        LBPStorage { 
            pending_in: vector::empty<Object<Metadata>>(),
            pending_in_amount: table::new<Object<Metadata>, u64>(),
        }
    }

    // Calculates the current weight of the project token.
    // -  decline_ratio = (total_collected / target_amount)^(stablized_weight / start_weight)
    public(friend) fun current_weight(params: &LBPParams ) : (u64, u64) {
 
        // Check if fully shifted 
        let weight_base = if ( params.total_amount_collected >= params.target_amount ) {
            // Use final weight if the target amount is reached
            params.final_weight
        } else if (10000 > params.total_amount_collected  ) {
            // Return the start weight is value is less than 10000
            params.start_weight
        } else {

            // Calculate the weight difference
            let weight_diff = if (params.start_weight > params.final_weight) { 
                params.start_weight-params.final_weight
            } else {
                0
            };

            assert!( weight_diff > 0 , ERR_INVALID_WEIGHT);

            // Ensure the accumulated amount does not exceed the target amount
            let accumulated_amount = if (params.target_amount > params.total_amount_collected) {
                (params.total_amount_collected as u128)
            } else {    
                (params.target_amount as u128)
            };
            let total_target_amount = (params.target_amount as u128);

            // Calculate the decline ratio for weight adjustment
            let decline_ratio = power( fixed_point64::create_from_rational(accumulated_amount, total_target_amount), fixed_point64::create_from_rational( (params.final_weight as u128), (params.start_weight as u128) ));
            
            // Adjust the start weight by the decline ratio to get the current weight
            params.start_weight-(fixed_point64::multiply_u128((weight_diff as u128), decline_ratio) as u64)
        };


        let weight_pair = WEIGHT_SCALE-weight_base;

        if ( params.is_proj_on_x ) {
            (weight_base, weight_pair)
        } else {
            (weight_pair, weight_base) 
        } 
    }

    // Only admin can set a new target amount
    public(friend) fun set_new_target_amount(params: &mut LBPParams, new_target_amount: u64)  {
        assert!( new_target_amount > params.total_amount_collected, ERR_TOO_LOW_AMOUNT );
        params.target_amount = new_target_amount;
    }

    public(friend) fun enable_buy_with_pair(params: &mut LBPParams, is_enable: bool)  { 
        params.enable_buy_with_pair = is_enable;
    }

    public(friend) fun enable_buy_with_vault(params: &mut LBPParams, is_enable: bool)  { 
        params.enable_buy_with_vault = is_enable;
    }

    public (friend) fun is_buy(params: &LBPParams) : bool {
        // X -> Y
        if ( params.is_proj_on_x ) {
            false
        } else {
            // Y -> X
            true
        }
    }

    // Verifies and adjusts the amount for weight calculation
    public(friend) fun verify_and_adjust_amount(params: &mut LBPParams, is_buy: bool, amount_in: u64, _amount_out: u64, is_vault: bool ) {
        // Works when the weight is not stabilized
        if ( params.target_amount >  params.total_amount_collected) {
            // Considered only buy transactions
            if (is_buy) {
                assert!( params.target_amount > amount_in, ERR_INVALID_AMOUNT );
                if (is_vault) {
                    assert!( params.enable_buy_with_vault, ERR_BUY_DISABLED_WITH_VAULT );
                } else {
                    assert!( params.enable_buy_with_pair, ERR_BUY_DISABLED_WITH_TOKEN );
                };
                
                // Update the total amount collected
                params.total_amount_collected = params.total_amount_collected+amount_in;
            };
        };
    }

    public(friend) fun add_pending_in(storage: &mut LBPStorage, coin_in: Object<Metadata>, amount_in: u64) {

        if (!table::contains(&storage.pending_in_amount, coin_in)) { 
            table::add(
                &mut storage.pending_in_amount,
                coin_in,
                amount_in
            );
        } else {
            *table::borrow_mut( &mut storage.pending_in_amount, coin_in ) = *table::borrow( &storage.pending_in_amount, coin_in )+amount_in;
        };

        if (!vector::contains(&storage.pending_in , &coin_in)) {
            vector::push_back<Object<Metadata>>(&mut storage.pending_in, coin_in);
        };

    }

    public(friend) fun remove_pending_in(storage: &mut LBPStorage, coin_in: Object<Metadata>) : u64 {
        let output = *table::borrow( &storage.pending_in_amount, coin_in );
        *table::borrow_mut( &mut storage.pending_in_amount, coin_in ) = 0;
        output
    }

    // public(friend) fun withdraw_pending_in<X>(storage: &mut LBPStorage, ctx: &mut TxContext) : Coin<PT_TOKEN<X>> {
        
    //     let token_name = token_to_name<X>();
        
    //     assert!(bag::contains_with_type<String, Balance<PT_TOKEN<X>>>(&storage.coins, token_name), ERR_INVALID_POOL);

    //     let current_balance = bag::borrow_mut<String, Balance<PT_TOKEN<X>>>(&mut storage.coins, token_name);

    //     // Get the total locked amount of PT tokens.
    //     let total_locked = balance::value(current_balance);

    //     // Locked amount must greater than 0, otherwise return an error.
    //     assert!(total_locked > 0 , ERR_EMPTY );
        
    //     storage.pending_in_amount = storage.pending_in_amount - total_locked;

    //     coin::from_balance(balance::split(current_balance, total_locked ), ctx)
    // }

    public fun is_vault(params: &LBPParams) : bool {
        params.is_vault
    }

    public fun total_amount_collected(params: &LBPParams) : u64 {
        params.total_amount_collected
    }

    public fun total_target_amount(params: &LBPParams) : u64 {
        params.target_amount
    }

    public fun proj_on_x(params: &LBPParams) : bool {
        params.is_proj_on_x
    }

}