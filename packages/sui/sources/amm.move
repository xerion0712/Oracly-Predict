// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// AMM DEX with custom weights. It originated based on the OmniBTC AMM and upgraded the weights function using the Balancer V2 Lite formula from Ethereum. 
// Having custom weights allows us to use much less capital to launch a new pool, as well as providing the capability of LBP.

module legato::amm {

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
    use sui::sui::SUI; 

    use sui_system::sui_system::{ Self, SuiSystemState };
    use sui_system::staking_pool::{ Self, StakedSui};

    use legato::comparator; 
    use legato::weighted_math;
    use legato::stable_math;
    use legato_math::fixed_point64::{Self, FixedPoint64};
    use legato::lbp::{LBPParams, LBPStorage, Self};
    use legato::vault::{Self, Global, ManagerCap};
    // use legato::stake_data_provider::{Self};
    use legato::event::{register_pool_event, swapped_event, future_swapped_event, add_liquidity_event, remove_liquidity_event};

    // ======== Constants ========

    // Default swap fee of 0.5% in fixed-point
    const DEFAULT_FEE: u128 = 92233720368547758;
    // 0.25% for LBP
    const LBP_FEE: u128 = 46116860184273879;
    // 0.1% for stable pools
    const STABLE_FEE: u128 = 18446744073709551;
    /// Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000; 
     /// Max u64 value.
    const U64_MAX: u64 = 18446744073709551615;
    /// The max value that can be held in one of the Balances of
    /// a Pool. U64 MAX / WEIGHT_SCALE
    const MAX_POOL_VALUE : u64 = 18446744073709551615;

    const MIN_SUI_TO_STAKE : u64 = 1_000_000_000; // 1 Sui

    // ======== Errors ========

    const ERR_ZERO_AMOUNT: u64 = 200; 
    const ERR_RESERVES_EMPTY: u64 = 201; 
    const ERR_POOL_FULL: u64 = 202; 
    const ERR_INSUFFICIENT_COIN_X: u64 = 203; 
    const ERR_INSUFFICIENT_COIN_Y: u64 = 204;  
    const ERR_OVERLIMIT: u64 = 206; 
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 207; 
    const ERR_LIQUID_NOT_ENOUGH: u64 = 208; 
    const ERR_THE_SAME_COIN: u64 = 209; 
    const ERR_POOL_HAS_REGISTERED: u64 = 210; 
    const ERR_POOL_NOT_REGISTER: u64 = 211; 
    const ERR_MUST_BE_ORDER: u64 = 212; 
    const ERR_U64_OVERFLOW: u64 = 213; 
    const ERR_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 215;
    const ERR_NOT_FOUND: u64 = 216;
    const ERR_DUPLICATED_ENTRY: u64 = 217;
    const ERR_UNAUTHORISED: u64 = 218;
    const ERR_WEIGHTS_SUM: u64 = 219;  
    const ERR_PAUSED: u64 = 222;
    const ERR_NOT_REGISTERED: u64 = 223;
    const ERR_UNEXPECTED_RETURN: u64 = 224; 
    const ERR_NOT_LBP: u64 = 225; 
    const ERR_SUI_TOO_LOW: u64 = 228;
    const ERR_ZERO_FUTURE_YIELD: u64 = 229; 
    const ERR_NOT_ACCEPT_VAULT: u64 = 230;

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
        lbp_params: Option<LBPParams>, // Params for a LBP pool
        lbp_storage: Option<LBPStorage>, // Extra storage for a LBP pool
        has_paused: bool,
        is_stable: bool,  // Indicates if the pool is a stable pool
        is_lbp: bool // Indicates if the pool is a LBP
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

    // Initializes the AMM module
    fun init(ctx: &mut TxContext) {

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

    /// Entry point for the `swap` method.
    /// Sends swapped Coin to the sender.
    public entry fun swap<X, Y>(
        global: &mut AMMGlobal,
        coin_in: Coin<X>,
        coin_out_min: u64,
        ctx: &mut TxContext
    ) {
        let is_order = is_order<X, Y>();

        assert!(!is_paused<X,Y>(global, is_order), ERR_PAUSED);

        let lp_name = generate_lp_name<X, Y>();

        let return_values = swap_out_non_entry<X, Y>(
            global,
            coin_in,
            coin_out_min,
            is_order,
            ctx
        );

        let coin_y_out = vector::pop_back(&mut return_values);
        let coin_y_in = vector::pop_back(&mut return_values);
        let coin_x_out = vector::pop_back(&mut return_values);
        let coin_x_in = vector::pop_back(&mut return_values);

        swapped_event(
            object::id(global),
            lp_name,
            coin_x_in,
            coin_x_out,
            coin_y_in,
            coin_y_out
        );
    }

    /// Entrypoint for the `add_liquidity` method.
    /// Sends `LP<X,Y>` to the transaction sender.
    public entry fun add_liquidity<X, Y>(
        global: &mut AMMGlobal,
        coin_x: Coin<X>,
        coin_x_min: u64,
        coin_y: Coin<Y>,
        coin_y_min: u64,
        ctx: &mut TxContext
    ) {
        let is_order = is_order<X, Y>();
        
        assert!(has_registered<X, Y>(global), ERR_NOT_REGISTERED);
        assert!(!is_paused<X,Y>(global, is_order), ERR_PAUSED);

        let lp_name = generate_lp_name<X, Y>();
        let pool = get_mut_pool<X, Y>(global, is_order);

        let (lp, return_values, is_pool_creator) = add_liquidity_non_entry(
            pool,
            coin_x,
            coin_x_min,
            coin_y,
            coin_y_min,
            is_order,
            ctx
        );
        assert!(vector::length(&return_values) == 3, ERR_UNEXPECTED_RETURN);

        // LP tokens of the pool creator are sent to the treasury and may receive another form of incentives
        if (is_pool_creator) {
            let treasury_address = get_treasury_address(global);
            transfer::public_transfer(lp, treasury_address);
        } else {
            transfer::public_transfer(lp, tx_context::sender(ctx));
        };

        let lp_val = vector::pop_back(&mut return_values);
        let coin_x_val = vector::pop_back(&mut return_values);
        let coin_y_val = vector::pop_back(&mut return_values);

        add_liquidity_event(
            object::id(global),
            lp_name,
            coin_x_val,
            coin_y_val,
            lp_val,
            is_pool_creator
        );
    }

    /// Entrypoint for the `remove_liquidity` method.
    /// Transfers Coin<X> and Coin<Y> to the sender.
    public entry fun remove_liquidity<X, Y>(
        global: &mut AMMGlobal,
        lp_coin: Coin<LP<X, Y>>,
        ctx: &mut TxContext
    ) {
        
        let is_order = is_order<X, Y>(); 
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

        remove_liquidity_event(
            object::id(global),
            lp_name,
            coin_x_val,
            coin_y_val,
            lp_val
        );

    }

    // This allows swaps future yield from yield-bearing assets (Staked SUI) 
    // for Y tokens on the LBP pool at a lower rate. When swapped, the vault 
    // tokens (PT) are returned to the sender at a 1:1 while the yield is used 
    // to get Y tokens. X refers to Legato vaults to be used.
    public entry fun future_swap<X,Y>(
        wrapper: &mut SuiSystemState,
        amm_global: &mut AMMGlobal,
        vault_global: &mut Global,
        staked_sui: StakedSui,
        ctx: &mut TxContext
    ) {
        assert!( has_registered<SUI, Y>(amm_global)  , ERR_NOT_REGISTERED);

        let is_order = is_order<SUI, Y>(); 
        assert!(!is_paused<SUI,Y>(amm_global, is_order), ERR_PAUSED); 
        
        let lp_name = generate_lp_name<SUI, Y>();

        // Mint PT 
        let staked_sui_in = staking_pool::staked_sui_amount(&staked_sui);
        let (pt_token, future_yield_amount) = vault::mint_non_entry<X>( wrapper, vault_global, staked_sui, ctx );
        let pt_token_value = coin::value(&pt_token);

        // Transfer PT tokens with deducted future yield back to the sender
        transfer::public_transfer(
            coin::split(&mut pt_token, pt_token_value-future_yield_amount, ctx),
            tx_context::sender(ctx)
        );

        let pt_token_remaining = coin::value(&pt_token);
        assert!( pt_token_remaining  > 0, ERR_ZERO_FUTURE_YIELD);
        
        // The future yield tokens are immediately used to acquire Y tokens at the early stage.
        // The Y tokens are locked and can be claimed according to the permitted timeframe of the vault staked in.
        // For example, staking at Q1 to Q4 vault will allow claiming Y tokens at the end of Q1, Q2, Q3 and Q4.

        // We're also waiving swap fees for future swaps.

        let pool = get_mut_pool<SUI, Y>(amm_global, is_order);
        assert!( pool.is_lbp , ERR_NOT_LBP);

        let (coin_x_reserve, coin_y_reserve, _lp) = get_reserves_size(pool, true);
        assert!(coin_x_reserve > 0 && coin_y_reserve > 0, ERR_RESERVES_EMPTY);

        // Obtain the current weights of the pool
        let (weight_x, weight_y ) = pool_current_weight<SUI,Y>(pool);

        let params = option::borrow_mut(&mut pool.lbp_params);

        // Ensure the pool's parameters accept a vault.
        assert!(  lbp::is_vault( params ), ERR_NOT_ACCEPT_VAULT);

        let storage = option::borrow_mut(&mut pool.lbp_storage);

        // Calculate the amount of Y tokens using the remaining PT tokens
        let coin_y_out = get_amount_out(
            pool.is_stable,
            pt_token_remaining,
            coin_x_reserve,
            weight_x, 
            coin_y_reserve,
            weight_y
        );

        lbp::verify_and_adjust_amount(params, true, pt_token_remaining, coin_y_out, true );

        // Store the PT tokens in the pool's pending storage.
        lbp::add_pending_in<X>( storage, pt_token, pt_token_remaining );

        // Transfer Y tokens to the sender.
        let coin_out = coin::take(&mut pool.coin_y, coin_y_out, ctx);
        
        transfer::public_transfer(
            coin_out,
            tx_context::sender(ctx)
        );
        
        future_swapped_event(
            object::id(amm_global),
            lp_name,
            staked_sui_in,
            future_yield_amount,
            coin_y_out
        );
       
    }

    // Similar to above but uses SUI tokens as input. 
    public entry fun future_swap_with_sui<X,Y>(
        wrapper: &mut SuiSystemState,
        amm_global: &mut AMMGlobal,
        vault_global: &mut Global, 
        sui: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(&sui) >= MIN_SUI_TO_STAKE, ERR_SUI_TOO_LOW);

        let validator_address = vault::get_random_validator_address( vault::staking_pools(vault_global) , ctx );
        let staked_sui = sui_system::request_add_stake_non_entry(wrapper, sui, validator_address, ctx);

        future_swap<X,Y>( wrapper, amm_global, vault_global, staked_sui, ctx );

    }

    // Allows authorized users to register a new liquidity pool with custom weights
    // Note that stable pools and LBP are using separate functions below
    public entry fun register_pool<X, Y>(
        global: &mut AMMGlobal,
        weight_x: u64,
        weight_y: u64, 
        ctx: &mut TxContext
    ) {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);

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
            lbp_params: option::none<LBPParams>(),
            lbp_storage: option::none<LBPStorage>(), 
            is_stable: false,
            is_lbp: false,
            has_paused: false
        });

        register_pool_event(
            object::id(global),
            lp_name,
            weight_x,
            weight_y,
            false,
            false
        );
        
    }

    // Allows authorized users to register a stable pool, weights are fixed at 50/50
    public entry fun register_stable_pool<X,Y>(
        global: &mut AMMGlobal,
        ctx: &mut TxContext
    ) {
        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);

        // Check if authorized to register
        if (global.enable_whitelist) {
            check_whitelist(global, tx_context::sender(ctx));
        };

        // Check if the pool already exists
        let lp_name = generate_lp_name<X, Y>();
        let has_registered = bag::contains_with_type<String, Pool<X, Y>>(&global.pools, lp_name);
        assert!(!has_registered, ERR_POOL_HAS_REGISTERED);

        let lp_supply = balance::create_supply(LP<X, Y> {});

        bag::add(&mut global.pools, lp_name, Pool {
            global: object::uid_to_inner(&global.id),
            coin_x: balance::zero<X>(),
            coin_y: balance::zero<Y>(),
            lp_supply,
            min_liquidity: balance::zero<LP<X, Y>>(),
            swap_fee: fixed_point64::create_from_raw_value( STABLE_FEE ),
            weight_x: 5000,
            weight_y: 5000,
            lbp_params: option::none<LBPParams>(),
            lbp_storage: option::none<LBPStorage>(), 
            is_stable: true,
            is_lbp: false,
            has_paused: false
        });

        register_pool_event(
            object::id(global),
            lp_name,
            5000,
            5000,
            true,
            false
        );
    }

    // Allows authorized users to register an LBP pool.
    // In LBP, weights apply only to the project token side and must be greater than 50%.
    public entry fun register_lbp_pool<X,Y>(
        global: &mut AMMGlobal,
        proj_on_x: bool, // Indicates whether the project token is on the X or Y side
        start_weight: u64,  // Initial weight of the project token.
        final_weight: u64, // The weight when the pool is stabilized.  
        is_vault: bool, // false - only common coins, true - coins+staking rewards.
        target_amount: u64, // The target amount required to fully shift the weight.
        ctx: &mut TxContext
    ) {

        let is_order = is_order<X, Y>();
        assert!(is_order, ERR_MUST_BE_ORDER);

        // Check if authorized to register
        if (global.enable_whitelist) {
            check_whitelist(global, tx_context::sender(ctx));
        };
        
        // Check if the pool already exists
        let lp_name = generate_lp_name<X, Y>();
        let has_registered = bag::contains_with_type<String, Pool<X, Y>>(&global.pools, lp_name);
        assert!(!has_registered, ERR_POOL_HAS_REGISTERED);

        let lp_supply = balance::create_supply(LP<X, Y> {});

        let params = lbp::construct_init_params(
            proj_on_x,
            start_weight,
            final_weight, 
            is_vault,
            target_amount
        );

        bag::add(&mut global.pools, lp_name, Pool {
            global: object::uid_to_inner(&global.id),
            coin_x: balance::zero<X>(),
            coin_y: balance::zero<Y>(),
            lp_supply,
            min_liquidity: balance::zero<LP<X, Y>>(),
            swap_fee: fixed_point64::create_from_raw_value( LBP_FEE ),
            weight_x: 0, // not used
            weight_y: 0, // not used
            lbp_params: option::some<LBPParams>(params),
            lbp_storage: option::some<LBPStorage>(lbp::create_empty_storage(ctx)),
            is_stable: false,
            is_lbp: true,
            has_paused: false
        });

        register_pool_event(
            object::id(global),
            lp_name,
            start_weight,
            final_weight,
            false,
            true
        );
    }

    // The process of redeeming PT tokens from the matured vault and using SUI to unblock tokens in the LBP's reserve. 
    // X refers to the project token.
    // Y refers to the matured vault.
    // Anyone can execute this function, but there are no incentives for doing so.
    public entry fun lbp_replenish<X,Y>(
        wrapper: &mut SuiSystemState,
        amm_global: &mut AMMGlobal,
        vault_global: &mut Global, 
        ctx: &mut TxContext
    ) {
        assert!( has_registered<SUI, X>(amm_global)  , ERR_NOT_REGISTERED);

        let is_order = is_order<SUI, X>(); 
        assert!(!is_paused<SUI,X>(amm_global, is_order), ERR_PAUSED); 

        let pool = get_mut_pool<SUI, X>(amm_global, is_order);
        assert!( pool.is_lbp , ERR_NOT_LBP);

        let storage = option::borrow_mut(&mut pool.lbp_storage);

        let pt_to_redeem = lbp::withdraw_pending_in<Y>( storage, ctx );

        // Redeem
        let (sui_token, _) = vault::redeem_non_entry( wrapper, vault_global, pt_to_redeem, ctx );

        let sui_balance = coin::into_balance(sui_token);

        balance::join(&mut pool.coin_x, sui_balance);

    }

    // ======== Public Functions =========

    /// Add liquidity to the `Pool`. Sender needs to provide both
    /// `Coin<X>` and `Coin<Y>`, and in exchange he gets `Coin<LP>` -
    /// liquidity provider tokens.
    public fun add_liquidity_non_entry<X,Y>(
        pool: &mut Pool<X, Y>,
        coin_x: Coin<X>,
        coin_x_min: u64,
        coin_y: Coin<Y>,
        coin_y_min: u64,
        is_order: bool,
        ctx: &mut TxContext
    ): (Coin<LP<X, Y>>, vector<u64>, bool) {
        assert!(is_order, ERR_MUST_BE_ORDER);

        let coin_x_value = coin::value(&coin_x);
        let coin_y_value = coin::value(&coin_y);

        assert!(coin_x_value > 0 && coin_y_value > 0, ERR_ZERO_AMOUNT);

        let coin_x_balance = coin::into_balance(coin_x);
        let coin_y_balance = coin::into_balance(coin_y);

        let (coin_x_reserve, coin_y_reserve, lp_supply) = get_reserves_size(pool, is_order);

        let (optimal_coin_x, optimal_coin_y, is_pool_creator) = calc_optimal_coin_values( 
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

        let coin_x_amount = balance::join(&mut pool.coin_x, coin_x_balance);
        let coin_y_amount = balance::join(&mut pool.coin_y, coin_y_balance);

        assert!(coin_x_amount < MAX_POOL_VALUE, ERR_POOL_FULL);
        assert!(coin_y_amount < MAX_POOL_VALUE, ERR_POOL_FULL);

        let balance = balance::increase_supply(&mut pool.lp_supply, provided_liq);

        let return_values = vector::empty<u64>();
        vector::push_back(&mut return_values, coin_x_value);
        vector::push_back(&mut return_values, coin_y_value);
        vector::push_back(&mut return_values, provided_liq);

        (coin::from_balance(balance, ctx), return_values, is_pool_creator)
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

    public fun has_registered<X, Y>(global: &AMMGlobal): bool {
        let lp_name = generate_lp_name<X, Y>();
        bag::contains_with_type<String, Pool<X, Y>>(&global.pools, lp_name)
    }

    public fun generate_lp_name<X, Y>(): String {
        let lp_name = string::utf8(b"");
        string::append_utf8(&mut lp_name, b"LP-");

        if (is_order<X, Y>()) {
            string::append_utf8(&mut lp_name, into_bytes(into_string(get<X>())));
            string::append_utf8(&mut lp_name, b"-");
            string::append_utf8(&mut lp_name, into_bytes(into_string(get<Y>())));
        } else {
            string::append_utf8(&mut lp_name, into_bytes(into_string(get<Y>())));
            string::append_utf8(&mut lp_name, b"-");
            string::append_utf8(&mut lp_name, into_bytes(into_string(get<X>())));
        };

        lp_name
    }

    public fun is_order<X, Y>(): bool {
        let comp = comparator::compare(&get<X>(), &get<Y>());
        assert!(!comparator::is_equal(&comp), ERR_THE_SAME_COIN);

        if (comparator::is_smaller_than(&comp)) {
            true
        } else {
            false
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

    /// Get most used values in a handy way:
    /// - amount of Coin<X>
    /// - amount of Coin<Y>
    /// - total supply of LP<X,Y>
    public fun get_reserves_size<X, Y>(pool: &Pool<X, Y>, is_order: bool): (u64, u64, u64) {

        if (!pool.is_lbp) {
            (
                balance::value(&pool.coin_x),
                balance::value(&pool.coin_y),
                balance::supply_value(&pool.lp_supply)
            )
        } else {

            let params = option::borrow(&pool.lbp_params);
            let is_vault = lbp::is_vault(params);

            // Initialize virtual amounts for X and Y tokens
            let virtual_amount_x = 0;
            let virtual_amount_y = 0;
            
            if (is_vault) {
                
                // Check if the current transaction is a buy transaction.
                let is_buy = if (is_order) {
                    lbp::is_buy(params)  
                } else {
                    !lbp::is_buy(params)
                };

                let storage = option::borrow(&pool.lbp_storage);
                let pending_in_amount = lbp::pending_in_amount(storage);

                // If the transaction is for X tokens and is a buy, set the virtual amount for X tokens.
                if (comparator::is_equal(&comparator::compare(&get<SUI>(), &get<X>())) && is_buy) {
                    virtual_amount_x = pending_in_amount;
                };

                // If the transaction is for Y tokens and is a buy, set the virtual amount for Y tokens.
                if (comparator::is_equal(&comparator::compare(&get<SUI>(), &get<Y>())) && is_buy) {
                    virtual_amount_y = pending_in_amount
                };
            };

            (
                balance::value(&pool.coin_x)+virtual_amount_x,
                balance::value(&pool.coin_y)+virtual_amount_y,
                balance::supply_value(&pool.lp_supply)
            )
        }
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
    ): (u64, u64, bool) {

        // If the pool has no existing liquidity, return the desired amounts.
        if (coin_x_reserve == 0 && coin_y_reserve == 0) {
            return (coin_x_desired, coin_y_desired, true)
        } else { 
            
            // For non-stable pools, use weighted math to compute optimal values.
            if (!pool.is_stable) {

                // Obtain the current weights of the pool
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
                    return (coin_x_desired, coin_y_needed, false)
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
                    return (coin_x_needed, coin_y_desired, false) 
                } 
            } else {
                // For stable pools, use stable math to compute the optimal values.
                 let coin_y_returned = stable_math::get_amount_out(
                    coin_x_desired,
                    coin_x_reserve, 
                    coin_y_reserve
                );

                if (coin_y_returned <= coin_y_desired) {
                    assert!(coin_y_returned >= coin_y_min, ERR_INSUFFICIENT_COIN_Y);
                    return (coin_x_desired, coin_y_returned, false)
                } else {
                    let coin_x_returned = stable_math::get_amount_out(
                        coin_y_desired,
                        coin_y_reserve, 
                        coin_x_reserve
                    );

                    assert!(coin_x_returned <= coin_x_desired, ERR_OVERLIMIT);
                    assert!(coin_x_returned >= coin_x_min, ERR_INSUFFICIENT_COIN_X);
                    return (coin_x_returned, coin_y_desired, false) 
                } 
            }
            
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

                let minimal_liquidity = balance::increase_supply(
                    &mut pool.lp_supply,
                    MINIMAL_LIQUIDITY
                );
                balance::join(&mut pool.min_liquidity, minimal_liquidity);

                initial_liq - MINIMAL_LIQUIDITY
            } else {
                weighted_math::compute_derive_lp( optimal_coin_x, optimal_coin_y, weight_x, weight_y, coin_x_reserve, coin_y_reserve, lp_supply )
            }
        } else {
            if (0 == lp_supply) {

                let initial_liq = stable_math::compute_initial_lp(  optimal_coin_x , optimal_coin_y  );
                assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

                let minimal_liquidity = balance::increase_supply(
                    &mut pool.lp_supply,
                    MINIMAL_LIQUIDITY
                );
                balance::join(&mut pool.min_liquidity, minimal_liquidity);

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

        if (!pool.is_stable) {

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
        } else {
            
            let multiplier = fixed_point64::create_from_rational( (lp_val as u128), (lp_supply as u128)  );
 
            let coin_x_out = fixed_point64::multiply_u128( (reserve_x_amount as u128), multiplier ); 
            let coin_y_out = fixed_point64::multiply_u128( (reserve_y_amount as u128), multiplier );

            balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp_coin));

            (
                coin::take(&mut pool.coin_x, (coin_x_out as u64), ctx),
                coin::take(&mut pool.coin_y, (coin_y_out as u64), ctx)
            )
        }
    }

    /// Swap Coin<X> for Coin<Y>
    /// Returns Coin<Y>
    public fun swap_out_non_entry<X, Y>(
        global: &mut AMMGlobal,
        coin_in: Coin<X>,
        coin_out_min: u64,
        is_order: bool,
        ctx: &mut TxContext
    ): vector<u64> {
        assert!(coin::value<X>(&coin_in) > 0, ERR_ZERO_AMOUNT);

        let treasury_address = get_treasury_address(global);

        if (is_order) {

            let pool = get_mut_pool<X, Y>(global, is_order);
            let (coin_x_reserve, coin_y_reserve, _lp) = get_reserves_size(pool, is_order);
            assert!(coin_x_reserve > 0 && coin_y_reserve > 0, ERR_RESERVES_EMPTY);
            let coin_x_in = coin::value(&coin_in);

            let (coin_x_after_fees, coin_x_fee) = weighted_math::get_fee_to_treasury( pool.swap_fee , coin_x_in);

            // Obtain the current weights of the pool
            let (weight_x, weight_y ) = pool_current_weight<X,Y>(pool);
 
            let coin_y_out = get_amount_out(
                pool.is_stable,
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

            if (pool.is_lbp) {
                let params = option::borrow_mut(&mut pool.lbp_params);
                let is_buy = lbp::is_buy(params);  
                lbp::verify_and_adjust_amount(params, is_buy, coin_x_in, coin_y_out, false );
            };

            let coin_x_balance = coin::into_balance(coin_in);
            transfer::public_transfer(
                coin::from_balance(balance::split(&mut coin_x_balance, coin_x_fee) , ctx),
                treasury_address
            );
            balance::join(&mut pool.coin_x, coin_x_balance);
            let coin_out = coin::take(&mut pool.coin_y, coin_y_out, ctx);
            transfer::public_transfer(coin_out, tx_context::sender(ctx));
 
            let return_values = vector::empty<u64>();
            vector::push_back(&mut return_values, coin_x_in);
            vector::push_back(&mut return_values, 0);
            vector::push_back(&mut return_values, 0);
            vector::push_back(&mut return_values, coin_y_out);
            return_values
        } else {

            let pool = get_mut_pool<Y, X>(global, !is_order);
            let (coin_x_reserve, coin_y_reserve, _lp) = get_reserves_size(pool, is_order);
            assert!(coin_x_reserve > 0 && coin_y_reserve > 0, ERR_RESERVES_EMPTY);
            let coin_y_in = coin::value(&coin_in);

            // Obtain the current weights of the pool
            let (weight_x, weight_y ) = pool_current_weight(pool);

            let (coin_y_after_fees, coin_y_fee) =  weighted_math::get_fee_to_treasury( pool.swap_fee , coin_y_in);
            let coin_x_out = get_amount_out(
                pool.is_stable,
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

            if (pool.is_lbp) {
                let params = option::borrow_mut(&mut pool.lbp_params);
                let is_buy = lbp::is_buy(params);   
                lbp::verify_and_adjust_amount(params, !is_buy, coin_y_in, coin_x_out, false);
            };

            let coin_y_balance = coin::into_balance(coin_in);
            transfer::public_transfer(
                coin::from_balance(balance::split(&mut coin_y_balance, coin_y_fee) , ctx),
                treasury_address
            );
            balance::join(&mut pool.coin_y, coin_y_balance);
            let coin_out = coin::take(&mut pool.coin_x, coin_x_out, ctx);
            transfer::public_transfer(coin_out, tx_context::sender(ctx));

            let return_values = vector::empty<u64>();
            vector::push_back(&mut return_values, 0);
            vector::push_back(&mut return_values, coin_x_out);
            vector::push_back(&mut return_values, coin_y_in);
            vector::push_back(&mut return_values, 0);
            return_values
        }
    }

    public fun get_amount_out(is_stable: bool, coin_in: u64, reserve_in: u64, weight_in: u64, reserve_out: u64, weight_out: u64) : u64 {
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

    // Retrieve the current weights of the pool
    public fun pool_current_weight<X,Y>(pool: &Pool<X, Y> ): (u64, u64)  {
        
        if (!pool.is_lbp) {
            ( pool.weight_x, pool.weight_y )
        } else {
            let params = option::borrow(&pool.lbp_params);
            lbp::current_weight( params ) 
        }

    }

    // Retrieves information about the LBP pool
    public fun lbp_info<X,Y>( global: &mut AMMGlobal) : (u64, u64, u64, u64) {
        let is_order = is_order<X, Y>();

        if (is_order) {
            let pool = get_mut_pool<X, Y>(global, is_order);

            assert!( pool.is_lbp == true , ERR_NOT_LBP);
            
            let ( weight_x, weight_y ) = pool_current_weight(pool);
            let params = option::borrow(&pool.lbp_params);

            (weight_x,  weight_y, lbp::total_amount_collected(params), lbp::total_target_amount(params))
        } else {
            let pool = get_mut_pool<Y, X>(global, true);
            assert!( pool.is_lbp == true , ERR_NOT_LBP);

            let ( weight_y, weight_x ) = pool_current_weight(pool);
            let params = option::borrow(&pool.lbp_params);

            ( weight_x, weight_y, lbp::total_amount_collected(params), lbp::total_target_amount(params))
        }
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
        assert!(contained,ERR_NOT_FOUND);
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

    // Set a new target amount for LBP
    public entry fun lbp_set_target_amount<Y>(global: &mut AMMGlobal, _manager_cap: &mut ManagerCap, new_target_amount: u64) {
        assert!( has_registered<SUI, Y>(global)  , ERR_NOT_REGISTERED);
        
        let is_order = is_order<SUI, Y>();
        let pool = get_mut_pool<SUI, Y>(global, is_order);
        assert!( pool.is_lbp , ERR_NOT_LBP);

        let params = option::borrow_mut(&mut pool.lbp_params);

        lbp::set_new_target_amount(  params, new_target_amount );
    }

    // Enable/Disable buy with pair or with vault tokens
    public entry fun lbp_enable_buy_with_pair_and_vault<Y>(global: &mut AMMGlobal, _manager_cap: &mut ManagerCap, enable_pair: bool, enable_vault: bool) {
        assert!( has_registered<SUI, Y>(global)  , ERR_NOT_REGISTERED);
        
        let is_order = is_order<SUI, Y>();
        let pool = get_mut_pool<SUI, Y>(global, is_order);
        assert!( pool.is_lbp , ERR_NOT_LBP);

        let params = option::borrow_mut(&mut pool.lbp_params);

        lbp::enable_buy_with_pair(  params, enable_pair );
        lbp::enable_buy_with_vault(  params, enable_vault );
    }

    // ======== Internal Functions =========

    fun check_whitelist(global: &AMMGlobal, sender: address) {
        let (contained, _) = vector::index_of<address>(&global.whitelist, &sender);
        assert!(contained, ERR_UNAUTHORISED);
    }
 
    fun get_treasury_address(global: &AMMGlobal) : address {
        global.treasury
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

    #[test_only]
    public fun add_liquidity_for_testing<X, Y>(
        global: &mut AMMGlobal,
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
        weight_x: u64,
        weight_y: u64, 
        is_stable: bool,
        ctx: &mut TxContext
    ): (Coin<LP<X, Y>>, vector<u64>, bool) {
        let is_order = is_order<X, Y>();
        if (!has_registered<X, Y>(global)) {
            if (!is_stable) {
                register_pool<X, Y>(global, weight_x, weight_y, ctx);
            } else {
                register_stable_pool<X,Y>( global, ctx );
            };
        };

        let pool = get_mut_pool<X, Y>(global, is_order);

        add_liquidity_non_entry(
            pool,
            coin_x,
            1,
            coin_y,
            1,
            is_order,
            ctx
        )
    }

    #[test_only]
    public fun remove_liquidity_for_testing<X, Y>(
        global: &mut AMMGlobal,
        lp_coin: Coin<LP<X, Y>>,
        ctx: &mut TxContext
    ): (Coin<X>, Coin<Y>) {

        let is_order = is_order<X, Y>();
        let pool = get_mut_pool<X, Y>(global, is_order);

        remove_liquidity_non_entry<X, Y>(
            pool,
            lp_coin,
            is_order,
            ctx
        )
    }

    #[test_only]
    public fun swap_for_testing<X, Y>(
        global: &mut AMMGlobal,
        coin_in: Coin<X>,
        coin_out_min: u64,
        ctx: &mut TxContext
    ): vector<u64> {
        swap_out_non_entry<X, Y>(
            global,
            coin_in,
            coin_out_min,
            is_order<X, Y>(),
            ctx
        )
    }

}