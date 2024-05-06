// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// LBP is a special type of AMM that allows for a gradual shift in weight over time or under certain conditions.
// It is built on top of AMM with custom weights, offering a solution for launching project tokens with reduced capital requirements and less selling pressure.
// In Legato LBP, there are two types of settlement assets available for pairing with project tokens.
// (1) Common coins like USDC or SUI (2) SUI staking rewards via Legato Vault

module legato::lbp {

    use std::option::{Self, Option};
    use std::vector;
    use std::string::{Self, String}; 
    use std::type_name::{get, into_string};
    use std::ascii::into_bytes;

    use sui::bag::{Self, Bag};
    use sui::object::{Self, ID, UID};
    use sui::balance::{ Self, Supply, Balance}; 
    use sui::tx_context::{ Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::transfer;

    use legato::fixed_point64::{Self, FixedPoint64}; 
    use legato::weighted_math;


    // ======== Constants ========

    // Default swap fee of 0.25%
    const DEFAULT_FEE: u128 = 46116860184273879;
    // Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000;
    // The integer scaling setting for weights
    const WEIGHT_SCALE: u128 = 10000;
    // Lowest weight in fixed-point raw value (0.1)
    const LOWEST_WEIGHT: u128 = 1844674407370955161; 
    // Highest weight in fixed-point raw value (10)
    const HIGEST_WEIGHT: u128 = 184467440737095516160;  
    /// a Pool. U64 MAX / WEIGHT_SCALE
    const MAX_POOL_VALUE : u64 = 18446744073709551615;


    // ======== Errors ========

    const ERR_POOL_HAS_REGISTERED:u64  = 500;
    const ERR_WEIGHTS_SUM: u64  = 501;
    const ERR_UNAUTHORISED: u64 = 502;
    const ERR_INVALID_POOL_ADMIN: u64 = 503;
    const ERR_NO_POOL: u64 = 504;
    const ERR_ALREADY_SET: u64 = 505;
    const ERR_INVALID_VALUE: u64 = 506;
    const ERR_DUPLICATED_ENTRY: u64 = 507;
    const ERR_NOT_FOUND: u64 = 508;
    const ERR_POOL_NOT_REGISTER: u64 = 509;
    const ERR_PAUSED: u64  = 510;
    const ERR_ZERO_AMOUNT: u64 = 511;
    const ERR_POOL_NOT_STARTED: u64 = 512;
    const ERR_INVALID_PAIR_TYPE: u64 = 513;
    const ERR_INSUFFICIENT_COIN_Y: u64 = 514;
    const ERR_INSUFFICIENT_COIN_X: u64 = 515;
    const ERR_OVERLIMIT: u64 = 516;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 517;
    const ERR_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 518;
    const ERR_POOL_FULL: u64 = 519;

    // ======== Structs =========

    // In LBP, we have only X marks the project token,
    // while the pair token is defined in the pool's state.
    struct LBPToken<phantom X> has drop, store {} 

    struct Weight has copy, store, drop {
        x: u64,
        y: u64
    }

    /// Struct defining the weights for the LBP pool.
    struct LBPWeights has store {
        weight_0: Weight,
        weight_1: Option<Weight>,
        weight_2: Option<Weight>,
        weight_3: Option<Weight>,
        weight_4: Option<Weight>,
        current: u8, // current weight
        total: u8, // total weight on this LBP pool (max.5)
        trigger_by: u8, // 1 - amount token sold, 2 - amount staked
        total_amount_token_sold: u64, // when trigger_by = 1 - total project token has been sold
        total_amount_staked: u64, // when trigger_by = 2 - total staking rewards received
        amount_to_trigger: u64 // amount collected until weight shifted
    }

    /// Struct defining the reserves for the LBP pool.
    struct LBPReserves<phantom X> has store {
        base: Balance<X>, // Project token
        pair: Bag, 
        pair_symbol: Option<String>, // Pair token symbol if it's a common coin
        pair_type: u8, // Type of pair token: 1 - common coin, 2 - SUI's staking rewards
    }

    /// Struct defining the properties and state of the LBP pool.
    struct LBPPool<phantom X> has store {
        global: ID,
        reserves: LBPReserves<X>,
        weights: LBPWeights,
        lp_supply: Supply<LBPToken<X>>,
        min_liquidity: Balance<LBPToken<X>>,
        swap_fee: FixedPoint64,
        pool_admin: address, // the project's token owner
        has_paused: bool,
        weight_set: bool, // Indicates whether the weights have been set
        reserve_set: bool // Indicates whether the reserves have been set
    }

    // The global state
    struct LBPGlobal has key {
        id: UID, 
        pools: Bag, // Collection of all LBP pools in the system
        archives: Bag, // Storage for archived LBP pool objects 
        whitelist: vector<address>, // List of addresses authorized to set up new pools
        treasury: address // Address where fees from all pools are collected for further LP staking
    }

    struct LBPManagerCap has key {
        id: UID
    }

    // Initializes the LBP
    fun init(ctx: &mut TxContext) {

        // Transfer ManagerCap to the deployer
        transfer::transfer(
            LBPManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        // Create a new list for adding to the global state
        let whitelist_list = vector::empty<address>();
        vector::push_back<address>(&mut whitelist_list, tx_context::sender(ctx));
        
        // Initialize the global state
        let global = LBPGlobal {
            id: object::new(ctx),
            whitelist: whitelist_list,
            pools: bag::new(ctx), 
            archives: bag::new(ctx), 
            treasury: tx_context::sender(ctx)
        };

        transfer::share_object(global)
    }

    // ======== Entry Points =========

    

    /// Entrypoint for the `add_liquidity` method.
    /// When setting the pool's pair as a common coin:
    /// X is always the type of the base or project token,
    /// and Y refers to the pair coin type.
    public entry fun add_liquidity<X, Y>(
        global: &mut LBPGlobal,
        coin_x: Coin<X>,
        coin_x_min: u64,
        coin_y: Coin<Y>,
        coin_y_min: u64,
        ctx: &mut TxContext
    ) {
        // Ensure that the LBP pool is not paused before proceeding
        assert!(!is_paused<X>(global), ERR_PAUSED);
        let pool = get_mut_pool<X>(global);

        assert!( pool.weight_set && pool.reserve_set, ERR_POOL_NOT_STARTED);
        
        // Ensure that the pair type of the reserves is set to a common coin
        assert!( pool.reserves.pair_type == 1 , ERR_INVALID_PAIR_TYPE);

        let coin_x_value = coin::value(&coin_x);
        let coin_y_value = coin::value(&coin_y);

        assert!(coin_x_value > 0 && coin_y_value > 0, ERR_ZERO_AMOUNT);

        let coin_x_balance = coin::into_balance(coin_x);
        let coin_y_balance = coin::into_balance(coin_y);

        let (coin_x_reserve, coin_y_reserve, lp_supply) = get_reserves_size<X, Y>(pool);

        // Calculate the optimal values for the provided coins
        let (optimal_coin_x, optimal_coin_y) = calc_optimal_coin_values( 
            pool, 
            coin_x_value, 
            coin_y_value, 
            coin_x_min, 
            coin_y_min, 
            coin_x_reserve, 
            coin_y_reserve 
        );

        // Obtain the current weights of the pool
        let (weight_x, weight_y) = pool_current_weight<X>(pool);

        // Calculate the amount of liquidity to be sent
        let provided_liq = if (0 == lp_supply) {
            // If the LP supply is zero, calculate the initial liquidity
            let initial_liq = weighted_math::compute_initial_lp(  weight_x, weight_y , optimal_coin_x , optimal_coin_y  );
            assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

            let minimal_liquidity = balance::increase_supply(
                &mut pool.lp_supply,
                MINIMAL_LIQUIDITY
            );
            balance::join(&mut pool.min_liquidity, minimal_liquidity);

            initial_liq - MINIMAL_LIQUIDITY
        } else {
            // If the LP supply is non-zero, compute the derived liquidity
            let (x_liq, y_liq) = weighted_math::compute_derive_lp( optimal_coin_x, optimal_coin_y, weight_x, weight_y, coin_x_reserve, coin_y_reserve, lp_supply );
            // Return the sum of the derived liquidity for X and Y tokens
            (x_liq + y_liq)
        };

        assert!(provided_liq > 0, ERR_INSUFFICIENT_LIQUIDITY_MINTED);

        
        // Transfer excess tokens back to the sender if the provided amounts exceed the optimal values
        if (optimal_coin_x < coin_x_value) {
            transfer::public_transfer(
                coin::from_balance(balance::split(&mut coin_x_balance, coin_x_value - optimal_coin_x), ctx),
                tx_context::sender(ctx)
            )
        };
        if (optimal_coin_y < coin_y_value) { 
            transfer::public_transfer(
                coin::from_balance(balance::split(&mut coin_y_balance, coin_y_value - optimal_coin_y), ctx),
                tx_context::sender(ctx)
            )
        };

        // Retrieve the symbol name for the Y coin
        let coin_y_symbol = generate_symbol_name<Y>();
        let coin_y_reserve = bag::borrow_mut<String, Balance<Y>>(&mut pool.reserves.pair, coin_y_symbol);

        let coin_x_amount = balance::join(&mut pool.reserves.base, coin_x_balance);
        let coin_y_amount = balance::join(coin_y_reserve, coin_y_balance);

        assert!(coin_x_amount < MAX_POOL_VALUE, ERR_POOL_FULL);
        assert!(coin_y_amount < MAX_POOL_VALUE, ERR_POOL_FULL);

        let balance = balance::increase_supply(&mut pool.lp_supply, provided_liq);

        // Transfer the LP tokens to the sender
        transfer::public_transfer(coin::from_balance(balance, ctx), tx_context::sender(ctx));

        // TODO: emit event

    }

    // Registers an LBP pool by an authorized caller. Weight and reserve data must be set afterward,
    // otherwise, the pool won't start.
    public entry fun register_lbp_pool<X>(
        global: &mut LBPGlobal,
        ctx: &mut TxContext
    ) {
        // Check if authorized to register
        check_whitelist(global, tx_context::sender(ctx));

        // Check if the pool already exists
        let lp_name = generate_lp_name<X>();
        let has_registered = bag::contains_with_type<String, LBPPool<X>>(&global.pools, lp_name);
        assert!(!has_registered, ERR_POOL_HAS_REGISTERED);

        let lp_supply = balance::create_supply(LBPToken<X> {});

        let weight_data = LBPWeights {
            weight_0: Weight { x : 5000, y : 5000 },
            weight_1: option::none<Weight>(),
            weight_2: option::none<Weight>(),
            weight_3: option::none<Weight>(),
            weight_4: option::none<Weight>(),
            current: 0,
            total: 1,
            trigger_by: 0,
            total_amount_staked: 0,
            total_amount_token_sold: 0,
            amount_to_trigger: 0
        };

        let reserve_data = LBPReserves {
            base: balance::zero<X>() ,
            pair: bag::new(ctx), 
            pair_symbol: option::none<String>(),
            pair_type: 0
        };

        bag::add(&mut global.pools, lp_name, LBPPool {
                global: object::uid_to_inner(&global.id),
                reserves: reserve_data,
                weights: weight_data,
                lp_supply,
                min_liquidity: balance::zero<LBPToken<X>>(),
                swap_fee: fixed_point64::create_from_raw_value( DEFAULT_FEE ),
                pool_admin: tx_context::sender(ctx),
                weight_set: false,
                reserve_set: false,
                has_paused: false
        });

        // TODO: emit event
    }

    // Sets up weight data for the LBP pool.
    public entry fun setup_weight_data<X>(
        global: &mut LBPGlobal,
        weight_0_x: u64, // Mandatory weight in fixed-point raw value
        weight_0_y: u64, // Mandatory weight in fixed-point raw value
        weight_1_x: u64, // Use zero when none
        weight_1_y: u64, // Use zero when none
        weight_2_x: u64, // Use zero when none
        weight_2_y: u64, // Use zero when none
        weight_3_x: u64, // Use zero when none
        weight_3_y: u64, // Use zero when none
        weight_4_x: u64, // Use zero when none
        weight_4_y: u64, // Use zero when none
        trigger_by: u8, // Allowed values: 1 for amount token sold, 2 for amount staked
        trigger_amount: u64, // Amount until weight shifted
        ctx: &mut TxContext
    ) {
        assert!( trigger_by == 1 || trigger_by == 2, ERR_INVALID_VALUE);
        assert!( trigger_amount > 0, ERR_INVALID_VALUE  );
        assert!( weight_0_x+weight_0_y == 10000, ERR_WEIGHTS_SUM);

        let pool = get_mut_pool<X>(global);

        // Ensure sender is the pool admin and weights are not already set
        assert!( pool.pool_admin == tx_context::sender(ctx), ERR_INVALID_POOL_ADMIN );
        assert!( pool.weight_set == false, ERR_ALREADY_SET );

        // Set weight_0
        pool.weights.weight_0.x = weight_0_x;
        pool.weights.weight_0.y = weight_0_y;
        let total = 1;

        // Set optional weights if non-zero
        if (weight_1_x != 0 && weight_1_y != 0)
            assert!( weight_1_x+weight_1_y == 10000, ERR_WEIGHTS_SUM);
            total = total+1;
            pool.weights.weight_1 = option::some<Weight>( Weight {
                x: weight_1_x,
                y: weight_1_y
            });
        
        if (weight_2_x != 0 && weight_2_y != 0)
            assert!( weight_2_x+weight_2_y == 10000, ERR_WEIGHTS_SUM);
            total = total+1;
            pool.weights.weight_2 = option::some<Weight>( Weight {
                x: weight_2_x,
                y: weight_2_y
            });

        if (weight_3_x != 0 && weight_3_y != 0)
            assert!( weight_3_x+weight_3_y == 10000, ERR_WEIGHTS_SUM);
            total = total+1;
            pool.weights.weight_3 = option::some<Weight>( Weight {
                x: weight_3_x,
                y: weight_3_y
            });

        if (weight_4_x != 0 && weight_4_y != 0)
            assert!( weight_4_x+weight_4_y == 10000, ERR_WEIGHTS_SUM);
            total = total+1;
            pool.weights.weight_4 = option::some<Weight>( Weight {
                x: weight_4_x,
                y: weight_4_y
            });

        // Set other weight properties
        pool.weights.trigger_by = trigger_by;
        pool.weights.amount_to_trigger = trigger_amount;

        // Mark weight as set
        pool.weight_set = true;

        // TODO: emit event
    }

    /// Sets up reserves with a common coin as a pair asset that needs to be provided on Type Y.
    /// Scroll down if you want to use staking rewards as a pair asset.
    public entry fun setup_reserve_with_common_coin<X, Y>(
        global: &mut LBPGlobal,
        ctx: &mut TxContext
    ) {
        let pool = get_mut_pool<X>(global);

        // Ensure sender is the pool admin and reserve data is not already set
        assert!( pool.pool_admin == tx_context::sender(ctx), ERR_INVALID_POOL_ADMIN );
        assert!( pool.reserve_set == false, ERR_ALREADY_SET );
        
        // Generate a symbol name for the pair token
        let symbol_name = generate_symbol_name<Y>();

        pool.reserves.pair_symbol = option::some<String>(symbol_name);

        // Initialize the pair token balance and add it to the reserves
        let new_balance = balance::zero<Y>();
        bag::add(&mut pool.reserves.pair, symbol_name, new_balance);

        // Set the pair type to indicate it's a common coin
        pool.reserves.pair_type = 1;

        // Mark reserve setup as completed
        pool.reserve_set = true;

        // TODO: emit event
    }

    /// Sets up reserves using staking rewards as a pair asset.
    public entry fun setup_reserve_with_staking_rewards<X>(
        global: &mut LBPGlobal,
        ctx: &mut TxContext
    ) {
        let pool = get_mut_pool<X>(global);

        // Ensure sender is the pool admin and reserve data is not already set
        assert!( pool.pool_admin == tx_context::sender(ctx), ERR_INVALID_POOL_ADMIN );
        assert!( pool.reserve_set == false, ERR_ALREADY_SET );

        // Set the pair type to indicate it's SUI's staking rewards
        pool.reserves.pair_type = 2;

        // Mark reserve setup as completed
        pool.reserve_set = true;
    }

    // ======== Public Functions =========

    public fun generate_lp_name<X>(): String {
        let lp_name = string::utf8(b"");
        string::append_utf8(&mut lp_name, b"LP-");
        string::append_utf8(&mut lp_name, into_bytes(into_string(get<X>())));
        lp_name
    }

    public fun generate_symbol_name<X>(): String {
        let symbol_name = string::utf8(b"");
        string::append_utf8(&mut symbol_name, into_bytes(into_string(get<X>())));
        symbol_name
    }

    public fun get_mut_pool<X>(
        global: &mut LBPGlobal
    ): &mut LBPPool<X> { 

        let lp_name = generate_lp_name<X>();
        let has_registered = bag::contains_with_type<String, LBPPool<X>>(&global.pools, lp_name);
        assert!(has_registered, ERR_POOL_NOT_REGISTER);

        bag::borrow_mut<String, LBPPool<X>>(&mut global.pools, lp_name)
    }

    public fun calc_optimal_coin_values<X>(
        pool: &LBPPool<X>,
        coin_x_desired: u64,
        coin_y_desired: u64,
        coin_x_min: u64,
        coin_y_min: u64,
        coin_x_reserve: u64,
        coin_y_reserve: u64
    ): (u64, u64) {

        if (coin_x_reserve == 0 && coin_y_reserve == 0) {
            return (coin_x_desired, coin_y_desired)
        } else { 

            let (weight_x, weight_y) = pool_current_weight<X>(pool);

            let coin_y_returned = weighted_math::compute_optimal_value(
                coin_x_desired,
                coin_x_reserve, 
                coin_y_reserve,
                weight_y
            );

            if (coin_y_returned <= coin_y_desired) {
                assert!(coin_y_returned >= coin_y_min, ERR_INSUFFICIENT_COIN_Y);
                return (coin_x_desired, coin_y_returned)
            } else {
                let coin_x_returned = weighted_math::compute_optimal_value(
                    coin_y_desired,
                    coin_y_reserve, 
                    coin_x_reserve,
                    weight_x
                );

                assert!(coin_x_returned <= coin_x_desired, ERR_OVERLIMIT);
                assert!(coin_x_returned >= coin_x_min, ERR_INSUFFICIENT_COIN_X);
                return (coin_x_returned, coin_y_desired) 
            } 
            
        }
    }

    public fun is_paused<X>(global: &LBPGlobal): bool { 
        let lp_name = generate_lp_name<X>();
        let has_registered = bag::contains_with_type<String, LBPPool<X>>(&global.pools, lp_name);
        assert!(has_registered, ERR_POOL_NOT_REGISTER);

        let pool = bag::borrow<String, LBPPool<X>>(&global.pools, lp_name);

        pool.has_paused
    }

    /// Get most used values in a handy way:
    /// - amount of Coin<X>
    /// - amount of Coin<Y>
    /// - total supply of LP<X,Y>
    public fun get_reserves_size<X, Y>(pool: &mut LBPPool<X>): (u64, u64, u64) {

        let coin_y_symbol = *option::borrow( &pool.reserves.pair_symbol );
        let coin_y_balance = bag::borrow<String, Balance<Y>>(&pool.reserves.pair, coin_y_symbol);

        (
            balance::value(&pool.reserves.base),
            balance::value(coin_y_balance), 
            balance::supply_value(&pool.lp_supply)
        )
    }

    fun pool_current_weight<X>(pool: &LBPPool<X>) : (u64, u64)  {
        
        let current_tier = pool.weights.current;
        let current_weight = pool.weights.weight_0;
        
        if (current_tier == 1) {
            current_weight = *option::borrow(&pool.weights.weight_1);
        } else if (current_tier == 2) {
            current_weight = *option::borrow(&pool.weights.weight_2);
        } else if (current_tier == 3) {
            current_weight = *option::borrow(&pool.weights.weight_3);
        } else if (current_tier == 4) {
            current_weight = *option::borrow(&pool.weights.weight_4);
        };

        ( current_weight.x, current_weight.y )
    }

    // ======== Only Governance =========

    // Adds a user to the whitelist 
    public entry fun add_whitelist(global: &mut LBPGlobal,  _manager_cap: &mut LBPManagerCap, user: address) {
        assert!(!vector::contains(&global.whitelist, &user),ERR_DUPLICATED_ENTRY);
        vector::push_back<address>(&mut global.whitelist, user);
    }

    // Removes a user from the whitelist
    public entry fun remove_whitelist(global: &mut LBPGlobal,  _manager_cap: &mut LBPManagerCap, user: address) {
        let (contained, index) = vector::index_of<address>(&global.whitelist, &user);
        assert!(contained,ERR_NOT_FOUND);
        vector::remove<address>(&mut global.whitelist, index);
    }

    // Updates the treasury address
    public entry fun update_treasury(global: &mut LBPGlobal, _manager_cap: &mut LBPManagerCap, treasury_address: address) {
        global.treasury = treasury_address;
    }

    // Moves a pool to the archive 
    public entry fun move_to_archive<X>(global: &mut LBPGlobal, _manager_cap: &mut LBPManagerCap) {
        let lp_name = generate_lp_name<X>();
        let has_registered = bag::contains_with_type<String, LBPPool<X>>(&global.pools, lp_name);
        assert!(has_registered, ERR_POOL_NOT_REGISTER);

        let pool = bag::remove<String, LBPPool<X>>(&mut global.pools, lp_name);

        bag::add(&mut global.archives, lp_name, pool );
    }

    // ======== Internal Functions =========

    fun check_whitelist(global: &LBPGlobal, sender: address) {
        let (contained, _) = vector::index_of<address>(&global.whitelist, &sender);
        assert!(contained, ERR_UNAUTHORISED);
    }


    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

}