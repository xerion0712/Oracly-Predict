// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// A custom weight DEX for trading tokens to tokens including vault tokens
// Allows setup of various types of pools - weighted pool, stable pool and LBP pool
// Forked from OmniBTC AMM Swap and improved with math from Balancer V2 Lite
// Supports only FA asset

module legato_addr::amm {

    use std::signer;  
    use std::string::{Self, String, utf8, bytes }; 
    use std::option::{Self, Option};

    use aptos_framework::event;
    use aptos_framework::fungible_asset::{
        Self, FungibleAsset, FungibleStore, Metadata,
        BurnRef, MintRef, TransferRef,
    };
    use aptos_framework::object::{Self, ConstructorRef, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use aptos_std::comparator;
    use aptos_std::math128;
    use aptos_std::math64;
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_std::table::{Self, Table};
    use aptos_std::fixed_point64::{Self, FixedPoint64}; 

    use legato_addr::base_fungible_asset;
    use legato_addr::stable_math;
    use legato_addr::weighted_math;
    use legato_addr::lbp::{Self, LBPParams};

    // ======== Constants ========

    // Default swap fee of 0.5% in fixed-point
    const DEFAULT_FEE: u128 = 92233720368547758; 
    // 0.25% for LBP
    const LBP_FEE: u128 = 46116860184273879;
    // 0.1% for stable pools
    const STABLE_FEE: u128 = 18446744073709551;
    // Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000; 
    // Max u64 value.
    const U64_MAX: u64 = 18446744073709551615;

    const WEIGHT_SCALE: u64 = 10000; 
    
    const LP_TOKEN_DECIMALS: u8 = 8;
    // The max value that can be held in one of the Balances of
    /// a Pool. U64 MAX / WEIGHT_SCALE
    const MAX_POOL_VALUE : u64 = 18446744073709551615;

    // ======== Errors ========

    const ERR_UNAUTHORIZED: u64 = 101;
    const ERR_POOL_HAS_REGISTERED: u64 = 102;
    const ERR_WEIGHTS_SUM: u64 = 103;
    const ERR_POOL_NOT_REGISTER: u64 = 104;
    const ERR_INVALID_ADDRESS: u64 = 105;
    const ERR_NOT_LBP: u64 = 106;
    const ERR_OVERLIMIT: u64 = 107;
    const ERR_INSUFFICIENT_COIN_X: u64 = 108;
    const ERR_INSUFFICIENT_COIN_Y: u64 = 109;
    const ERR_PAUSED: u64 = 110;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 111;
    const ERR_U64_OVERFLOW: u64 = 112;
    const ERR_POOL_FULL: u64 = 113;
    const ERR_ZERO_AMOUNT: u64 = 114;
    const ERR_INSUFFICIENT_AMOUNT: u64 = 115;
    const ERR_RESERVES_EMPTY: u64 = 116;
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 117;

    // ======== Structs =========

    // Liquidity pool with custom weighting 
    struct Pool has store {
        token_1: Object<FungibleStore>,
        token_2: Object<FungibleStore>,
        weight_1: u64, // 50% using 5000
        weight_2: u64, // 50% using 5000
        min_liquidity: Object<FungibleStore>,
        swap_fee: FixedPoint64,
        lp_mint: MintRef,
        lp_burn: BurnRef,
        lp_transfer: TransferRef,
        lp_metadata: Object<Metadata>,
        lbp_params: Option<LBPParams>, // Params for a LBP pool
        has_paused: bool,
        is_stable: bool, // Indicates if the pool is a stable pool
        is_lbp: bool, // Indicates if the pool is a LBP
    }

    // Represents the global state of the AMM. 
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct AMMManager has key { 
        pool_list: Table<String, Pool>,
        whitelist: SmartVector<address>, // who can setup a new pool
        extend_ref: ExtendRef,
        enable_whitelist: bool,
        treasury_address: address // where all fees from all pools will be sent for further LP staking
    }

     #[event]
    /// Event emitted when a pool is created.
    struct RegisterPool has drop, store { 
        pool_name: String,
        token_1: String,
        token_2: String,
        weight_1: u64,
        weight_2: u64,
        is_stable: bool,
        is_lbp: bool
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
    struct Swapped has drop, store {
        pool_name: String,
        token_in: String,
        token_out: String,
        amount_in: u64,
        amount_out: u64
    }

    // Constructor for this module.
    fun init_module(sender: &signer) {
        
        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        let whitelist = smart_vector::new();
        smart_vector::push_back(&mut whitelist, signer::address_of(sender));

        move_to(sender, AMMManager { 
            whitelist, 
            pool_list: table::new<String, Pool>(),
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
    )   acquires AMMManager  {

        let is_order = is_order(token_1, token_2);

        let token_out = swap_out_non_entry(
            sender,
            token_1,
            token_2,
            token_in,
            token_out_min,
            is_order
        );

        let amount_out = fungible_asset::amount(&token_out);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let pool_config = get_mut_pool( &mut config.pool_list, token_1, token_2);

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

    // Register a new liquidity pool with custom weights
    public entry fun register_pool(
        sender: &signer, 
        token_1: Object<Metadata>,
        token_2: Object<Metadata>,
        weight_1: u64,
        weight_2: u64
    )  acquires AMMManager {
        
        let is_order = is_order(token_1, token_2);

        if (!is_order) {
            register_pool(sender, token_2, token_1, weight_2, weight_1);
        } else {

            let config = borrow_global_mut<AMMManager>(@legato_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
            if (config.enable_whitelist) {
                // Ensure that the caller is on the whitelist
                assert!( smart_vector::contains(&config.whitelist, &(signer::address_of(sender))) , ERR_UNAUTHORIZED);
            };

            let (lp_name, lp_symbol) = generate_lp_name_and_symbol(token_1, token_2);

            assert!( !table::contains(&config.pool_list, lp_name), ERR_POOL_HAS_REGISTERED);

            let constructor_ref = &object::create_named_object(&config_object_signer, *bytes(&lp_symbol) );
        
            base_fungible_asset::initialize(
                constructor_ref,
                0, /* maximum_supply. 0 means no maximum */
                lp_name, /* name */
                lp_symbol, /* symbol */
                8, /* decimals */
                utf8(b"https://www.legato.finance/assets/images/favicon.ico"), /* icon */
                utf8(b"https://legato.finance"), /* project */
            );

            let pool = init_pool_params(constructor_ref, token_1, token_2, weight_1, weight_2, fixed_point64::create_from_raw_value( DEFAULT_FEE ), false, false, option::none() );

            // Add to the table.
            table::add(
                &mut config.pool_list,
                lp_name,
                pool
            );

             // Emit an event
            event::emit(RegisterPool { pool_name: lp_name, token_1 : fungible_asset::symbol(token_1), token_2 : fungible_asset::symbol(token_2),  weight_1, weight_2, is_stable: false,  is_lbp: false });

        };
    
    }

    // Register a stable pool, weights are fixed at 50/50
    public entry fun register_stable_pool(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>) acquires AMMManager {
        
        let is_order = is_order(token_1, token_2);

        if (!is_order) {
            register_stable_pool(sender, token_2, token_1);
        } else {

            let config = borrow_global_mut<AMMManager>(@legato_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
            if (config.enable_whitelist) {
                // Ensure that the caller is on the whitelist
                assert!( smart_vector::contains(&config.whitelist, &(signer::address_of(sender))) , ERR_UNAUTHORIZED);
            };

            let (lp_name, lp_symbol) = generate_lp_name_and_symbol(token_1, token_2);

            assert!( !table::contains(&config.pool_list, lp_name), ERR_POOL_HAS_REGISTERED);

            let constructor_ref = &object::create_named_object(&config_object_signer, *bytes(&lp_symbol) );
        
            base_fungible_asset::initialize(
                constructor_ref,
                0, /* maximum_supply. 0 means no maximum */
                lp_name, /* name */
                utf8(b"LP"), /* symbol */
                8, /* decimals */
                utf8(b"https://www.legato.finance/assets/images/favicon.ico"), /* icon */
                utf8(b"https://legato.finance"), /* project */
            );

            let pool = init_pool_params(constructor_ref, token_1, token_2, 5000, 5000, fixed_point64::create_from_raw_value( STABLE_FEE ), true, false, option::none() );

            // Add to the table.
            table::add(
                &mut config.pool_list,
                lp_name,
                pool
            );

             // Emit an event
            event::emit(RegisterPool { pool_name: lp_name, token_1 : fungible_asset::symbol(token_1), token_2 : fungible_asset::symbol(token_2),  weight_1 : 5000, weight_2 : 5000, is_stable: true,  is_lbp: false });

        };

    }

    // Register an LBP pool, project token weights must be greater than 50%.
    // is_vault specifies if staking rewards from Legato Vault are accepted
    public entry fun register_lbp_pool(
        sender: &signer,
        token_1: Object<Metadata>,
        start_weight: u64,  // Initial weight of the project token.
        final_weight: u64, // The weight when the pool is stabilized. 
        is_vault: bool, // false - only common coins, true - coins+staking rewards.
        target_amount: u64, // The target amount required to fully shift the weight.
    ) acquires AMMManager {

        let metadata = object::address_to_object<Metadata>(@aptos_fungible_asset);
        let is_order = is_order(token_1, metadata);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        if (config.enable_whitelist) {
            // Ensure that the caller is on the whitelist
            assert!( smart_vector::contains(&config.whitelist, &(signer::address_of(sender))) , ERR_UNAUTHORIZED);
        };

        if (is_order) {
            let proj_on_x = true; // Indicates whether the project token is on the X or Y side

            let (lp_name, lp_symbol) = generate_lp_name_and_symbol(token_1, metadata);
            assert!( !table::contains(&config.pool_list, lp_name), ERR_POOL_HAS_REGISTERED);

            let constructor_ref = &object::create_named_object(&config_object_signer, *bytes(&lp_symbol) );
        
            base_fungible_asset::initialize(
                constructor_ref,
                0, /* maximum_supply. 0 means no maximum */
                lp_name, /* name */
                lp_symbol, /* symbol */
                8, /* decimals */
                utf8(b"https://www.legato.finance/assets/images/favicon.ico"), /* icon */
                utf8(b"https://legato.finance"), /* project */
            );

            let params = lbp::construct_init_params( proj_on_x, start_weight, final_weight, is_vault, target_amount );

            let pool = init_pool_params(constructor_ref, token_1, metadata, 0, 0, fixed_point64::create_from_raw_value( LBP_FEE ), false, true, option::some<LBPParams>(params)  );

            // Add to the table.
            table::add(
                &mut config.pool_list,
                lp_name,
                pool
            );

            // Emit an event
            event::emit(RegisterPool { pool_name: lp_name, token_1 : fungible_asset::symbol(token_1), token_2 : fungible_asset::symbol(metadata),  weight_1: start_weight, weight_2: final_weight, is_stable: false,  is_lbp: true });

        } else {
            let proj_on_x = false;

            let (lp_name, lp_symbol) = generate_lp_name_and_symbol(metadata, token_1);
            assert!( !table::contains(&config.pool_list, lp_name), ERR_POOL_HAS_REGISTERED);

            let constructor_ref = &object::create_named_object(&config_object_signer, *bytes(&lp_symbol) );
        
            base_fungible_asset::initialize(
                constructor_ref,
                0, /* maximum_supply. 0 means no maximum */
                lp_name, /* name */
                lp_symbol, /* symbol */
                8, /* decimals */
                utf8(b"https://www.legato.finance/assets/images/favicon.ico"), /* icon */
                utf8(b"https://legato.finance"), /* project */
            );

            let params = lbp::construct_init_params( proj_on_x, start_weight, final_weight, is_vault, target_amount );

            let pool = init_pool_params(constructor_ref, metadata, token_1, 0, 0, fixed_point64::create_from_raw_value( LBP_FEE ), false, true, option::some<LBPParams>(params)  );

            // Add to the table.
            table::add(
                &mut config.pool_list,
                lp_name,
                pool
            );

            // Emit an event
            event::emit(RegisterPool { pool_name: lp_name, token_1 : fungible_asset::symbol(metadata), token_2 : fungible_asset::symbol(token_1),  weight_1: start_weight, weight_2: final_weight, is_stable: false,  is_lbp: true });

        }

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
    ) acquires AMMManager {

        let is_order = is_order(token_1, token_2);

        if (!is_order) {
            add_liquidity( lp_provider, token_2, token_1, coin_y_amount, coin_y_min, coin_x_amount, coin_x_min );
        } else {

            let config = borrow_global_mut<AMMManager>(@legato_addr);
            let (lp_name, _) = generate_lp_name_and_symbol(token_1, token_2);
            assert!( table::contains( &config.pool_list, lp_name ) , ERR_POOL_NOT_REGISTER);

            let pool_config = table::borrow_mut( &mut config.pool_list, lp_name );

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

            let lp_tokens = mint_lp( 
                pool_config,
                optimal_1,
                optimal_2
            );

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
    public entry fun remove_liquidity(lp_provider: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>,  lp_amount: u64) acquires AMMManager {

        let is_order = is_order(token_1, token_2);

        if (!is_order) {
            remove_liquidity( lp_provider, token_2, token_1, lp_amount );
        } else {

            let config = borrow_global_mut<AMMManager>(@legato_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
            let (lp_name, _) = generate_lp_name_and_symbol(token_1, token_2);
            assert!( table::contains( &config.pool_list, lp_name ) , ERR_POOL_NOT_REGISTER);

            let pool_config = table::borrow_mut( &mut config.pool_list, lp_name );
            assert!(!pool_config.has_paused , ERR_PAUSED );

            let coin_x_out = 0;
            let coin_y_out = 0;

            let lp_token_supply = option::destroy_some(fungible_asset::supply(pool_config.lp_metadata));
            let reserve_1 = fungible_asset::balance(pool_config.token_1);
            let reserve_2 = fungible_asset::balance(pool_config.token_2);

            if (!pool_config.is_stable) {
                
                let (weight_1, weight_2 ) = pool_current_weight(pool_config);

                (coin_x_out, coin_y_out) = weighted_math::compute_withdrawn_coins( 
                    lp_amount, 
                    (lp_token_supply as u64), 
                    reserve_1, 
                    reserve_2, 
                    weight_1, 
                    weight_2
                ); 

                let coin_x_withdrawn = fungible_asset::withdraw(&config_object_signer, pool_config.token_1, coin_x_out);
                let coin_y_withdrawn = fungible_asset::withdraw(&config_object_signer, pool_config.token_2, coin_y_out);

                primary_fungible_store::ensure_primary_store_exists(signer::address_of(lp_provider), token_1);
                let store_x = primary_fungible_store::primary_store(signer::address_of(lp_provider), token_1);
                fungible_asset::deposit(store_x, coin_x_withdrawn);

                primary_fungible_store::ensure_primary_store_exists(signer::address_of(lp_provider), token_2);
                let store_y = primary_fungible_store::primary_store(signer::address_of(lp_provider), token_2);
                fungible_asset::deposit(store_y, coin_y_withdrawn);

            } else {

                let multiplier = fixed_point64::create_from_rational( (lp_amount as u128), (lp_token_supply as u128)  );
 
                coin_x_out = (fixed_point64::multiply_u128( (reserve_1 as u128), multiplier ) as u64); 
                coin_y_out = (fixed_point64::multiply_u128( (reserve_2 as u128), multiplier ) as u64);

                let coin_x_withdrawn = fungible_asset::withdraw(&config_object_signer, pool_config.token_1, coin_x_out);
                let coin_y_withdrawn = fungible_asset::withdraw(&config_object_signer, pool_config.token_2, coin_y_out);

                primary_fungible_store::ensure_primary_store_exists(signer::address_of(lp_provider), token_1);
                let store_x = primary_fungible_store::primary_store(signer::address_of(lp_provider), token_1);
                fungible_asset::deposit(store_x, coin_x_withdrawn);

                primary_fungible_store::ensure_primary_store_exists(signer::address_of(lp_provider), token_2);
                let store_y = primary_fungible_store::primary_store(signer::address_of(lp_provider), token_2);
                fungible_asset::deposit(store_y, coin_y_withdrawn);

            };

            let lp_store = ensure_lp_token_store( pool_config, signer::address_of(lp_provider));
            fungible_asset::burn_from(&pool_config.lp_burn, lp_store, lp_amount);

            // Emit an event
            // event::emit(RemovedLiquidity { pool_name: lp_name, coin_x : coin::symbol<X>(), coin_y : coin::symbol<Y>(), lp_in: lp_amount, coin_x_out, coin_y_out });
        };

    }

    
    // ======== Public Functions =========

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

    #[view]
    public fun is_order(token_1: Object<Metadata>, token_2: Object<Metadata>): bool {
        let token_1_addr = object::object_address(&token_1);
        let token_2_addr = object::object_address(&token_2);
        comparator::is_smaller_than(&comparator::compare(&token_1_addr, &token_2_addr))
    }

    #[view]
    public fun get_config_object_address(): address acquires AMMManager {
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        signer::address_of(&config_object_signer)
    }

    #[view]
    public fun get_treasury_address(): address acquires AMMManager {
        let config = borrow_global<AMMManager>(@legato_addr);
        config.treasury_address
    }

    #[view]
    public fun get_lp_metadata(token_1: Object<Metadata>, token_2: Object<Metadata>): Object<Metadata> acquires AMMManager {
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let pool = get_mut_pool( &mut config.pool_list, token_1, token_2);
        pool.lp_metadata
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

            // For non-stable pools, use weighted math to compute optimal values.
            if (!pool.is_stable) {

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

            } else {

                // For stable pools, use stable math to compute the optimal values.
                let token_2_returned = stable_math::get_amount_out(
                    token_1_desired,
                    reserves_1, 
                    reserves_2
                );

                if (token_2_returned <= token_2_desired) {
                    assert!(token_2_returned >= token_2_min, ERR_INSUFFICIENT_COIN_Y);
                    return (token_1_desired, token_2_returned, false)
                } else {
                    let token_1_returned = stable_math::get_amount_out(
                        token_2_desired,
                        reserves_2, 
                        reserves_1
                    );

                    assert!(token_1_returned <= token_1_desired, ERR_OVERLIMIT);
                    assert!(token_1_returned >= token_1_min, ERR_INSUFFICIENT_COIN_X);
                    return (token_1_returned, token_2_desired, false) 
                }

            }

        }
 
    }

    // Retrieve the current weights of the pool
    public fun pool_current_weight(pool: &Pool ): (u64, u64)  {
        
        if (!pool.is_lbp) {
            ( pool.weight_1, pool.weight_2 )
        } else {
            let params = option::borrow(&pool.lbp_params);
            lbp::current_weight( params ) 
        }

    }
    

    public fun swap_out_non_entry( 
        sender: &signer, 
        token_1: Object<Metadata>,
        token_2: Object<Metadata>,
        token_in: u64,
        token_out_min: u64,
        is_order: bool
    ) : FungibleAsset acquires AMMManager {
        assert!(primary_fungible_store::balance(signer::address_of(sender), token_1) >= token_in, ERR_INSUFFICIENT_AMOUNT );

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);

        let pool_config = get_mut_pool( &mut config.pool_list,  token_1, token_2);

        assert!(!pool_config.has_paused , ERR_PAUSED );

        if (is_order) {

            let reserve_in = fungible_asset::balance(pool_config.token_1);
            let reserve_out = fungible_asset::balance(pool_config.token_2);
            assert!(reserve_in > 0 && reserve_out > 0, ERR_RESERVES_EMPTY);

            let (coin_x_after_fees, coin_x_fee) = weighted_math::get_fee_to_treasury( pool_config.swap_fee , token_in);

            // Obtain the current weights of the pool
            let (weight_in, weight_out) = pool_current_weight(pool_config);

            let token_2_out = get_amount_out(
                pool_config.is_stable,
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

            if (pool_config.is_lbp) {
                let params = option::borrow_mut(&mut pool_config.lbp_params);
                let is_buy = lbp::is_buy(params);  
                lbp::verify_and_adjust_amount(params, is_buy, token_in, token_2_out, false );
            };

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
                pool_config.is_stable,
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

            if (pool_config.is_lbp) {
                let params = option::borrow_mut(&mut pool_config.lbp_params);
                let is_buy = lbp::is_buy(params);   
                lbp::verify_and_adjust_amount(params, !is_buy, token_in, token_2_out, false);
            };

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

    // ======== Only Governance =========

    // Adds a user to the whitelist
    public entry fun add_whitelist(sender: &signer, whitelist_address: address) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        assert!( !smart_vector::contains(&config.whitelist, &whitelist_address) , ERR_INVALID_ADDRESS);
        smart_vector::push_back(&mut config.whitelist, whitelist_address);
    }

    // Removes a user from the whitelist
    public entry fun remove_whitelist(sender: &signer, whitelist_address: address) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (found, idx) = smart_vector::index_of<address>(&config.whitelist, &whitelist_address);
        assert!(  found , ERR_INVALID_ADDRESS);
        smart_vector::swap_remove<address>(&mut config.whitelist, idx );
    }

    // Update treasury address
    public entry fun update_treasury_address(sender: &signer, new_address: address) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        config.treasury_address = new_address;
    }

    // Enable or disable whitelist requirement
    public entry fun enable_whitelist(sender: &signer, is_enable: bool) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        config.enable_whitelist = is_enable;
    }

    // Updates the swap fee for the specified pool
    public entry fun update_pool_fee(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>, fee_numerator: u128, fee_denominator: u128) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let pool_config = get_mut_pool( &mut config.pool_list,  token_1, token_2 );
        pool_config.swap_fee = fixed_point64::create_from_rational( fee_numerator, fee_denominator );
    }

    // Pause/Unpause the LP pool
    public entry fun pause(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>, is_pause: bool) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let pool_config = get_mut_pool( &mut config.pool_list,  token_1, token_2 );
        pool_config.has_paused = is_pause
    }

    // Set a new target amount for LBP
    public entry fun lbp_set_target_amount(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>, new_target_amount: u64) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let pool_config = get_mut_pool( &mut config.pool_list,  token_1, token_2 );

        assert!( pool_config.is_lbp , ERR_NOT_LBP);

        let params = option::borrow_mut(&mut pool_config.lbp_params);
        lbp::set_new_target_amount(  params, new_target_amount );
    }

    // Enable/Disable buy with pair or with vault tokens
    public entry fun lbp_enable_buy_with_pair_and_vault(sender: &signer, token_1: Object<Metadata>, token_2: Object<Metadata>, enable_pair: bool, enable_vault: bool) acquires AMMManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let pool_config = get_mut_pool( &mut config.pool_list,  token_1, token_2 );

        assert!( pool_config.is_lbp , ERR_NOT_LBP);

        let params = option::borrow_mut(&mut pool_config.lbp_params);

        lbp::enable_buy_with_pair(  params, enable_pair );
        lbp::enable_buy_with_vault(  params, enable_vault );
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

    fun init_pool_params(constructor_ref: &ConstructorRef, token_1: Object<Metadata>, token_2: Object<Metadata>, weight_1: u64, weight_2: u64, swap_fee: FixedPoint64, is_stable: bool, is_lbp: bool, lbp_params: Option<LBPParams> ) : Pool {
        // Ensure that the normalized weights sum up to 100%
        if (!is_lbp) {
            assert!( weight_1+weight_2 == 10000, ERR_WEIGHTS_SUM); 
        };
        
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
            lbp_params,
            has_paused: false,
            is_stable,
            is_lbp
        }
    }

    // mint LP tokens
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
        
        assert!( fungible_asset::balance(pool_config.token_1) < MAX_POOL_VALUE, ERR_POOL_FULL);
        assert!( fungible_asset::balance(pool_config.token_2) < MAX_POOL_VALUE, ERR_POOL_FULL);

        fungible_asset::mint(&pool_config.lp_mint, provided_liq)
    }

    // Calculates the provided liquidity based on the current LP supply and reserves.
    fun calculate_provided_liq(pool_config: &mut Pool, lp_supply: u64, coin_x_reserve: u64, coin_y_reserve: u64, optimal_coin_x: u64, optimal_coin_y: u64): u64 {

        if (!pool_config.is_stable) {

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
            
        } else {
            if (0 == lp_supply) {

                let initial_liq = stable_math::compute_initial_lp(  optimal_coin_x , optimal_coin_y  );
                assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

                let lp_tokens = fungible_asset::mint(&pool_config.lp_mint, MINIMAL_LIQUIDITY);

                fungible_asset::deposit(pool_config.min_liquidity, lp_tokens);

                initial_liq - MINIMAL_LIQUIDITY
            } else {
                let x_liq = (lp_supply as u128) * (optimal_coin_x as u128) / (coin_x_reserve as u128);
                let y_liq = (lp_supply as u128) * (optimal_coin_y as u128) / (coin_y_reserve as u128);
                if (x_liq < y_liq) {
                    assert!(x_liq < (U64_MAX as u128), ERR_U64_OVERFLOW);
                    (x_liq as u64)
                } else {
                    assert!(y_liq < (U64_MAX as u128), ERR_U64_OVERFLOW);
                    (y_liq as u64)
                }
            }
        }

    }

    fun get_amount_out(is_stable: bool, coin_in: u64, reserve_in: u64, weight_in: u64, reserve_out: u64, weight_out: u64) : u64 {
        if (!is_stable) {
            weighted_math::get_amount_out(
                coin_in,
                reserve_in,
                weight_in, 
                reserve_out,
                weight_out, 
            )
        } else { 
            // FIXME: remove stable pool as the formula doesn't accurate
            weighted_math::get_amount_out(
                coin_in,
                reserve_in,
                5000, 
                reserve_out,
                5000, 
            )
        }
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

    // ======== Test-related Functions =========

    #[test_only] 
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}