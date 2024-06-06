// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// A custom weight DEX for trading tokens to tokens including vault tokens
// Allows setup of various types of pools - weighted pool, stable pool and LBP pool
// Forked from OmniBTC AMM Swap and improved with math from Balancer V2 Lite
// Supports only legacy coins for now

module legato_addr::amm {

    use std::option::{Self, Option};
    use std::signer;
    use std::vector; 
    use std::bcs;
    use std::string::{Self, String };  
    
    use aptos_framework::event;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability}; 
    use aptos_framework::object::{Self, ExtendRef, Object, ConstructorRef }; 
    use aptos_std::smart_vector::{Self, SmartVector}; 
    use aptos_std::comparator::{Self, Result};
    use aptos_std::type_info;  
    use aptos_std::fixed_point64::{Self, FixedPoint64}; 

    use legato_addr::weighted_math;
    use legato_addr::stable_math;
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
    
    const SYMBOL_PREFIX_LENGTH: u64 = 4;

    const LP_TOKEN_DECIMALS: u8 = 8;
    // The max value that can be held in one of the Balances of
    /// a Pool. U64 MAX / WEIGHT_SCALE
    const MAX_POOL_VALUE : u64 = 18446744073709551615;

    // ======== Errors ========

    const ERR_NOT_COIN: u64 = 101;
    const ERR_THE_SAME_COIN: u64 = 102;
    const ERR_WEIGHTS_SUM: u64 = 103;
    const ERR_UNAUTHORIZED: u64 = 104;
    const ERR_MUST_BE_ORDER: u64 = 105;
    const ERR_POOL_HAS_REGISTERED: u64 = 106;
    const ERR_INVALID_ADDRESS: u64 = 107;
    const ERR_POOL_NOT_REGISTER: u64 = 108;
    const ERR_NOT_LBP: u64 = 109;
    const ERR_PAUSED: u64 = 110;
    const ERR_POOL_EXISTS: u64 = 111; 
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 112;
    const ERR_INSUFFICIENT_COIN_X: u64 = 113;
    const ERR_INSUFFICIENT_COIN_Y: u64 = 114;
    const ERR_OVERLIMIT: u64 = 115; 
    const ERR_U64_OVERFLOW: u64 = 116;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 117;
    const ERR_POOL_FULL: u64 = 118; 


    // ======== Structs =========
    /// The Pool token that will be used to mark the pool share
    /// of a liquidity provider. The parameter `X` and `Y` is for the
    /// coin held in the pool.
    struct LP<phantom X, phantom Y> has drop, store {}

    // Liquidity pool with custom weighting 
    struct Pool<phantom X, phantom Y> has key, store {
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
        weight_x: u64, // 50% using 5000
        weight_y: u64, // 50% using 5000
        min_liquidity: Coin<LP<X, Y>>,
        swap_fee: FixedPoint64,
        lp_mint: MintCapability<LP<X, Y>>,
        lp_burn: BurnCapability<LP<X, Y>>,
        lbp_params: Option<LBPParams>, // Params for a LBP pool
        has_paused: bool,
        is_stable: bool, // Indicates if the pool is a stable pool
        is_lbp: bool, // Indicates if the pool is a LBP
    }

    // Represents the global state of the AMM. 
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct AMMManager has key { 
        pool_list: SmartVector<String>, // all pools in the system
        whitelist: SmartVector<address>, // who can setup a new pool
        extend_ref: ExtendRef,
        enable_whitelist: bool,
        treasury_address: address // where all fees from all pools will be sent for further LP staking
    }

    #[event]
    /// Event emitted when a pool is created.
    struct RegisterPool has drop, store { 
        pool_name: String,
        coin_x: String,
        coin_y: String,
        weight_x: u64,
        weight_y: u64,
        is_stable: bool,
        is_lbp: bool
    }

    #[event]
    struct Swapped has drop, store {
        pool_name: String,
        coin_in: String,
        coin_out: String,
        amount_in: u64,
        amount_out: u64
    }

    #[event]
    struct AddedLiquidity has drop, store {
        pool_name: String,
        coin_x: String,
        coin_y: String,
        coin_x_in: u64,
        coin_y_in: u64,
        lp_out: u64
    }

    #[event]
    struct RemovedLiquidity has drop, store {
        pool_name: String,
        coin_x: String,
        coin_y: String,
        lp_in: u64,
        coin_x_out: u64,
        coin_y_out: u64
    }

    // Constructor for this module.
    fun init_module(sender: &signer) {
        
        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        let whitelist = smart_vector::new();
        smart_vector::push_back(&mut whitelist, signer::address_of(sender));

        move_to(sender, AMMManager { 
            whitelist, 
            pool_list: smart_vector::new(), 
            extend_ref,
            enable_whitelist: true,
            treasury_address: signer::address_of(sender)
        });
    }

    // ======== Entry Points =========

    /// Entry point for the `swap` method.
    /// Sends swapped Coin to the sender.
    public entry fun swap<X,Y>(sender: &signer, coin_in: u64, coin_out_min: u64) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        assert!(coin::is_coin_initialized<X>(), ERR_NOT_COIN);
        assert!(coin::is_coin_initialized<Y>(), ERR_NOT_COIN);

        if (is_order) {
            let (reserve_x, reserve_y) = get_reserves_size<X, Y>();
            swap_out_y<X, Y>(sender, coin_in, coin_out_min, reserve_x, reserve_y);
        } else {
            let (reserve_y, reserve_x) = get_reserves_size<Y, X>();
            swap_out_x<Y, X>(sender, coin_in, coin_out_min, reserve_x, reserve_y);
        };
    }

    // Register a new liquidity pool with custom weights
    public entry fun register_pool<X, Y>(
        sender: &signer,
        weight_x: u64,
        weight_y: u64
    ) acquires AMMManager {
        let is_order = is_order<X, Y>();
        if (!is_order) {
            register_pool<Y,X>(sender, weight_y, weight_x);
        } else {
            assert!(coin::is_coin_initialized<X>(), ERR_NOT_COIN);
            assert!(coin::is_coin_initialized<Y>(), ERR_NOT_COIN);

            let config = borrow_global_mut<AMMManager>(@legato_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
            if (config.enable_whitelist) {
                // Ensure that the caller is on the whitelist
                assert!( smart_vector::contains(&config.whitelist, &(signer::address_of(sender))) , ERR_UNAUTHORIZED);
            };

            let (lp_name, lp_symbol) = generate_lp_name_and_symbol<X, Y>();

            assert!( !smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_HAS_REGISTERED);

            let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) = coin::initialize<LP<X, Y>>(sender, lp_name, lp_symbol, 8, true);
            coin::destroy_freeze_cap(lp_freeze_cap);

            // Registers X and Y if not already registered
            if (!coin::is_account_registered<X>(signer::address_of(&config_object_signer))) {
                coin::register<X>(&config_object_signer)
            };

            if (!coin::is_account_registered<Y>(signer::address_of(&config_object_signer))) {
                coin::register<Y>(&config_object_signer)
            };

            let pool = init_pool_params<X,Y>(weight_x, weight_y, fixed_point64::create_from_raw_value( DEFAULT_FEE ), lp_mint_cap, lp_burn_cap, false, false, option::none() );

            move_to(&config_object_signer, pool);

            smart_vector::push_back(&mut config.pool_list, lp_name);

            // Emit an event
            event::emit(RegisterPool { pool_name: lp_name, coin_x : coin::symbol<X>(), coin_y : coin::symbol<Y>(),  weight_x, weight_y, is_stable: false,  is_lbp: false });
        };
    }

    // Register a stable pool, weights are fixed at 50/50
    public entry fun register_stable_pool<X,Y>(sender: &signer) acquires AMMManager {
        let is_order = is_order<X, Y>();
        if (!is_order) {
            register_stable_pool<Y,X>(sender );
        } else {
            assert!(coin::is_coin_initialized<X>(), ERR_NOT_COIN);
            assert!(coin::is_coin_initialized<Y>(), ERR_NOT_COIN);

            let config = borrow_global_mut<AMMManager>(@legato_addr);
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
            if (config.enable_whitelist) {
                // Ensure that the caller is on the whitelist
                assert!( smart_vector::contains(&config.whitelist, &(signer::address_of(sender))) , ERR_UNAUTHORIZED);
            };

            let (lp_name, lp_symbol) = generate_lp_name_and_symbol<X, Y>();

            assert!( !smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_HAS_REGISTERED);

            let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) = coin::initialize<LP<X, Y>>(sender, lp_name, lp_symbol, 8, true);
            coin::destroy_freeze_cap(lp_freeze_cap);

            // Registers X and Y if not already registered
            if (!coin::is_account_registered<X>(signer::address_of(&config_object_signer))) {
                coin::register<X>(&config_object_signer)
            };

            if (!coin::is_account_registered<Y>(signer::address_of(&config_object_signer))) {
                coin::register<Y>(&config_object_signer)
            };

            let pool = init_pool_params<X,Y>(5000, 5000, fixed_point64::create_from_raw_value( STABLE_FEE ), lp_mint_cap, lp_burn_cap, true, false, option::none() );

            move_to(&config_object_signer, pool);

            smart_vector::push_back(&mut config.pool_list, lp_name);

            // Emit an event
            event::emit(RegisterPool { pool_name: lp_name, coin_x : coin::symbol<X>(), coin_y : coin::symbol<Y>(),  weight_x: 5000, weight_y: 5000, is_stable: true,  is_lbp: false });
        };

    }

    // Register an LBP pool, project token weights must be greater than 50%.
    // is_vault specifies if staking rewards from Legato Vault are accepted
    public entry fun register_lbp_pool<X,Y>(
        sender: &signer,
        proj_on_x: bool, // Indicates whether the project token is on the X or Y side
        start_weight: u64,  // Initial weight of the project token.
        final_weight: u64, // The weight when the pool is stabilized. 
        is_vault: bool, // false - only common coins, true - coins+staking rewards.
        target_amount: u64, // The target amount required to fully shift the weight.
    ) acquires AMMManager {
        
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);

        assert!(coin::is_coin_initialized<X>(), ERR_NOT_COIN);
        assert!(coin::is_coin_initialized<Y>(), ERR_NOT_COIN);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        if (config.enable_whitelist) {
            // Ensure that the caller is on the whitelist
            assert!( smart_vector::contains(&config.whitelist, &(signer::address_of(sender))) , ERR_UNAUTHORIZED);
        };

        let (lp_name, lp_symbol) = generate_lp_name_and_symbol<X, Y>();

        assert!( !smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_HAS_REGISTERED);

        let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) = coin::initialize<LP<X, Y>>(sender, lp_name, lp_symbol, 8, true);
        coin::destroy_freeze_cap(lp_freeze_cap);

        // Registers X and Y if not already registered
        if (!coin::is_account_registered<X>(signer::address_of(&config_object_signer))) {
            coin::register<X>(&config_object_signer)
        };

        if (!coin::is_account_registered<Y>(signer::address_of(&config_object_signer))) {
            coin::register<Y>(&config_object_signer)
        };

        let params = lbp::construct_init_params(
            proj_on_x,
            start_weight,
            final_weight, 
            is_vault,
            target_amount
        );

        let pool = init_pool_params<X,Y>(0, 0, fixed_point64::create_from_raw_value( LBP_FEE ), lp_mint_cap, lp_burn_cap, false, true, option::some<LBPParams>(params) );

        move_to(&config_object_signer, pool);

        smart_vector::push_back(&mut config.pool_list, lp_name);

        // Emit an event
        event::emit(RegisterPool { pool_name: lp_name, coin_x : coin::symbol<X>(), coin_y : coin::symbol<Y>(),  weight_x: start_weight, weight_y: final_weight, is_stable: false,  is_lbp: true });

    }

    /// Entrypoint for the `add_liquidity` method.
    /// Sends `LP<X,Y>` to the transaction sender.
    public entry fun add_liquidity<X,Y>(
        lp_provider: &signer, 
        coin_x_amount: u64,
        coin_x_min: u64,
        coin_y_amount: u64,
        coin_y_min: u64
    ) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);

        assert!(coin::is_coin_initialized<X>(), ERR_NOT_COIN);
        assert!(coin::is_coin_initialized<Y>(), ERR_NOT_COIN);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (lp_name, _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_EXISTS);

        let (optimal_x, optimal_y, _) = calc_optimal_coin_values<X, Y>(
            coin_x_amount,
            coin_y_amount,
            coin_x_min,
            coin_y_min
        );

        let (reserves_x, reserves_y) = get_reserves_size<X, Y>();

        assert!(optimal_x >= coin_x_min, ERR_INSUFFICIENT_COIN_X);
        assert!(optimal_y >= coin_y_min, ERR_INSUFFICIENT_COIN_Y);

        let coin_x_opt = coin::withdraw<X>(lp_provider, optimal_x);
        let coin_y_opt = coin::withdraw<Y>(lp_provider, optimal_y);

        let lp_coins = mint_lp<X, Y>( 
            coin_x_opt,
            coin_y_opt,
            optimal_x,
            optimal_y,
            reserves_x,
            reserves_y
        );

        let lp_amount = coin::value(&lp_coins);

        let lp_provider_address = signer::address_of(lp_provider);
        if (!coin::is_account_registered<LP<X, Y>>(lp_provider_address)) {
            coin::register<LP<X, Y>>(lp_provider);
        };
        coin::deposit(lp_provider_address, lp_coins);

        // Emit an event
        event::emit(AddedLiquidity { pool_name: lp_name, coin_x : coin::symbol<X>(), coin_y : coin::symbol<Y>(),  coin_x_in:optimal_x, coin_y_in: optimal_y , lp_out: lp_amount });
    }

    /// Entrypoint for the `remove_liquidity` method.
    /// Transfers Coin<X> and Coin<Y> to the sender.
    public entry fun remove_liquidity<X, Y>( 
        lp_provider: &signer, 
        lp_amount: u64
    ) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);

        assert!(coin::is_coin_initialized<LP<X,Y>>(), ERR_NOT_COIN);
        
        let config = borrow_global_mut<AMMManager>(@legato_addr);

        let (lp_name, _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_NOT_REGISTER);

        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer);
        assert!(exists<Pool<X, Y>>(pool_address), ERR_POOL_EXISTS);

        let (reserves_x, reserves_y) = get_reserves_size<X, Y>();
        let lp_coins_total = option::extract(&mut coin::supply<LP<X, Y>>());

        let pool = borrow_global_mut<Pool<X, Y>>(pool_address);
        assert!(!pool.has_paused , ERR_PAUSED );

        let coin_x_out = 0;
        let coin_y_out = 0;

        if (!pool.is_stable) {
            
            let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);

            (coin_x_out, coin_y_out) = weighted_math::compute_withdrawn_coins( 
                lp_amount, 
                (lp_coins_total as u64), 
                reserves_x, 
                reserves_y, 
                weight_x, 
                weight_y
            ); 

            let coin_x = coin::extract(&mut pool.coin_x, coin_x_out);
            coin::deposit(signer::address_of(lp_provider), coin_x);

            let coin_y = coin::extract(&mut pool.coin_y, coin_y_out);
            coin::deposit(signer::address_of(lp_provider), coin_y);

        } else {

            let multiplier = fixed_point64::create_from_rational( (lp_amount as u128), (lp_coins_total as u128)  );
 
            coin_x_out = (fixed_point64::multiply_u128( (reserves_x as u128), multiplier ) as u64); 
            coin_y_out = (fixed_point64::multiply_u128( (reserves_y as u128), multiplier ) as u64);

            let coin_x = coin::extract(&mut pool.coin_x, (coin_x_out));
            coin::deposit(signer::address_of(lp_provider), coin_x);

            let coin_y = coin::extract(&mut pool.coin_y, (coin_y_out));
            coin::deposit(signer::address_of(lp_provider), coin_y);

        };

        let burn_coin = coin::withdraw<LP<X, Y>>(lp_provider, lp_amount);
        coin::burn(burn_coin, &pool.lp_burn);

        // Emit an event
        event::emit(RemovedLiquidity { pool_name: lp_name, coin_x : coin::symbol<X>(), coin_y : coin::symbol<Y>(), lp_in: lp_amount, coin_x_out, coin_y_out });
    }

    #[view]
    public fun is_order<X, Y>(): bool {
        let comp = compare<X, Y>();
        assert!(!comparator::is_equal(&comp), ERR_THE_SAME_COIN);

        if (comparator::is_smaller_than(&comp)) {
            true
        } else {
            false
        }
    }

    #[view]
    public fun get_config_object_address() : address  acquires AMMManager  {
        let config = borrow_global<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        signer::address_of(&config_object_signer)
    }

    #[view]
    public fun get_treasury_address(): address acquires AMMManager {
        let config = borrow_global<AMMManager>(@legato_addr);
        config.treasury_address
    }

    // Retrieves information about the LBP pool
    #[view]
    public fun lbp_info<X,Y>() : (u64, u64, u64, u64) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer);
        
        if (is_order) {
            assert!(exists<Pool<X, Y>>(pool_address), ERR_POOL_EXISTS);
            let pool = borrow_global_mut<Pool<X, Y>>(pool_address);

            assert!( pool.is_lbp == true , ERR_NOT_LBP);

            let ( weight_x, weight_y ) = pool_current_weight(pool);
            let params = option::borrow(&pool.lbp_params);

            (weight_x,  weight_y, lbp::total_amount_collected(params), lbp::total_target_amount(params))
        } else {
            assert!(exists<Pool<Y, X>>(pool_address), ERR_POOL_EXISTS);
            let pool = borrow_global_mut<Pool<Y, X>>(pool_address);

            assert!( pool.is_lbp == true , ERR_NOT_LBP);

            let ( weight_y, weight_x ) = pool_current_weight(pool);
            let params = option::borrow(&pool.lbp_params);

            ( weight_x, weight_y, lbp::total_amount_collected(params), lbp::total_target_amount(params))
        }
 
    }

    /// Calculate amounts needed for adding new liquidity for both `X` and `Y`.
    /// * `x_desired` - desired value of coins `X`.
    /// * `y_desired` - desired value of coins `Y`.
    /// Returns both `X` and `Y` coins amounts.
    public fun calc_optimal_coin_values<X, Y>(
        x_desired: u64,
        y_desired: u64,
        coin_x_min: u64,
        coin_y_min: u64
    ): (u64, u64, bool) acquires Pool, AMMManager   {
        let (reserves_x, reserves_y) = get_reserves_size<X, Y>();

        let config = borrow_global<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer);
        let pool = borrow_global<Pool<X, Y>>(pool_address);

        if (reserves_x == 0 && reserves_y == 0) {
            return (x_desired, y_desired, true)
        } else {

            // For non-stable pools, use weighted math to compute optimal values.
            if (!pool.is_stable) {

                let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);

                let y_needed = weighted_math::compute_optimal_value(x_desired, reserves_y, weight_y, reserves_x, weight_x );

                if (y_needed <= y_desired) {
                    assert!(y_needed >= coin_y_min, ERR_INSUFFICIENT_COIN_Y);
                    return (x_desired, y_needed, false)
                } else {
                    let x_needed =  weighted_math::compute_optimal_value(y_desired, reserves_x, weight_x, reserves_y, weight_y);
                    assert!(x_needed <= x_desired, ERR_OVERLIMIT);
                    assert!(x_needed >= coin_x_min, ERR_INSUFFICIENT_COIN_X);
                    return (x_needed, y_desired, false)
                }

            } else {

                // For stable pools, use stable math to compute the optimal values.
                let coin_y_returned = stable_math::get_amount_out(
                    x_desired,
                    reserves_x, 
                    reserves_y
                );

                if (coin_y_returned <= y_desired) {
                    assert!(coin_y_returned >= coin_y_min, ERR_INSUFFICIENT_COIN_Y);
                    return (x_desired, coin_y_returned, false)
                } else {
                    let coin_x_returned = stable_math::get_amount_out(
                        y_desired,
                        reserves_y, 
                        reserves_x
                    );

                    assert!(coin_x_returned <= x_desired, ERR_OVERLIMIT);
                    assert!(coin_x_returned >= coin_x_min, ERR_INSUFFICIENT_COIN_X);
                    return (coin_x_returned, y_desired, false) 
                }

            }

        }
    }

    public fun get_reserves_size<X, Y>(): (u64, u64) acquires Pool, AMMManager {
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer);

        assert!(exists<Pool<X, Y>>(pool_address), ERR_POOL_NOT_REGISTER);

        let pool = borrow_global<Pool<X, Y>>(pool_address);

        let x_reserve = coin::value(&pool.coin_x);
        let y_reserve = coin::value(&pool.coin_y);

        (x_reserve, y_reserve)
    }

    // Retrieve the current weights of the pool
    public fun pool_current_weight<X,Y>(pool: &Pool<X, Y> ): (u64, u64)  {
        
        if (!pool.is_lbp) {
            ( pool.weight_x, pool.weight_y )
        } else {
            let params = option::borrow(&pool.lbp_params);
            lbp::current_weight( params ) 
        }

    }

    /// Calculates the provided liquidity based on the current LP supply and reserves.
    /// If the LP supply is zero, it computes the initial liquidity and increases the supply.
    public fun calculate_provided_liq<X,Y>(pool: &mut Pool<X, Y>, lp_supply: u64, coin_x_reserve: u64, coin_y_reserve: u64, optimal_coin_x: u64, optimal_coin_y: u64 ) : u64 {
        if (!pool.is_stable) {

            // Obtain the current weights of the pool
            let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);

            if (0 == lp_supply) {

                let initial_liq = weighted_math::compute_initial_lp( weight_x, weight_y , optimal_coin_x , optimal_coin_y  );
                assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

                coin::merge(&mut pool.min_liquidity, coin::mint<LP<X, Y>>(MINIMAL_LIQUIDITY, &pool.lp_mint) );

                initial_liq - MINIMAL_LIQUIDITY
            } else {
                weighted_math::compute_derive_lp( optimal_coin_x, optimal_coin_y, weight_x, weight_y, coin_x_reserve, coin_y_reserve, lp_supply )
            }
        } else {
            if (0 == lp_supply) {

                let initial_liq = stable_math::compute_initial_lp(  optimal_coin_x , optimal_coin_y  );
                assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

                coin::merge(&mut pool.min_liquidity, coin::mint<LP<X, Y>>(MINIMAL_LIQUIDITY, &pool.lp_mint) );

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

    // ======== Internal Functions =========

    fun coin_symbol_prefix<CoinType>(): String {
        let symbol = coin::symbol<CoinType>();
        let prefix_length = SYMBOL_PREFIX_LENGTH;
        if (string::length(&symbol) < SYMBOL_PREFIX_LENGTH) {
            prefix_length = string::length(&symbol);
        };
        string::sub_string(&symbol, 0, prefix_length)
    }

    /// Compare two coins, 'X' and 'Y'.
    fun compare<X, Y>(): Result {
        let x_info = type_info::type_of<X>();
        let x_compare = &mut type_info::struct_name(&x_info);
        vector::append(x_compare, type_info::module_name(&x_info));

        let y_info = type_info::type_of<Y>();
        let y_compare = &mut type_info::struct_name(&y_info);
        vector::append(y_compare, type_info::module_name(&y_info));

        let comp = comparator::compare(x_compare, y_compare);
        if (!comparator::is_equal(&comp)) return comp;

        let x_address = type_info::account_address(&x_info);
        let y_address = type_info::account_address(&y_info);
        comparator::compare(&x_address, &y_address)
    }

    /// Generate LP coin name and symbol for pair `X`/`Y`.
    /// ```
    /// name = "LP-" + symbol<X>() + "-" + symbol<Y>();
    /// symbol = symbol<X>()[0:4] + "-" + symbol<Y>()[0:4];
    /// ```
    /// For example, for `LP<BTC, USDT>`,
    /// the result will be `(b"LP-BTC-USDT", b"BTC-USDT")`
    public fun generate_lp_name_and_symbol<X, Y>(): (String, String) {
        let lp_name = string::utf8(b"");
        string::append_utf8(&mut lp_name, b"LP-");
        string::append(&mut lp_name, coin::symbol<X>());
        string::append_utf8(&mut lp_name, b"-");
        string::append(&mut lp_name, coin::symbol<Y>());

        let lp_symbol = string::utf8(b"");
        string::append(&mut lp_symbol, coin_symbol_prefix<X>());
        string::append_utf8(&mut lp_symbol, b"-");
        string::append(&mut lp_symbol, coin_symbol_prefix<Y>());

        (lp_name, lp_symbol)
    }

    fun init_pool_params<X,Y>(weight_x: u64, weight_y: u64, swap_fee: FixedPoint64, lp_mint: MintCapability<LP<X,Y>>, lp_burn: BurnCapability<LP<X,Y>>, is_stable: bool, is_lbp: bool, lbp_params: Option<LBPParams> ) : Pool<X, Y> {
        // Ensure that the normalized weights sum up to 100%
        if (!is_lbp) {
            assert!( weight_x+weight_y == 10000, ERR_WEIGHTS_SUM); 
        };
        
        Pool<X, Y> {
            coin_x: coin::zero<X>(),
            coin_y: coin::zero<Y>(), 
            weight_x,
            weight_y,
            swap_fee,
            lp_mint,
            lp_burn,
            min_liquidity: coin::zero<LP<X,Y>>(),
            has_paused: false,
            is_stable,
            is_lbp,
            lbp_params
        }
    }

    fun swap_out_y<X, Y>(
        sender: &signer,
        coin_in_value: u64,
        coin_out_min_value: u64,
        reserve_in: u64,
        reserve_out: u64,
    ) acquires Pool, AMMManager {

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (lp_name, _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_NOT_REGISTER);
        
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer);

        let pool = borrow_global_mut<Pool<X, Y>>(pool_address);

        assert!(!pool.has_paused , ERR_PAUSED );

        let (coin_x_after_fees, coin_x_fee) = weighted_math::get_fee_to_treasury( pool.swap_fee , coin_in_value);

        let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);

        let coin_y_out = get_amount_out(
            pool.is_stable,
            coin_x_after_fees,
            reserve_in,
            weight_x,
            reserve_out,
            weight_y
        );

        assert!(
            coin_y_out >= coin_out_min_value,
            ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
        );

        if (pool.is_lbp) {
            let params = option::borrow_mut(&mut pool.lbp_params);
            let is_buy = lbp::is_buy(params);  
            lbp::verify_and_adjust_amount(params, is_buy, coin_in_value, coin_y_out, false );
        };

        let coin_in = coin::withdraw<X>(sender, coin_in_value);
        let fee_in = coin::extract(&mut coin_in, coin_x_fee);

        coin::deposit( config.treasury_address, fee_in);

        coin::merge(&mut pool.coin_x, coin_in);

        let out_swapped = coin::extract(&mut pool.coin_y, coin_y_out);

        if (!coin::is_account_registered<Y>(signer::address_of(sender))) {
            coin::register<Y>(sender);
        };

        coin::deposit(signer::address_of(sender), out_swapped);

        // Emit an event
        event::emit(Swapped { pool_name: lp_name, coin_in : coin::symbol<X>(), coin_out : coin::symbol<Y>(), amount_in: coin_in_value, amount_out: coin_y_out });
    }

    fun swap_out_x<X,Y>(
        sender: &signer,
        coin_in_value: u64,
        coin_out_min_value: u64,
        reserve_in: u64,
        reserve_out: u64
    ) acquires Pool, AMMManager {

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (lp_name , _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name), ERR_POOL_NOT_REGISTER);
        
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer);

        let pool = borrow_global_mut<Pool<X, Y>>(pool_address);

        assert!(!pool.has_paused , ERR_PAUSED );

        let (coin_y_after_fees, coin_y_fee) =  weighted_math::get_fee_to_treasury( pool.swap_fee , coin_in_value);

        let (weight_x, weight_y ) = pool_current_weight(pool);

        let coin_x_out = weighted_math::get_amount_out(
            coin_y_after_fees,
            reserve_in,
            weight_y,
            reserve_out,
            weight_x
        );

        assert!(
            coin_x_out >= coin_out_min_value,
            ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
        );

        if (pool.is_lbp) {
            let params = option::borrow_mut(&mut pool.lbp_params);
            let is_buy = lbp::is_buy(params);   
            lbp::verify_and_adjust_amount(params, !is_buy, coin_in_value, coin_x_out, false);
        };

        let coin_in = coin::withdraw<Y>(sender, coin_in_value);
        let fee_in = coin::extract(&mut coin_in, coin_y_fee);

        coin::deposit( config.treasury_address, fee_in);

        coin::merge(&mut pool.coin_y, coin_in);

        let out_swapped = coin::extract(&mut pool.coin_x, coin_x_out);

        if (!coin::is_account_registered<X>(signer::address_of(sender))) {
            coin::register<X>(sender);
        };

        coin::deposit(signer::address_of(sender), out_swapped);

        // Emit an event
        event::emit(Swapped { pool_name: lp_name, coin_in : coin::symbol<Y>(), coin_out : coin::symbol<X>(), amount_in: coin_in_value, amount_out: coin_x_out });
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
            stable_math::get_amount_out(
                coin_in,
                reserve_in, 
                reserve_out
            )
        }
    }

    // mint LP tokens
    fun mint_lp<X, Y>( 
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
        optimal_x: u64,
        optimal_y: u64,
        coin_x_reserve: u64,
        coin_y_reserve: u64
    ): Coin<LP<X, Y>>  acquires Pool, AMMManager {
        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer);

        assert!(exists<Pool<X, Y>>(pool_address), ERR_POOL_EXISTS);

        let pool = borrow_global_mut<Pool<X, Y>>(pool_address);
        assert!(!pool.has_paused , ERR_PAUSED );

        // let x_provided_val = coin::value<X>(&coin_x);
        // let y_provided_val = coin::value<Y>(&coin_y);

        // Retrieves total LP coins supply
        let lp_coins_total = option::extract(&mut coin::supply<LP<X, Y>>());

        // Computes provided liquidity
        let provided_liq = calculate_provided_liq<X,Y>(pool, (lp_coins_total as u64), coin_x_reserve, coin_y_reserve, optimal_x, optimal_y  );

        // Merges provided coins into pool
        coin::merge(&mut pool.coin_x, coin_x);
        coin::merge(&mut pool.coin_y, coin_y);

        assert!(coin::value(&pool.coin_x) < MAX_POOL_VALUE, ERR_POOL_FULL);
        assert!(coin::value(&pool.coin_y) < MAX_POOL_VALUE, ERR_POOL_FULL);

        // Mints LP tokens
        coin::mint<LP<X, Y>>(provided_liq, &pool.lp_mint)
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
    public entry fun update_pool_fee<X,Y>(sender: &signer, fee_numerator: u128, fee_denominator: u128) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (lp_name, _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name), ERR_POOL_NOT_REGISTER);

        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer); 

        let pool_config = borrow_global_mut<Pool<X, Y>>(pool_address);
        pool_config.swap_fee = fixed_point64::create_from_rational( fee_numerator, fee_denominator );

    }

    // Pause/Unpause the LP pool
    public entry fun pause<X,Y>(sender: &signer, is_pause: bool) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (lp_name, _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name), ERR_POOL_NOT_REGISTER);

        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer); 

        let pool_config = borrow_global_mut<Pool<X, Y>>(pool_address);
        pool_config.has_paused = is_pause
    }

    // Set a new target amount for LBP
    public entry fun lbp_set_target_amount<X,Y>(sender: &signer, new_target_amount: u64) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (lp_name, _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_NOT_REGISTER);
        
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer); 
        let pool_config = borrow_global_mut<Pool<X, Y>>(pool_address);

        let params = option::borrow_mut(&mut pool_config.lbp_params);
        lbp::set_new_target_amount(  params, new_target_amount );
    }

    // Enable/Disable buy with pair or with vault tokens
    public entry fun lbp_enable_buy_with_pair_and_vault<X,Y>(sender: &signer, enable_pair: bool, enable_vault: bool) acquires AMMManager, Pool {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<AMMManager>(@legato_addr);
        let (lp_name, _) = generate_lp_name_and_symbol<X, Y>();
        assert!( smart_vector::contains(&config.pool_list, &lp_name) , ERR_POOL_NOT_REGISTER);

        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let pool_address = signer::address_of(&config_object_signer); 
        let pool_config = borrow_global_mut<Pool<X, Y>>(pool_address);

        assert!( pool_config.is_lbp , ERR_NOT_LBP);

        let params = option::borrow_mut(&mut pool_config.lbp_params);

        lbp::enable_buy_with_pair(  params, enable_pair );
        lbp::enable_buy_with_vault(  params, enable_vault );
    }


    // ======== Test-related Functions =========

    #[test_only] 
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}