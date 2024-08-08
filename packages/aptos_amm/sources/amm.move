// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// AMM DEX with custom weights on Aptos Move supports FA assets
// The logic and mathematical calculations for managing pools are borrowed
// from the established methodologies used in Balancer v.2 and OmniBTC.
//
// This implementation allows projects to set up a pool with less capital
// compared to traditional 50/50 weight AMM DEXs.


module legato_amm_addr::amm {

    use std::signer;  
    use std::string::{Self, String, utf8, bytes }; 
    use std::option::{Self, Option};
    use std::vector;

    use aptos_std::comparator;
    use aptos_std::math128;
    use aptos_std::math64;
    use aptos_std::table::{Self, Table};
    use aptos_std::fixed_point64::{Self, FixedPoint64}; 

    use aptos_framework::event;
    use aptos_framework::fungible_asset::{
        Self, FungibleAsset, FungibleStore, Metadata,
        BurnRef, MintRef, TransferRef,
    };
    use aptos_framework::object::{Self, ConstructorRef, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;

    use legato_amm_addr::base_fungible_asset;
    use legato_amm_addr::weighted_math;

    // ======== Constants ========

    // Default swap fee of 0.5% in fixed-point
    const DEFAULT_FEE: u128 = 92233720368547758; 
    // Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000; 

    // ======== Errors ========

    const ERR_UNAUTHORIZED: u64 = 1;
    const ERR_POOL_HAS_REGISTERED: u64 = 2;
    const ERR_WEIGHTS_SUM: u64 = 3;
    const ERR_POOL_NOT_REGISTER: u64 = 4;
    const ERR_INVALID_ADDRESS: u64 = 5;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 6;
    const ERR_PAUSED: u64 = 7;
    const ERR_INSUFFICIENT_COIN_X: u64 = 8;
    const ERR_INSUFFICIENT_COIN_Y: u64 = 9;
    const ERR_OVERLIMIT: u64 = 10;
    const ERR_INSUFFICIENT_AMOUNT: u64 = 11;
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 12;
    const ERR_RESERVES_EMPTY: u64 = 13;
    const ERR_INVALID_PATH_LENGTH: u64 = 14;

    // ======== Structs =========

    // Liquidity pool with custom weighting 
    struct Pool has store { 
        token_1: Object<FungibleStore>,
        token_2: Object<FungibleStore>,
        weight_1: u64, // Weight on the X, e.g., 50% using 5000
        weight_2: u64, // Weight on the Y, e.g., 50% using 5000
        min_liquidity: Object<FungibleStore>,
        swap_fee: FixedPoint64,
        lp_mint: MintRef,
        lp_burn: BurnRef,
        lp_transfer: TransferRef,
        lp_metadata: Object<Metadata>,
        has_paused: bool
    }

    // Represents the global state of the AMM. 
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct AMMGlobal has key { 
        pools: Table<String, Pool>,
        archives: Table<String, Pool>,
        whitelist: vector<address>, // who can setup a new pool
        extend_ref: ExtendRef,
        enable_whitelist: bool,
        treasury_address: address // where all fees from all pools will be sent for further LP staking
    }

    // Used when swapping with a specified path
    struct Route has drop, store {
        token_1: Object<Metadata>,
        token_2: Object<Metadata>,
        pool_name: String,
        is_order: bool
    }

    #[event]
    /// Event emitted when a pool is created.
    struct RegisterPool has drop, store { 
        pool_name: String,
        token_1: String,
        token_2: String,
        weight_1: u64,
        weight_2: u64
    }

    #[event]
    struct AddedLiquidity has drop, store {
        pool_name: String,
        token_1: String,
        token_2: String,
        token_1_in: u64,
        token_2_in: u64,
        lp_out: u64
    }

    #[event]
    struct RemovedLiquidity has drop, store {
        pool_name: String,
        lp_in: u64,
        token_1: String,
        token_2: String,
        token_1_out: u64,
        token_2_out: u64
    }

    #[event]
    struct Swapped has drop, store {
        pool_name: String,
        token_in: String,
        token_out: String,
        amount_in: u64,
        amount_out: u64
    }

    #[event]
    struct RouteSwapped has drop, store {
        pool_name: vector<String>,
        token_in: String,
        token_out: String,
        amount_in: u64,
        amount_out: u64
    }

    // Initializes the AMM module
    fun init_module(sender: &signer) {
        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        let whitelist = vector::empty<address>();
        vector::push_back(&mut whitelist, signer::address_of(sender));

        move_to(sender, AMMGlobal { 
            whitelist, 
            pools: table::new<String, Pool>(),
            archives: table::new<String, Pool>(),
            extend_ref,
            enable_whitelist: true,
            treasury_address: signer::address_of(sender)
        });
    }

    // ======== Entry Points =========

    // Entry point for the `swap` method
    public entry fun swap(
        sender: &signer,
        token_1: Object<Metadata>,
        token_2: Object<Metadata>,
        token_in: u64,
        token_out_min: u64
    )  acquires AMMGlobal  {
        
        let is_order = is_order(token_1, token_2);

        let token_out = swap_out_non_entry(sender, token_1, token_2, token_in, token_out_min, is_order);

        let amount_out = fungible_asset::amount(&token_out);

        primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), token_2);
        let store = primary_fungible_store::primary_store(signer::address_of(sender), token_2);
        fungible_asset::deposit(store, token_out);

        let (lp_name, _) = if (is_order) {
            generate_lp_name_and_symbol(token_1, token_2)
        } else {
            generate_lp_name_and_symbol(token_2, token_1)
        };

        // Emit an event
        event::emit(Swapped { pool_name: lp_name, token_in: fungible_asset::symbol(token_1), token_out: fungible_asset::symbol(token_2), amount_in: token_in, amount_out });
    }

    // Swaps tokens across multiple pools using the provided path.
    // The path length must be between 2 and 4
    public entry fun route_swap(sender: &signer, path: vector<Object<Metadata>>, token_in: u64, token_out_min: u64)  acquires AMMGlobal {
        assert!( vector::length( &path ) >= 2 && vector::length( &path ) <= 4 , ERR_INVALID_PATH_LENGTH );

        if ( vector::length( &path ) == 2 ) {
            // Single-hop swap 

            let token_1 = *vector::borrow(&path, 0);
            let token_2 = *vector::borrow(&path, 1);
            let is_order = is_order(token_1, token_2);

            // Execute the swap
            let token_out = swap_out_non_entry(sender, token_1, token_2, token_in, token_out_min, is_order);
            let amount_out = fungible_asset::amount(&token_out);

            primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), token_2);
            let store = primary_fungible_store::primary_store(signer::address_of(sender), token_2);
            fungible_asset::deposit(store, token_out);

            let (lp_name, _) = if (is_order) {
                generate_lp_name_and_symbol(token_1, token_2)
            } else {
                generate_lp_name_and_symbol(token_2, token_1)
            };

            let pool_name = vector::empty<String>();
            vector::push_back( &mut pool_name, lp_name );

            // Emit an event
            event::emit(RouteSwapped { pool_name, token_in: fungible_asset::symbol(token_1), token_out: fungible_asset::symbol(token_2), amount_in: token_in, amount_out });
        } else {

            // Multi-hop swaps for paths with more than 2 pools
            let routes = extract_routes(path);

            // Check if any pool in the route is paused
            check_routes(&routes);

            let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);

            let input_token = *vector::borrow(&path, 0);
            let fungible_asset_in = primary_fungible_store::withdraw(sender, input_token, token_in);
            let amount_in = fungible_asset::amount(&fungible_asset_in);

            primary_fungible_store::ensure_primary_store_exists( signer::address_of(&config_object_signer) , input_token);
            let store = primary_fungible_store::primary_store(signer::address_of(&config_object_signer)  , input_token);
            fungible_asset::deposit( store , fungible_asset_in);

            let token_amounts = vector::empty<u64>();
            vector::push_back( &mut token_amounts, amount_in);

            let pool_count = 0;
            let pool_name = vector::empty<String>();

            // Perform swaps across each pool in the route
            while (pool_count < vector::length( &routes )) {
                let route = vector::borrow( &routes, pool_count); 

                let token_in = vector::pop_back(&mut token_amounts); 
                let token_out = swap_out_non_entry(&config_object_signer, route.token_1, route.token_2, token_in, 0, route.is_order);
                let token_out_amount = fungible_asset::amount(&token_out);

                primary_fungible_store::ensure_primary_store_exists( signer::address_of(&config_object_signer), route.token_2);
                let store = primary_fungible_store::primary_store(signer::address_of(&config_object_signer), route.token_2);
                fungible_asset::deposit( store , token_out);

                vector::push_back( &mut token_amounts, token_out_amount);
                vector::push_back( &mut pool_name, route.pool_name);

                pool_count = pool_count+1;
            };

            // Send the final output tokens to the sender
            let output_amount = vector::pop_back(&mut token_amounts); 
            let output_token = *vector::borrow(&path, vector::length(&routes)-1);
            
            let fungible_asset_out = primary_fungible_store::withdraw(&config_object_signer, output_token, output_amount);

            primary_fungible_store::ensure_primary_store_exists( signer::address_of(sender) , output_token);
            let store = primary_fungible_store::primary_store(signer::address_of(sender)  , output_token);
            fungible_asset::deposit( store , fungible_asset_out);

            assert!(
                output_amount >= token_out_min,
                ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
            );

            // Emit event
            event::emit(RouteSwapped { pool_name, token_in: fungible_asset::symbol(input_token), token_out: fungible_asset::symbol(output_token), amount_in, amount_out: output_amount });
        };
    }
    
    // Register a new liquidity pool with custom weights
    public entry fun register_pool(
        sender: &signer, 
        token_1: Object<Metadata>,
        token_2: Object<Metadata>,
        weight_1: u64,
        weight_2: u64
    )  acquires AMMGlobal {

        let is_order = is_order(token_1, token_2);

        if (!is_order) {
            register_pool(sender, token_2, token_1, weight_2, weight_1);
        } else {

            let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
            if (config.enable_whitelist) {
                // Ensure that the caller is on the whitelist
                assert!( vector::contains(&config.whitelist, &(signer::address_of(sender))) , ERR_UNAUTHORIZED);
            };

            let (lp_name, lp_symbol) = generate_lp_name_and_symbol(token_1, token_2);

            assert!( !table::contains(&config.pools, lp_name), ERR_POOL_HAS_REGISTERED);

            let constructor_ref = &object::create_named_object(&config_object_signer, *bytes(&lp_symbol) );

            base_fungible_asset::initialize(
                constructor_ref,
                0, /* maximum_supply. 0 means no maximum */
                lp_name, /* name */
                utf8(b"LP"), /* symbol */
                8, /* decimals */
                utf8(b"https://img.tamago.finance/legato-logo-icon.png"), /* icon */
                utf8(b"https://legato.finance"), /* project */
            );

            let pool = init_pool_params(constructor_ref, token_1, token_2, weight_1, weight_2, fixed_point64::create_from_raw_value( DEFAULT_FEE ) );

            // Add to the table.
            table::add(
                &mut config.pools,
                lp_name,
                pool
            );

            // Emit an event
            event::emit(RegisterPool { pool_name: lp_name, token_1 : fungible_asset::symbol(token_1), token_2 : fungible_asset::symbol(token_2),  weight_1, weight_2 });

        };

    }

    // Entrypoint for the `add_liquidity` method.
    public entry fun add_liquidity(
        lp_provider: &signer, 
        token_1: Object<Metadata>,
        token_2: Object<Metadata>,
        coin_x_amount: u64,
        coin_x_min: u64,
        coin_y_amount: u64,
        coin_y_min: u64
    ) acquires AMMGlobal {
        
        let is_order = is_order(token_1, token_2);

        if (!is_order) {
            add_liquidity( lp_provider, token_2, token_1, coin_y_amount, coin_y_min, coin_x_amount, coin_x_min );
        } else {

            let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
            let (lp_name, _) = generate_lp_name_and_symbol(token_1, token_2);
            assert!( table::contains( &config.pools, lp_name ) , ERR_POOL_NOT_REGISTER);

            let pool_config = table::borrow_mut( &mut config.pools, lp_name );

            let (optimal_x, optimal_y, is_pool_creator) = calc_optimal_coin_values(
                pool_config,
                coin_x_amount,
                coin_y_amount,
                coin_x_min,
                coin_y_min
            );

            assert!(optimal_x >= coin_x_min, ERR_INSUFFICIENT_COIN_X);
            assert!(optimal_y >= coin_y_min, ERR_INSUFFICIENT_COIN_Y);

            let optimal_1 = primary_fungible_store::withdraw(lp_provider, token_1, optimal_x);
            let optimal_2 = primary_fungible_store::withdraw(lp_provider, token_2, optimal_y);

            let lp_tokens = mint_lp(pool_config, optimal_1, optimal_2  );

            let lp_out = fungible_asset::amount(&lp_tokens);

            // LP tokens of the pool creator are sent to the treasury and may receive another form of incentives
            if (is_pool_creator) {
                let treasury_address = config.treasury_address;
                let lp_store = ensure_lp_token_store( pool_config, treasury_address);
                fungible_asset::deposit_with_ref( &pool_config.lp_transfer, lp_store, lp_tokens);
            } else {
                let lp_store = ensure_lp_token_store( pool_config, signer::address_of(lp_provider));
                fungible_asset::deposit_with_ref( &pool_config.lp_transfer, lp_store, lp_tokens);
            };

            // Emit an event
            event::emit(AddedLiquidity { pool_name: lp_name, token_1: fungible_asset::symbol(token_1), token_2: fungible_asset::symbol(token_2),  token_1_in: optimal_x, token_2_in: optimal_y , lp_out  });

        };
    }

    // Entrypoint for the `remove_liquidity` method.
    public entry fun remove_liquidity(lp_provider: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>,  lp_amount: u64) acquires AMMGlobal {

        let is_order = is_order(token_1, token_2);

        if (!is_order) {
            remove_liquidity( lp_provider, token_2, token_1, lp_amount );
        } else {
            
            let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
            
            // Generate the LP token name and check if the pool is registered
            let (lp_name, _) = generate_lp_name_and_symbol(token_1, token_2);
            assert!( table::contains( &config.pools, lp_name ) , ERR_POOL_NOT_REGISTER);

            let pool_config = table::borrow_mut( &mut config.pools, lp_name );
            assert!(!pool_config.has_paused , ERR_PAUSED );

            let lp_token_supply = option::destroy_some(fungible_asset::supply(pool_config.lp_metadata));
            let reserve_1 = fungible_asset::balance(pool_config.token_1);
            let reserve_2 = fungible_asset::balance(pool_config.token_2);

            let (weight_1, weight_2 ) = pool_current_weight(pool_config);

            // Calculate the amount of tokens to withdraw
            let (coin_x_out, coin_y_out) = weighted_math::compute_withdrawn_coins( 
                lp_amount, 
                (lp_token_supply as u64), 
                reserve_1, 
                reserve_2, 
                weight_1, 
                weight_2
            ); 

            // Withdraw the tokens from the pool
            let coin_x_withdrawn = fungible_asset::withdraw(&config_object_signer, pool_config.token_1, coin_x_out);
            let coin_y_withdrawn = fungible_asset::withdraw(&config_object_signer, pool_config.token_2, coin_y_out);

            primary_fungible_store::ensure_primary_store_exists(signer::address_of(lp_provider), token_1);
            let store_x = primary_fungible_store::primary_store(signer::address_of(lp_provider), token_1);
            fungible_asset::deposit(store_x, coin_x_withdrawn);

            primary_fungible_store::ensure_primary_store_exists(signer::address_of(lp_provider), token_2);
            let store_y = primary_fungible_store::primary_store(signer::address_of(lp_provider), token_2);
            fungible_asset::deposit(store_y, coin_y_withdrawn);

            // Burn the corresponding amount of LP tokens
            let lp_store = ensure_lp_token_store( pool_config, signer::address_of(lp_provider));
            fungible_asset::burn_from(&pool_config.lp_burn, lp_store, lp_amount);

            // Emit an event
            event::emit(RemovedLiquidity { pool_name: lp_name,  lp_in: lp_amount, token_1: fungible_asset::symbol(token_1), token_2: fungible_asset::symbol(token_2), token_1_out: coin_x_out , token_2_out: coin_y_out  });
        };

    }

    // ======== Public Functions =========

    // Retrieve the current weights of the pool
    public fun pool_current_weight(pool: &Pool ): (u64, u64)  {
        ( pool.weight_1, pool.weight_2 )
    }

    public fun get_mut_pool(pool_list: &mut Table<String, Pool>,  token_1: Object<Metadata>, token_2: Object<Metadata>): &mut Pool {
        let is_order = is_order(token_1, token_2);

        if (is_order) {
            let (lp_name, _) = generate_lp_name_and_symbol(token_1, token_2);
            assert!( table::contains( pool_list, lp_name ) , ERR_POOL_NOT_REGISTER);
            table::borrow_mut( pool_list, lp_name )
        } else {
            let (lp_name, _) = generate_lp_name_and_symbol(token_2, token_1);
            assert!(  table::contains( pool_list, lp_name ) , ERR_POOL_NOT_REGISTER);
            table::borrow_mut( pool_list, lp_name )
        } 
    }

    // Calculate amounts needed for adding new liquidity for both `X` and `Y`.
    public fun calc_optimal_coin_values( 
        pool: &Pool,
        token_1_desired: u64,
        token_2_desired: u64,
        token_1_min: u64,
        token_2_min: u64
    ) : (u64, u64, bool)  {

        let reserves_1 = fungible_asset::balance(pool.token_1);
        let reserves_2 = fungible_asset::balance(pool.token_2);

        if (reserves_1 == 0 && reserves_2 == 0) {
            return (token_1_desired, token_2_desired, true)
        } else {

            let (weight_1, weight_2 ) = pool_current_weight(pool);
            let token_2_needed = weighted_math::compute_optimal_value(token_1_desired, reserves_2, weight_2, reserves_1, weight_1 );

            if (token_2_needed <= token_2_desired) {
                assert!(token_2_needed >= token_2_min, ERR_INSUFFICIENT_COIN_Y);
                return (token_1_desired, token_2_needed, false)
            } else {
                let token_1_needed =  weighted_math::compute_optimal_value(token_2_desired, reserves_1, weight_1, reserves_2, weight_2);
                assert!(token_1_needed <= token_1_desired, ERR_OVERLIMIT);
                assert!(token_1_needed >= token_1_min, ERR_INSUFFICIENT_COIN_X);
                return (token_1_needed, token_2_desired, false)
            }

        }
 
    }

    public fun swap_out_non_entry( 
        sender: &signer, 
        token_1: Object<Metadata>,
        token_2: Object<Metadata>,
        token_in: u64,
        token_out_min: u64,
        is_order: bool
    ) : FungibleAsset acquires AMMGlobal {
        assert!(primary_fungible_store::balance(signer::address_of(sender), token_1) >= token_in, ERR_INSUFFICIENT_AMOUNT );

        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);

        let pool_config = get_mut_pool( &mut config.pools,  token_1, token_2);

        assert!(!pool_config.has_paused, ERR_PAUSED );

        if (is_order) {
            
            let reserve_in = fungible_asset::balance(pool_config.token_1);
            let reserve_out = fungible_asset::balance(pool_config.token_2);
            assert!(reserve_in > 0 && reserve_out > 0, ERR_RESERVES_EMPTY);

            let (coin_x_after_fees, coin_x_fee) = weighted_math::get_fee_to_treasury( pool_config.swap_fee , token_in);

            // Obtain the current weights of the pool
            let (weight_in, weight_out) = pool_current_weight(pool_config);

            let token_2_out = get_amount_out( 
                coin_x_after_fees,
                reserve_in,
                weight_in, 
                reserve_out,
                weight_out
            );

            assert!(
                token_2_out >= token_out_min,
                ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
            );

            let token_in_coin = primary_fungible_store::withdraw(sender, token_1, token_in);
            let fee_in_coin = fungible_asset::extract(&mut token_in_coin, coin_x_fee);

            fungible_asset::deposit(pool_config.token_1, token_in_coin);

            // send fees to treasury
            primary_fungible_store::ensure_primary_store_exists(config.treasury_address, token_1);
            let store = primary_fungible_store::primary_store(config.treasury_address, token_1);
            fungible_asset::deposit(store, fee_in_coin);

            // send out token-2
            fungible_asset::withdraw(&config_object_signer, pool_config.token_2, token_2_out)

        } else {

            let reserve_in = fungible_asset::balance(pool_config.token_2);
            let reserve_out = fungible_asset::balance(pool_config.token_1);
            assert!(reserve_in > 0 && reserve_out > 0, ERR_RESERVES_EMPTY);

            let (coin_y_after_fees, coin_y_fee) =  weighted_math::get_fee_to_treasury( pool_config.swap_fee , token_in);

            // Obtain the current weights of the pool
            let (weight_out, weight_in) = pool_current_weight(pool_config);

            let token_2_out = get_amount_out( 
                coin_y_after_fees,
                reserve_in,
                weight_in,
                reserve_out,
                weight_out
            );

            assert!(
                token_2_out >= token_out_min,
                ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
            );

            let token_in_coin = primary_fungible_store::withdraw(sender, token_1, token_in);
            let fee_in_coin = fungible_asset::extract(&mut token_in_coin, coin_y_fee);

            fungible_asset::deposit(pool_config.token_2, token_in_coin);

            // send fees to treasury
            primary_fungible_store::ensure_primary_store_exists(config.treasury_address, token_1);
            let store = primary_fungible_store::primary_store(config.treasury_address, token_1);
            fungible_asset::deposit(store, fee_in_coin);

            // send out token-2
            fungible_asset::withdraw(&config_object_signer, pool_config.token_1, token_2_out)
        }

    }



    #[view]
    public fun is_order(token_1: Object<Metadata>, token_2: Object<Metadata>): bool {
        let token_1_addr = object::object_address(&token_1);
        let token_2_addr = object::object_address(&token_2);
        comparator::is_smaller_than(&comparator::compare(&token_1_addr, &token_2_addr))
    }

    #[view]
    public fun get_config_object_address(): address acquires AMMGlobal {
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        signer::address_of(&config_object_signer)
    }

    #[view]
    public fun get_lp_metadata(token_1: Object<Metadata>, token_2: Object<Metadata>): Object<Metadata> acquires AMMGlobal {
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        let pool = get_mut_pool( &mut config.pools, token_1, token_2);
        pool.lp_metadata
    }

    #[view]
    public fun get_treasury_address(): address acquires AMMGlobal {
        let config = borrow_global<AMMGlobal>(@legato_amm_addr);
        config.treasury_address
    }

    #[view]
    public fun get_reserves(token_1: Object<Metadata>, token_2: Object<Metadata>) : (u64, u64)  acquires AMMGlobal {
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        let pool_config = get_mut_pool( &mut config.pools, token_1, token_2);
        let is_order = is_order(token_1, token_2);

        if (is_order) {
            (fungible_asset::balance(pool_config.token_1), fungible_asset::balance(pool_config.token_2))
        } else {
            (fungible_asset::balance(pool_config.token_2), fungible_asset::balance(pool_config.token_1))
        }
    }

    // ======== Only Governance =========

    // Adds a user to the whitelist
    public entry fun add_whitelist(sender: &signer, whitelist_address: address) acquires AMMGlobal {
        assert!( signer::address_of(sender) == @legato_amm_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        assert!( !vector::contains(&config.whitelist, &whitelist_address) , ERR_INVALID_ADDRESS);
        vector::push_back(&mut config.whitelist, whitelist_address);
    }

    // Removes a user from the whitelist
    public entry fun remove_whitelist(sender: &signer, whitelist_address: address) acquires AMMGlobal {
        assert!( signer::address_of(sender) == @legato_amm_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        let (found, idx) = vector::index_of<address>(&config.whitelist, &whitelist_address);
        assert!(  found , ERR_INVALID_ADDRESS);
        vector::swap_remove<address>(&mut config.whitelist, idx );
    }

    // Update treasury address
    public entry fun update_treasury_address(sender: &signer, new_address: address) acquires AMMGlobal {
        assert!( signer::address_of(sender) == @legato_amm_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        config.treasury_address = new_address;
    }

    // Enable or disable whitelist requirement
    public entry fun enable_whitelist(sender: &signer, is_enable: bool) acquires AMMGlobal {
        assert!( signer::address_of(sender) == @legato_amm_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        config.enable_whitelist = is_enable;
    }

    // Updates the swap fee for the specified pool
    public entry fun update_pool_fee(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>, fee_numerator: u128, fee_denominator: u128) acquires AMMGlobal {
        assert!( signer::address_of(sender) == @legato_amm_addr , ERR_UNAUTHORIZED);
        
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        let pool_config = get_mut_pool( &mut config.pools,  token_1, token_2 );
        pool_config.swap_fee = fixed_point64::create_from_rational( fee_numerator, fee_denominator );
    }

    // Pause/Unpause the LP pool
    public entry fun pause(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>, is_pause: bool) acquires AMMGlobal {
        assert!( signer::address_of(sender) == @legato_amm_addr , ERR_UNAUTHORIZED);
        
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        let pool_config = get_mut_pool( &mut config.pools,  token_1, token_2 );
        pool_config.has_paused = is_pause
    }

    // Inactivate LP pool by moving to the archive
    public entry fun move_to_archive(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>) acquires AMMGlobal {
        assert!( signer::address_of(sender) == @legato_amm_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMGlobal>(@legato_amm_addr);
        
        let lp_name = if (is_order(token_1, token_2)) {
            let (name, _) = generate_lp_name_and_symbol(token_1, token_2);
            name
        } else {
            let (name, _) = generate_lp_name_and_symbol(token_2, token_1);
            name
        };

        assert!( table::contains( &config.pools, lp_name ), ERR_POOL_NOT_REGISTER);
        let pool = table::remove( &mut config.pools, lp_name );
        table::add( &mut config.archives, lp_name, pool );

    }
    
    // ======== Internal Functions =========

    fun generate_lp_name_and_symbol(token_1: Object<Metadata>, token_2: Object<Metadata>):  (String, String) {
        let lp_name = string::utf8(b"");
        string::append_utf8(&mut lp_name, b"LP-");
        string::append(&mut lp_name, fungible_asset::symbol(token_1));
        string::append_utf8(&mut lp_name, b"-");
        string::append(&mut lp_name, fungible_asset::symbol(token_2));

        let lp_symbol = string::utf8(b"");
        string::append(&mut lp_symbol, fungible_asset::symbol(token_1));
        string::append_utf8(&mut lp_symbol, b"-");
        string::append(&mut lp_symbol, fungible_asset::symbol(token_2));

        (lp_name, lp_symbol)
    }

    fun check_routes( routes: &vector<Route> ) acquires AMMGlobal  {

        let config = borrow_global<AMMGlobal>(@legato_amm_addr);

        let pool_count = 0;

        while (pool_count < vector::length( routes )) {
            let route = vector::borrow( routes, pool_count );
            assert!( table::contains( &config.pools, route.pool_name ) , ERR_POOL_NOT_REGISTER);
            let pool_config = table::borrow( &config.pools, route.pool_name );
            assert!(!pool_config.has_paused , ERR_PAUSED );
            pool_count = pool_count+1;
        };
        
    }

    fun init_pool_params(constructor_ref: &ConstructorRef, token_1: Object<Metadata>, token_2: Object<Metadata>, weight_1: u64, weight_2: u64, swap_fee: FixedPoint64) : Pool {
        
        // Ensure that the normalized weights sum up to 100%
        assert!( weight_1+weight_2 == 10000, ERR_WEIGHTS_SUM); 

        let pool_signer = &object::generate_signer(constructor_ref);

        let lp_mint = fungible_asset::generate_mint_ref(constructor_ref);
        let lp_burn = fungible_asset::generate_burn_ref(constructor_ref);
        let lp_transfer = fungible_asset::generate_transfer_ref(constructor_ref);
        let lp_metadata = object::object_from_constructor_ref<Metadata>(constructor_ref);
 
        Pool { 
            token_1: create_token_store(pool_signer, token_1) ,
            token_2: create_token_store(pool_signer, token_2),
            weight_1,
            weight_2,
            min_liquidity: create_token_store(pool_signer, lp_metadata),
            swap_fee,
            lp_mint,
            lp_burn,
            lp_transfer,
            lp_metadata, 
            has_paused: false
        }
    }

    // Mint LP tokens
    fun mint_lp(pool_config: &mut Pool, fungible_asset_1: FungibleAsset, fungible_asset_2: FungibleAsset) : FungibleAsset {

        assert!(!pool_config.has_paused , ERR_PAUSED );
        
        let amount_1 = fungible_asset::amount(&fungible_asset_1);
        let amount_2 = fungible_asset::amount(&fungible_asset_2);

        // Retrieves total LP coins supply
        let lp_token_supply = option::destroy_some(fungible_asset::supply(pool_config.lp_metadata));
        let reserve_1 = fungible_asset::balance(pool_config.token_1);
        let reserve_2 = fungible_asset::balance(pool_config.token_2);

        // Computes provided liquidity
        let provided_liq = calculate_provided_liq( pool_config, (lp_token_supply as u64), reserve_1, reserve_2, amount_1, amount_2  );

        // Deposit the received liquidity into the pool.
        fungible_asset::deposit(pool_config.token_1, fungible_asset_1);
        fungible_asset::deposit(pool_config.token_2, fungible_asset_2);
        
        fungible_asset::mint(&pool_config.lp_mint, provided_liq)
    }

    // Calculates the provided liquidity based on the current LP supply and reserves.
    fun calculate_provided_liq(pool_config: &mut Pool, lp_supply: u64, coin_x_reserve: u64, coin_y_reserve: u64, optimal_coin_x: u64, optimal_coin_y: u64): u64 {
 
        // Obtain the current weights of the pool
        let (weight_1, weight_2 ) = pool_current_weight(pool_config);

        if (0 == lp_supply) {

            let initial_liq = weighted_math::compute_initial_lp( weight_1, weight_2 , optimal_coin_x , optimal_coin_y  );
            assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

            let lp_tokens = fungible_asset::mint(&pool_config.lp_mint, MINIMAL_LIQUIDITY);

            fungible_asset::deposit(pool_config.min_liquidity, lp_tokens);

            initial_liq - MINIMAL_LIQUIDITY
        } else {
            weighted_math::compute_derive_lp( optimal_coin_x, optimal_coin_y, weight_1, weight_2, coin_x_reserve, coin_y_reserve, lp_supply )
        }
        
    }

    fun get_amount_out(  coin_in: u64, reserve_in: u64, weight_in: u64, reserve_out: u64, weight_out: u64) : u64 {
        weighted_math::get_amount_out(
            coin_in,
            reserve_in,
            weight_in, 
            reserve_out,
            weight_out, 
        )
    }

    fun ensure_lp_token_store(pool_config: &Pool, lp: address ): Object<FungibleStore> {
        primary_fungible_store::ensure_primary_store_exists(lp,  pool_config.lp_metadata);
        let store = primary_fungible_store::primary_store(lp,  pool_config.lp_metadata);
        if (!fungible_asset::is_frozen(store)) {
            // LPs must call transfer here to transfer the LP tokens so claimable fees can be updated correctly.
            fungible_asset::set_frozen_flag(&pool_config.lp_transfer, store, true);
        };
        store
    }

    inline fun create_token_store(pool_signer: &signer, token: Object<Metadata>): Object<FungibleStore> {
        let constructor_ref = &object::create_object_from_object(pool_signer);
        fungible_asset::create_store(constructor_ref, token)
    }

    fun extract_routes(path: vector<Object<Metadata>>): vector<Route> {

        let output = vector::empty<Route>();
        let pool_count = 0;

        while ( pool_count < (vector::length( &path )-1) ) {
            
            let token_1 = *vector::borrow( &path, pool_count );
            let token_2 = *vector::borrow( &path, pool_count+1);
            let is_order = is_order(token_1, token_2);

            let (lp_name, _) = if (is_order) {
                generate_lp_name_and_symbol(token_1, token_2)
            } else {
                generate_lp_name_and_symbol(token_2, token_1)
            };

            vector::push_back( &mut output, Route {
                token_1,
                token_2,
                pool_name: lp_name,
                is_order
            });

            pool_count = pool_count+1;
        };

        output
    }

    // ======== Test-related Functions =========

    #[test_only] 
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }
}