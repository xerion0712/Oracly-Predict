// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// AMM DEX with custom weights. It originated from the OmniBTC AMM and upgraded the weight function using the Balancer V2 Lite formula from Ethereum.
// LBP in the current version is separated into another file.

module legato_amm::amm {

  
    use std::vector;
    use std::string::{ String};   
 
    use sui::bag::{Self, Bag};
    use sui::object::{Self, ID, UID};
    use sui::balance::{ Self, Supply, Balance}; 
    use sui::tx_context::{ Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::transfer; 
    use sui::event::emit;

     
    use legato_amm::weighted_math;
    use legato_amm::lp_helpers::{ is_order, generate_lp_name };
    use legato_math::fixed_point64::{Self, FixedPoint64};

    // ======== Constants ========

    // Default swap fee of 0.5% in fixed-point
    const DEFAULT_FEE: u128 = 92233720368547758;
    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000; 

    // ======== Errors ========

    const ERR_MUST_BE_ORDER: u64 = 1;
    // const ERR_INCORRECT_SWAP: u64 = 2;
    const ERR_UNAUTHORISED: u64 = 3;
    const ERR_NOT_FOUND: u64 = 4;
    const ERR_DUPLICATED_ENTRY: u64 = 5;
    const ERR_POOL_NOT_REGISTER: u64 = 6;
    const ERR_POOL_HAS_REGISTERED: u64 = 7;
    const ERR_WEIGHTS_SUM: u64 = 8;
    const ERR_ZERO_AMOUNT: u64 = 9;
    const ERR_INSUFFICIENT_COIN_Y: u64 = 10;
    const ERR_OVERLIMIT: u64 = 11;
    const ERR_INSUFFICIENT_COIN_X: u64 = 12;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 13;
    const ERR_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 14;
    const ERR_NOT_REGISTERED: u64 = 15;
    const ERR_PAUSED: u64 = 16;
    const ERR_RESERVES_EMPTY: u64 = 17;
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 18;

    // ======== Structs =========

    /// The Pool token that will be used to mark the pool share
    /// of a liquidity provider. The parameter `X` and `Y` is for the
    /// coin held in the pool.
    struct LP<phantom X, phantom Y> has drop, store {}

    // The liquidity pool with custom weighting
    struct Pool<phantom X, phantom Y> has store {
        global: ID,
        coin_x: Balance<X>,
        coin_y: Balance<Y>,
        weight_x: u64, // Weight on the X side, e.g., 50% using 5000
        weight_y: u64, // Weight on the Y side, e.g., 50% using 5000
        lp_supply: Supply<LP<X, Y>>,
        min_liquidity: Balance<LP<X, Y>>,
        swap_fee: FixedPoint64,
        has_paused: bool
    }
    
    // The global state of the AMM
    struct AMMGlobal has key {
        id: UID, 
        pools: Bag, // Collection of all LP pools in the system
        archives: Bag, // Storage for archived pools 
        enable_whitelist: bool ,
        whitelist: vector<address>, // Addresses that can set up a new pool
        treasury: address // Address where all fees from all pools are collected for further LP staking
    }

    // Using ManagerCap for admin permission
    struct ManagerCap has key {
        id: UID
    }

    struct RegisterPoolEvent has copy, drop {
        global: ID,
        lp_name: String,
        weight_x: u64,
        weight_y: u64
    }

    struct AddLiquidityEvent has copy, drop {
        global: ID,
        lp_name: String,
        lp_amount: u64,
        is_pool_creator: bool
    }

    struct RemoveLiquidityEvent has copy, drop {
        global: ID,
        lp_name: String,
        lp_amount: u64,
        coin_x_amount: u64,
        coin_y_amount: u64
    }

    struct SwappedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_in_amount: u64,
        coin_out_amount: u64
    }

    // Initializes the AMM module
    fun init(ctx: &mut TxContext) {

        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        // Create a new list for adding to the global state
        let whitelist_list = vector::empty<address>();
        vector::push_back<address>(&mut whitelist_list, tx_context::sender(ctx));
        
        
        // Initialize the global state
        let global = AMMGlobal {
            id: object::new(ctx),
            whitelist: whitelist_list,
            pools: bag::new(ctx), 
            enable_whitelist: true,
            archives: bag::new(ctx), 
            treasury: tx_context::sender(ctx)
        };

        transfer::share_object(global)
    }

    // ======== Entry Points =========

    // Entry point for the swap function to exchange Coin<X> for Coin<Y>
    public entry fun swap<X,Y>(
        global: &mut AMMGlobal,
        coin_in: Coin<X>,
        coin_out_min: u64,
        ctx: &mut TxContext
    ) {
        let coin_out = swap_out_non_entry<X, Y>( global, coin_in, coin_out_min, ctx );
        transfer::public_transfer(coin_out, tx_context::sender(ctx));
    }

    // Entrypoint for the add_liquidity function that returns LP<X,Y> back to the sender.
    public entry fun add_liquidity<X,Y>(
        global: &mut AMMGlobal,
        coin_x: Coin<X>,
        coin_x_min: u64,
        coin_y: Coin<Y>,
        coin_y_min: u64,
        ctx: &mut TxContext
    ) {
        let is_order = is_order<X, Y>();

        if (!is_order) {
            add_liquidity<Y,X>( global, coin_y, coin_y_min, coin_x, coin_x_min, ctx );
        } else {

            assert!(has_registered<X, Y>(global), ERR_NOT_REGISTERED);
            assert!(!is_paused<X,Y>(global, is_order), ERR_PAUSED);

            let lp_name = generate_lp_name<X, Y>();
            let pool = get_mut_pool<X, Y>(global, is_order);

            let (_, _, lp_supply) = get_reserves_size(pool, is_order);

            let is_pool_creator = if (lp_supply == 0) {
                true
            } else {
                false
            };

            let lp = add_liquidity_non_entry(
                pool,
                coin_x,
                coin_x_min,
                coin_y,
                coin_y_min,
                is_order,
                ctx
            );

            let lp_amount = coin::value(&lp);

            // LP tokens of the pool creator are sent to the treasury and may receive another form of incentives
            if (is_pool_creator) {
                let treasury_address = get_treasury_address(global);
                transfer::public_transfer(lp, treasury_address);
            } else {
                transfer::public_transfer(lp, tx_context::sender(ctx));
            };

            emit(
                AddLiquidityEvent {
                    global: object::id(global),
                    lp_name,
                    lp_amount,
                    is_pool_creator
                }
            )
        }

    }

    // Entrypoint for the remove_liquidity method that burns LP and returns Coin<X> and Coin<Y> to the sender.
    public entry fun remove_liquidity<X, Y>(
        global: &mut AMMGlobal,
        lp_coin: Coin<LP<X, Y>>,
        ctx: &mut TxContext
    ) {
        let is_order = is_order<X, Y>();

        assert!(is_order, ERR_MUST_BE_ORDER);
        assert!(!is_paused<X,Y>(global, is_order), ERR_PAUSED);
        let pool = get_mut_pool<X, Y>(global, is_order);
        let lp_name = generate_lp_name<X, Y>();

        let lp_val = coin::value(&lp_coin);
        let (coin_x, coin_y) = remove_liquidity_non_entry(pool, lp_coin, is_order, ctx);
        let coin_x_val = coin::value(&coin_x);
        let coin_y_val = coin::value(&coin_y);

        transfer::public_transfer(
            coin_x,
            tx_context::sender(ctx)
        );

        transfer::public_transfer(
            coin_y,
            tx_context::sender(ctx)
        );
        
        emit(
            RemoveLiquidityEvent {
                global: object::id(global),
                lp_name,
                lp_amount: lp_val,
                coin_x_amount: coin_x_val,
                coin_y_amount: coin_y_val
            }
        )
    
    }

    // Allows anyone or authorized users if enabled to register a new liquidity pool with custom weights
    public entry fun register_pool<X, Y>(
        global: &mut AMMGlobal,
        weight_x: u64,
        weight_y: u64, 
        ctx: &mut TxContext
    ) {
        let is_order = is_order<X, Y>();
        if (!is_order) {
            register_pool<Y,X>( global, weight_y, weight_x, ctx );
        } else {

            // Check if authorized to register
            if (global.enable_whitelist) {
                check_whitelist(global, tx_context::sender(ctx));
            };

            // Check if the pool already exists
            let lp_name = generate_lp_name<X, Y>();
            let has_registered = bag::contains_with_type<String, Pool<X, Y>>(&global.pools, lp_name);
            assert!(!has_registered, ERR_POOL_HAS_REGISTERED);

            let lp_supply = balance::create_supply(LP<X, Y> {});

            // Ensure that the normalized weights sum up to 100%
            assert!( weight_x+weight_y == 10000, ERR_WEIGHTS_SUM);

            bag::add(&mut global.pools, lp_name, Pool {
                global: object::uid_to_inner(&global.id),
                coin_x: balance::zero<X>(),
                coin_y: balance::zero<Y>(),
                lp_supply,
                min_liquidity: balance::zero<LP<X, Y>>(),
                swap_fee: fixed_point64::create_from_raw_value( DEFAULT_FEE ),
                weight_x,
                weight_y,
                has_paused: false
            });

            emit(
                RegisterPoolEvent {
                    global: object::id(global),
                    lp_name,
                    weight_x,
                    weight_y
                }
            )

        }

    }


    // ======== Public Functions =========

    // Exchange Coin<X> for Coin<Y> and return the Coin object.
    public fun swap_out_non_entry<X, Y>(
        global: &mut AMMGlobal,
        coin_in: Coin<X>,
        coin_out_min: u64,
        ctx: &mut TxContext
    ): Coin<Y> {
        assert!(coin::value<X>(&coin_in) > 0, ERR_ZERO_AMOUNT);

        let is_order = is_order<X, Y>();
        let lp_name = generate_lp_name<X, Y>();
        assert!(!is_paused<X,Y>(global, is_order), ERR_PAUSED);

        let treasury_address = get_treasury_address(global);
        let global_id =  object::id(global);
        
        if (is_order) {
            
            let pool = get_mut_pool<X, Y>(global, is_order);
            let (coin_x_reserve, coin_y_reserve, _lp) = get_reserves_size(pool, is_order);
            assert!(coin_x_reserve > 0 && coin_y_reserve > 0, ERR_RESERVES_EMPTY);
            let coin_x_in = coin::value(&coin_in);

            let (coin_x_after_fees, coin_x_fee) = weighted_math::get_fee_to_treasury( pool.swap_fee , coin_x_in);

            // Obtain the current weights of the pool
            let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);

            let coin_y_out = get_amount_out(
                coin_x_after_fees,
                coin_x_reserve,
                weight_x, 
                coin_y_reserve,
                weight_y
            );

            assert!(
                coin_y_out >= coin_out_min,
                ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
            );

            let coin_x_balance = coin::into_balance(coin_in);
            transfer::public_transfer(
                coin::from_balance(balance::split(&mut coin_x_balance, coin_x_fee) , ctx),
                treasury_address
            );

            balance::join(&mut pool.coin_x, coin_x_balance);

            emit(
                SwappedEvent {
                    global: global_id, 
                    lp_name,
                    coin_in_amount: coin_x_in,
                    coin_out_amount: coin_y_out
                }
            );

            (coin::take(&mut pool.coin_y, coin_y_out, ctx))
        } else {

            let pool = get_mut_pool<Y, X>(global, !is_order);
            let (coin_x_reserve, coin_y_reserve, _lp) = get_reserves_size(pool, is_order);
            assert!(coin_x_reserve > 0 && coin_y_reserve > 0, ERR_RESERVES_EMPTY);
            let coin_y_in = coin::value(&coin_in);

            // Obtain the current weights of the pool
            let (weight_x, weight_y ) = pool_current_weight(pool);

            let (coin_y_after_fees, coin_y_fee) =  weighted_math::get_fee_to_treasury( pool.swap_fee , coin_y_in);

            let coin_x_out = get_amount_out( 
                coin_y_after_fees,
                coin_y_reserve,
                weight_y, 
                coin_x_reserve,
                weight_x
            );

            assert!(
                coin_x_out >= coin_out_min,
                ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM
            );

            let coin_y_balance = coin::into_balance(coin_in);
            transfer::public_transfer(
                coin::from_balance(balance::split(&mut coin_y_balance, coin_y_fee) , ctx),
                treasury_address
            );
            balance::join(&mut pool.coin_y, coin_y_balance);

            emit(
                SwappedEvent {
                    global: global_id, 
                    lp_name,
                    coin_in_amount: coin_y_in,
                    coin_out_amount: coin_x_out
                }
            );

            (coin::take(&mut pool.coin_x, coin_x_out, ctx))
        }
        

    }


    /// Add liquidity to the `Pool`. Sender needs to provide both
    /// `Coin<X>` and `Coin<Y>`, and in exchange he gets `Coin<LP>` -
    /// liquidity provider tokens.
    #[allow(lint(self_transfer))]
    public fun add_liquidity_non_entry<X,Y>(
        pool: &mut Pool<X, Y>,
        coin_x: Coin<X>,
        coin_x_min: u64,
        coin_y: Coin<Y>,
        coin_y_min: u64,
        is_order: bool,
        ctx: &mut TxContext
    ) : Coin<LP<X, Y>> {
        assert!(is_order, ERR_MUST_BE_ORDER);

        let coin_x_value = coin::value(&coin_x);
        let coin_y_value = coin::value(&coin_y);

        assert!(coin_x_value > 0 && coin_y_value > 0, ERR_ZERO_AMOUNT);

        let coin_x_balance = coin::into_balance(coin_x);
        let coin_y_balance = coin::into_balance(coin_y);

        let (coin_x_reserve, coin_y_reserve, lp_supply) = get_reserves_size(pool, is_order);

        let (optimal_coin_x, optimal_coin_y) = calc_optimal_coin_values( 
            pool, 
            coin_x_value, 
            coin_y_value, 
            coin_x_min, 
            coin_y_min, 
            coin_x_reserve, 
            coin_y_reserve
        );

        let provided_liq = calculate_provided_liq<X,Y>(pool, lp_supply, coin_x_reserve, coin_y_reserve, optimal_coin_x, optimal_coin_y  );

        assert!(provided_liq > 0, ERR_INSUFFICIENT_LIQUIDITY_MINTED);

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

        balance::join(&mut pool.coin_x, coin_x_balance);
        balance::join(&mut pool.coin_y, coin_y_balance);

        let balance = balance::increase_supply(&mut pool.lp_supply, provided_liq);

        coin::from_balance(balance, ctx)
    }

    /// Remove liquidity from the `Pool` by burning `Coin<LP>`.
    /// Returns `Coin<X>` and `Coin<Y>`.
    public fun remove_liquidity_non_entry<X, Y>(
        pool: &mut Pool<X, Y>,
        lp_coin: Coin<LP<X, Y>>,
        is_order: bool,
        ctx: &mut TxContext
    ): (Coin<X>, Coin<Y>) {
        assert!(is_order, ERR_MUST_BE_ORDER);

        let lp_val = coin::value(&lp_coin);
        assert!(lp_val > 0, ERR_ZERO_AMOUNT);

        let (reserve_x_amount, reserve_y_amount, lp_supply) = get_reserves_size(pool, is_order); 

        let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);

        let (coin_x_out, coin_y_out) = weighted_math::compute_withdrawn_coins( 
            lp_val, 
            lp_supply, 
            reserve_x_amount, 
            reserve_y_amount, 
            weight_x, 
            weight_y
        ); 

        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp_coin));

        (
            coin::take(&mut pool.coin_x, coin_x_out, ctx),
            coin::take(&mut pool.coin_y, coin_y_out, ctx)
        )
    }

    public fun global_id<X, Y>(pool: &Pool<X, Y>): ID {
        pool.global
    }


    #[allow(unused_type_parameter, unused_variable)]
    public fun id<X, Y>(global: &AMMGlobal): ID {
        object::uid_to_inner(&global.id)
    }

    public fun get_mut_pool<X, Y>(
        global: &mut AMMGlobal,
        is_order: bool,
    ): &mut Pool<X, Y> {
        assert!(is_order, ERR_MUST_BE_ORDER);

        let lp_name = generate_lp_name<X, Y>();
        let has_registered = bag::contains_with_type<String, Pool<X, Y>>(&global.pools, lp_name);
        assert!(has_registered, ERR_POOL_NOT_REGISTER);

        bag::borrow_mut<String, Pool<X, Y>>(&mut global.pools, lp_name)
    }

    public fun balance_x<X,Y>(pool: &Pool<X, Y>): u64 {
        balance::value<X>(&pool.coin_x)
    }

    public fun balance_y<X,Y>(pool: &Pool<X, Y>): u64 {
        balance::value<Y>(&pool.coin_y)
    }

    /// Get most used values in a handy way:
    /// - amount of Coin<X>
    /// - amount of Coin<Y>
    /// - total supply of LP<X,Y>
    public fun get_reserves_size<X, Y>(pool: &Pool<X, Y>, _is_order: bool): (u64, u64, u64) {
        (
            balance::value(&pool.coin_x),
            balance::value(&pool.coin_y),
            balance::supply_value(&pool.lp_supply)
        )  
    }

    // Calculate the optimal amounts of `X` and `Y` coins needed for adding new liquidity.
    // Returns both `X` and `Y` coins amounts.
    public fun calc_optimal_coin_values<X,Y>(
        pool: &Pool<X, Y>,
        coin_x_desired: u64,
        coin_y_desired: u64,
        coin_x_min: u64,
        coin_y_min: u64,
        coin_x_reserve: u64,
        coin_y_reserve: u64
    ): (u64, u64) {

        // If the pool has no existing liquidity, return the desired amounts.
        if (coin_x_reserve == 0 && coin_y_reserve == 0) {
            return (coin_x_desired, coin_y_desired)
        } else { 
            
            let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);

            let coin_y_needed = weighted_math::compute_optimal_value(
                coin_x_desired,
                coin_y_reserve,
                weight_y, 
                coin_x_reserve, 
                weight_x
            );
 
            if (coin_y_needed <= coin_y_desired) {  
                assert!(coin_y_needed >= coin_y_min, ERR_INSUFFICIENT_COIN_Y);
                return (coin_x_desired, coin_y_needed)
            } else {
  
                let coin_x_needed = weighted_math::compute_optimal_value(
                    coin_y_desired,
                    coin_x_reserve, 
                    weight_x,
                    coin_y_reserve,
                    weight_y
                );
 
                assert!(coin_x_needed <= coin_x_desired, ERR_OVERLIMIT);
                assert!(coin_x_needed >= coin_x_min, ERR_INSUFFICIENT_COIN_X);
                return (coin_x_needed, coin_y_desired) 
            } 
            
        }
    }

    // Retrieve the current weights of the pool
    public fun pool_current_weight<X,Y>(pool: &Pool<X, Y> ): (u64, u64)  {
        ( pool.weight_x, pool.weight_y )
    }

    /// Calculates the provided liquidity based on the current LP supply and reserves.
    /// If the LP supply is zero, it computes the initial liquidity and increases the supply.
    public fun calculate_provided_liq<X,Y>(pool: &mut Pool<X, Y>, lp_supply: u64, coin_x_reserve: u64, coin_y_reserve: u64, optimal_coin_x: u64, optimal_coin_y: u64 ) : u64 {
        
        // Obtain the current weights of the pool
        let (weight_x, weight_y) = pool_current_weight<X,Y>(pool);

        if (0 == lp_supply) {

            let initial_liq = weighted_math::compute_initial_lp( weight_x, weight_y , optimal_coin_x , optimal_coin_y  );
            assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

            let minimal_liquidity = balance::increase_supply(
                &mut pool.lp_supply,
                MINIMAL_LIQUIDITY
            );
            balance::join(&mut pool.min_liquidity, minimal_liquidity);

            initial_liq - MINIMAL_LIQUIDITY
        } else {
            weighted_math::compute_derive_lp( optimal_coin_x, optimal_coin_y, weight_x, weight_y, coin_x_reserve, coin_y_reserve, lp_supply )
        }

    }

    public fun is_paused<X,Y>(global: &mut AMMGlobal, is_order: bool): bool { 
        if (is_order) {
            let pool = get_mut_pool<X, Y>(global, is_order);
            pool.has_paused
        } else {
            let pool = get_mut_pool<Y, X>(global, !is_order);
            pool.has_paused
        }
    }

    public fun get_amount_out(coin_in: u64, reserve_in: u64, weight_in: u64, reserve_out: u64, weight_out: u64) : u64 {
        weighted_math::get_amount_out( coin_in, reserve_in, weight_in, reserve_out, weight_out)
    }
    
    // ======== Only Governance =========

    // Updates the swap fee for the specified pool
    public entry fun update_pool_fee<X, Y>(global: &mut AMMGlobal, _manager_cap: &mut ManagerCap, fee_numerator: u128, fee_denominator: u128 ) {
        let is_order = is_order<X, Y>();
        let pool = get_mut_pool<X, Y>(global, is_order);
        pool.swap_fee = fixed_point64::create_from_rational( fee_numerator, fee_denominator )
    }

    // Adds a user to the whitelist
    public entry fun add_whitelist(global: &mut AMMGlobal,  _manager_cap: &mut ManagerCap, user: address) {
        assert!(!vector::contains(&global.whitelist, &user),ERR_DUPLICATED_ENTRY);
        vector::push_back<address>(&mut global.whitelist, user);
    }

    // Removes a user from the whitelist
    public entry fun remove_whitelist(global: &mut AMMGlobal,  _manager_cap: &mut ManagerCap, user: address) {
        let (contained, index) = vector::index_of<address>(&global.whitelist, &user);
        assert!(contained, ERR_NOT_FOUND);
        vector::remove<address>(&mut global.whitelist, index);
    }

    // Enable/Disable whitelist system
    public entry fun enable_whitelist(global: &mut AMMGlobal,  _manager_cap: &mut ManagerCap, is_enable: bool ) {
        global.enable_whitelist = is_enable;
    }

    // Pauses the specified pool
    public entry fun pause<X, Y>(global: &mut AMMGlobal, _manager_cap: &mut ManagerCap) {
        let is_order = is_order<X, Y>();
        let pool = get_mut_pool<X, Y>(global, is_order);
        pool.has_paused = true
    }

    // Resumes the specified pool
    public entry fun resume<X, Y>( global: &mut AMMGlobal, _manager_cap: &mut ManagerCap) {
        let is_order = is_order<X, Y>();
        let pool = get_mut_pool<X, Y>(global, is_order);
        pool.has_paused = false
    }

    // Updates the treasury address
    public entry fun update_treasury(global: &mut AMMGlobal, _manager_cap: &mut ManagerCap, treasury_address: address) {
        global.treasury = treasury_address;
    }

    // Moves a pool to the archive 
    public entry fun move_to_archive<X, Y>(global: &mut AMMGlobal, _manager_cap: &mut ManagerCap) {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);

        let lp_name = generate_lp_name<X, Y>();
        let pool = bag::remove<String, Pool<X, Y>>(&mut global.pools, lp_name);

        bag::add(&mut global.archives, lp_name, pool );
    }

    // ======== Internal Functions =========

    fun check_whitelist(global: &AMMGlobal, sender: address) {
        let (contained, _) = vector::index_of<address>(&global.whitelist, &sender);
        assert!(contained, ERR_UNAUTHORISED);
    }
 
    fun get_treasury_address(global: &AMMGlobal) : address {
        global.treasury
    }

    fun has_registered<X, Y>(global: &AMMGlobal): bool {
        let lp_name = generate_lp_name<X, Y>();
        bag::contains_with_type<String, Pool<X, Y>>(&global.pools, lp_name)
    }

    

    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun get_mut_pool_for_testing<X, Y>(
        global: &mut AMMGlobal
    ): &mut Pool<X, Y> {
        get_mut_pool<X, Y>(global, is_order<X, Y>())
    }

}
