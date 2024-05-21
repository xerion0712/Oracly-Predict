// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// An extension to AMM for LBP, a special pool that allows for a gradual shift in weight per conditions.
// This provides a solution for launching project tokens with reduced capital requirements and less selling pressure.
// In Legato LBP, there are two types of settlement assets available for pairing with project tokens.
// (1) Common coins like USDC or SUI (2) SUI staking rewards via Legato Vault

module legato::lbp {

    use std::vector;
    use std::string::{Self, String}; 
    use std::type_name::{get, into_string};
    use std::ascii::into_bytes;

    use sui::coin::{Self, Coin};
    use sui::balance::{ Self, Supply, Balance}; 
    use sui::bag::{Self, Bag};
    use sui::tx_context::{ Self, TxContext}; 

    use legato::fixed_point64::{Self};
    use legato::weighted_math;
    use legato::vault::{  PT_TOKEN};
 
    /// The integer scaling setting for weights
    const WEIGHT_SCALE: u64 = 10000;

    // ======== Errors ========
 
    const ERR_INVALID_WEIGHT: u64 = 301;  
    const ERR_INVALID_SENDER: u64 = 302;
    const ERR_EMPTY: u64 = 303;
    const ERR_INVALID_POOL: u64 = 304;
    const ERR_INSUFFICIENT_AMOUNT : u64 = 305;
    const ERR_INVALID_AMOUNT: u64 = 306;

    friend legato::amm;

    // ======== Structs =========

    // Defines the settings for the LBP pool.
    struct LBPParams has store {
        is_proj_on_x: bool, // Indicates if the project token is on the X side of the pool.
        start_weight: u64,  // Initial weight of the project token.
        final_weight: u64, // The weight when the pool is stabilized.  
        is_vault: bool, // Accepts vault tokens
        target_amount: u64, // The target amount required to fully shift the weight.
        total_amount_collected: u64,  // Total amount accumulated in the pool.
    }

    // Storage for vault-related coins when accepting vault tokens
    struct LBPStorage has store {
        coins: Bag, // Storage for coins pending in and out
        pending_in: vector<String>, // List of coins pending to be added to the pool
        pending_in_amount: u64 // Total amount of coins pending to be added to the pool
    }

    // Constructs initialization parameters for an Lpending_amountBP
    public(friend) fun construct_init_params(
        proj_on_x: bool, // Indicates whether the project token is on the X or Y side
        start_weight: u64, 
        final_weight: u64,  
        is_vault: bool, // Determines if future staking rewards.
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
            total_amount_collected: 0
        }
    }

    public(friend) fun create_empty_storage(ctx: &mut TxContext) : LBPStorage {
        LBPStorage {
            coins: bag::new(ctx), 
            pending_in: vector::empty<String>(),
            pending_in_amount: 0,
            // pending_out: vector::empty<String>(),
            // pending_out_amount: 0
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
            let decline_ratio = weighted_math::power( fixed_point64::create_from_rational( accumulated_amount, total_target_amount )  , fixed_point64::create_from_rational( (params.final_weight as u128), (params.start_weight as u128) ));
            
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

    public (friend) fun is_buy(params: &LBPParams) : bool {
        // X -> Y
        if ( params.is_proj_on_x ) {
            false
        } else {
            // Y -> X
            true
        }
    }

    public(friend) fun add_pending_in<X>(storage: &mut LBPStorage, coin_in: Coin<PT_TOKEN<X>>, amount_in: u64) {
        let token_name = token_to_name<X>();

         if (!bag::contains_with_type<String, Balance<PT_TOKEN<X>>>(&storage.coins, token_name)) {
            let new_balance = balance::zero<PT_TOKEN<X>>();
            balance::join(&mut new_balance, coin::into_balance(coin_in));
            bag::add(&mut storage.coins, token_name, new_balance );
        } else {
            let current_balance = bag::borrow_mut<String, Balance<PT_TOKEN<X>>>(&mut storage.coins, token_name);
            balance::join( current_balance, coin::into_balance(coin_in) );
        };

        storage.pending_in_amount = storage.pending_in_amount+amount_in;

        if (!vector::contains(&storage.pending_in , &token_name)) {
            vector::push_back<String>(&mut storage.pending_in, token_name);
        };

    }

    // public(friend) fun add_pending_out<Y>(storage: &mut LBPStorage, coin_out: Coin<Y>, amount_out: u64 ) {

    //     let project_token_name =  token_to_name<Y>();

    //     if (!bag::contains_with_type<String, Balance<Y>>(&storage.coins, project_token_name)) {
    //         let new_balance = balance::zero<Y>();
    //         balance::join(&mut new_balance, coin::into_balance(coin_out));
    //         bag::add(&mut storage.coins, project_token_name, new_balance );
    //     } else {
    //         let current_balance = bag::borrow_mut<String, Balance<Y>>(&mut storage.coins, project_token_name);
    //         balance::join( current_balance, coin::into_balance(coin_out) );
    //     };

    //     storage.pending_out_amount = storage.pending_out_amount+amount_out;

    //     if (!vector::contains(&storage.pending_out, &project_token_name)) {
    //         vector::push_back<String>(&mut storage.pending_out, project_token_name);
    //     };

    //     // update_pending_out_table( &mut storage.pending_out_table, project_token_name, amount_out, sender_address );

    // }

    // Verifies and adjusts the amount for weight calculation
    public(friend) fun verify_and_adjust_amount(params: &mut LBPParams, is_buy: bool, amount_in: u64, _amount_out: u64 ) {
        // Works when the weight is not stabilized
        if ( params.target_amount >  params.total_amount_collected) {
            // Considered only buy transactions
            if (is_buy) {
                assert!( params.target_amount > amount_in, ERR_INVALID_AMOUNT );
                // Update the total amount collected
                params.total_amount_collected = params.total_amount_collected+amount_in;
            };
        };
    }

    public(friend) fun withdraw_pending_in<X>(storage: &mut LBPStorage, ctx: &mut TxContext) : Coin<PT_TOKEN<X>> {
        
        let token_name = token_to_name<X>();
        
        assert!(bag::contains_with_type<String, Balance<PT_TOKEN<X>>>(&storage.coins, token_name), ERR_INVALID_POOL);

        let current_balance = bag::borrow_mut<String, Balance<PT_TOKEN<X>>>(&mut storage.coins, token_name);

        // Get the total locked amount of PT tokens.
        let total_locked = balance::value(current_balance);

        // Locked amount must greater than 0, otherwise return an error.
        assert!(total_locked > 0 , ERR_EMPTY );
        
        storage.pending_in_amount = storage.pending_in_amount - total_locked;

        coin::from_balance(balance::split(current_balance, total_locked ), ctx)
    }
 
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

    public fun pending_in_amount(storage: &LBPStorage) : u64 {
        storage.pending_in_amount
    }

    public fun token_to_name<X>(): String {
        string::utf8(into_bytes(into_string(get<X>())))
    }

    // Updates the pending balance of a user for a given token.
    // fun update_pending_out_table(table: &mut Table<address, UserBalance>, token_name: String, amount: u64, sender: address) {
        
    //     // Check if the user (sender) already has a balance entry in the table
    //     if (table::contains(table, sender)) {
            
    //         let user_balance = table::borrow_mut(table, sender );

    //         // Check if the token is already in the user's token list
    //         if (!vector::contains(&user_balance.token_names , &token_name)) {
    //             // If the token is not in the list, add it along with the amount
    //             vector::push_back( &mut user_balance.token_names, token_name);
    //             vector::push_back( &mut user_balance.token_amounts, amount);
    //         } else {
    //              // If the token is already in the list, find its index
    //             let (_, index) = vector::index_of(&user_balance.token_names, &token_name );
    //             let current_amount = *vector::borrow( &user_balance.token_amounts, index );
    //             // Update the amount of the token by adding the new amount
    //             *vector::borrow_mut( &mut user_balance.token_amounts, index ) = current_amount+amount;
    //         };
    //     } else {
    //         // If the user does not have a balance entry, create new lists for token names and amounts
    //         let token_list = vector::empty<String>();
    //         let balance_list = vector::empty<u64>();

    //         // Add the token name and amount to the new lists
    //         vector::push_back( &mut token_list, token_name );
    //         vector::push_back( &mut balance_list, amount);

    //         let user_balance = UserBalance {    
    //             token_names: token_list,
    //             token_amounts: balance_list
    //         };

    //         // Add the new user balance entry to the table
    //         table::add(table, sender, user_balance);
    //     };
    // }

    // public(friend) fun pending_out_balances(storage: &LBPStorage, sender: address) : (vector<String>, vector<u64>) {
    //     assert!( table::contains(&storage.pending_out_table , sender), ERR_INVALID_SENDER );
        
    //     let user_balance = table::borrow(&storage.pending_out_table, sender );

    //     (user_balance.token_names, user_balance.token_amounts)
    // }
 
    // fun increase_total_amount_collected(params: &mut LBPParams, amount: u64) {
    //     params.total_amount_collected = params.total_amount_collected+amount;
    // }

    // #[test]
    // public fun test_current_weight() {

    //     let params = construct_init_params(
    //         false,
    //         9000, // start weight
    //         6000, // end weight 
    //         false,
    //         50000_000000 // 50,000 USDC
    //     );

    //     increase_total_amount_collected( &mut params, 2000_000000 ); // 2,000 USDC
    //     let current_weight = 10000;

    //     // Keep acquiring
    //     while ( total_amount_collected(&params) <= 50000_000000) { 
    //         let (_, weight_pair) = current_weight( &params );
 
    //         // Check that the weight is continuously declining
    //         assert!( current_weight >= weight_pair , weight_pair);
            
    //         current_weight = weight_pair;
    //         increase_total_amount_collected( &mut params, 2000_000000 );
    //     };

    // }

}