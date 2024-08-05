// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// Legato Options allow for short and long put and call options contracts on Sui based on Hegic v.1
// This version aims to be minimal and is deployed to Testnet to experiment with the product.

module legato_options::options_manager {

    use sui::object::{Self, ID, UID};
    use sui::tx_context::{ Self, TxContext};
    use sui::transfer; 
    use sui::table::{ Self, Table};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance::{ Self, Supply, Balance};  
    use sui::event::emit;

    use std::type_name::{get, into_string};
    use std::ascii::into_bytes;
    use std::string::{ Self, String }; 
    use std::vector; 

    use legato_options::mock_usdy::{MOCK_USDY}; 
    use legato_math::fixed_point64::{Self, FixedPoint64}; 
    use legato_math::math128;
    use legato_math::math_fixed64;

    // ======== Constants ========

    // Minimal liquidity.
    const MINIMAL_LIQUIDITY: u64 = 1000; 
    // Default settlement fee of 0.5% in fixed-point
    const DEFAULT_FEE: u128 = 92233720368547758;
    // Default implied volatility rate of 55% in fixed-point
    const DEFAULT_IV_RATE: u64 = 5500;
    // Decimals for SUI and USDY tokens
    const DECIMALS: u64 = 9;

    // ======== Errors ========

    const ERR_ZERO_VALUE: u64 = 1;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 2;
    const ERR_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 3;
    const ERR_IV_TOO_LOW: u64 = 4;
    const ERR_INVALID_PERIOD: u64 = 5;
    const ERR_FEED_NOT_SETUP: u64 = 6;
    const ERR_INVALID_DECIMAL: u64 = 7;
    const ERR_PREMIUM_TOO_LOW: u64 = 8;
    const ERR_INSUFFICIENT_COIN_VALUE: u64 = 9;
    const ERR_INVALID_ID: u64 = 10;
    const ERR_OPTION_EXPIRED: u64 = 11;
    const ERR_NOT_ACTIVE: u64 = 12;
    const ERR_NOT_SUPPORT: u64 = 13;
    const ERR_POOL_ALREADY_REGISTERED: u64 = 14; 
    const ERR_WRONG_TYPE: u64 = 15;
    const ERR_CURRENT_PRICE_TOO_LOW: u64 = 16;
    const ERR_INVALID_OPTION_ID: u64 = 17;
    const ERR_INVALID_HOLDER: u64 = 18;
    const ERR_INSUFFICIENT_BALANCE: u64 = 19;
    const ERR_CURRENT_PRICE_TOO_HIGH: u64 = 20;

    // ======== Structs =========

    // An LP share token represents a user's ownership in a respective liquidity pool.
    public struct WRITE_SUI has drop, store {}
    public struct WRITE_STABLE has drop, store {}

    // Provide price data in the system.
    // Use manual updates for the current Testnet version.
    // May integrate with Pyth Oracle for the Mainnet.
    public struct Feed has store {
        decimal: u64,
        price: u64,
        updated_epoch: u64
    }

    // An option contract 
    public struct Option has store {
        holder: address,
        call_or_put: bool,
        strike: u64, // Strike price of the option
        amount: u64, // Amount of the underlying asset covered by the option.
        premium: u64, // Premium paid by the holder to purchase this option
        expiration: u64, // Epoch time when the option expires.
        is_active: bool,
        is_exercised: bool,
        is_expired: bool
    }

    // Liquidity Pool for Sui tokens to distribute P&L.
    public struct CallPool has store {
        lp_supply: Supply<WRITE_SUI>,
        min_liquidity: Balance<WRITE_SUI>,
        balance: Balance<SUI>,
        locked_amount: u64,
        locked_premium: u64
    }

    // Liquidity Pool for stablecoins to distribute P&L.
    public struct PutPool has store { 
        lp_supply: Supply<WRITE_STABLE>,
        min_liquidity: Balance<WRITE_STABLE>,
        balance: Balance<MOCK_USDY>,
        locked_amount: u64,
        locked_premium: u64
    }

    // The global state
    public struct OptionsGlobal has key {
        id: UID,
        call_pool: CallPool,
        put_pool: PutPool,
        option_contracts: vector<Option>,
        feeds: Table<String, Feed>, // Price feeders 
        treasury: address, // Address that collect settlement fees
        settlement_fee: FixedPoint64,
        iv_rate: u64
    }

    // Using ManagerCap for admin permission
    public struct ManagerCap has key {
        id: UID
    }

    public struct CreateOptionEvent has copy, drop {
        global: ID,
        option_id: u64,
        holder: address,
        call_or_put: bool,
        epoch: u64,
        expiration: u64,
        option_amount: u64,
        premium_paid: u64,
        strike_price: u64,
    }

    public struct ExerciseOptionEvent has copy, drop {
        global: ID,
        option_id: u64,
        holder: address,
        call_or_put: bool,
        epoch: u64,
        profit: u64
    }   

    public struct ExpireOptionEvent has copy, drop {
        global: ID,
        option_id: u64,
        holder: address,
        call_or_put: bool
    }

    public struct AddLiquidityEvent has copy, drop {
        global: ID,
        sui_or_stable: bool,
        input_amount: u64,
        lp_share: u64,
        epoch: u64,
        sender: address
    }

    public struct RemoveLiquidityEvent has copy, drop {
        global: ID,
        sui_or_stable: bool,
        lp_amount: u64,
        output_amount: u64,
        epoch: u64,
        sender: address
    }

    // Initializes the options module
    fun init(ctx: &mut TxContext) {
        
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        let lp_supply_sui = balance::create_supply(WRITE_SUI {});
        let lp_supply_stable = balance::create_supply(WRITE_STABLE {});

        // Initialize the global state
        let global = OptionsGlobal {
            id: object::new(ctx),
            call_pool: CallPool {
                lp_supply: lp_supply_sui,
                min_liquidity: balance::zero<WRITE_SUI>(),
                balance: balance::zero<SUI>(),
                locked_amount: 0,
                locked_premium: 0
            },
            put_pool: PutPool {
                lp_supply: lp_supply_stable,
                min_liquidity: balance::zero<WRITE_STABLE>(),
                balance: balance::zero<MOCK_USDY>(),
                locked_amount: 0,
                locked_premium: 0
            },
            option_contracts: vector::empty<Option>(),
            feeds : table::new(ctx),
            treasury: tx_context::sender(ctx),
            settlement_fee: fixed_point64::create_from_raw_value( DEFAULT_FEE ),
            iv_rate: DEFAULT_IV_RATE
        };
    
        transfer::share_object(global)
    
    }

    // ======== Entry Points =========

    // Creates a new call option and pays the premium
    public entry fun create_call_option(
        options_global: &mut OptionsGlobal,
        period: u64, // The period must be between 1 and 30 epochs.
        amount: u64, // Option amount
        strike: u64, // Strike price
        sui_coin: &mut Coin<SUI>, // Sui used to pay the premium for the option
        ctx: &mut TxContext
    ) {
        assert!( period > 0 && period <= 30, ERR_INVALID_PERIOD );
        assert!( strike > 0, ERR_ZERO_VALUE );

        // TODO: check remaining assets on the pool

        let strike_price = fixed_point64::create_from_rational( (strike as u128), math128::pow(10, (DECIMALS as u128)) );
        let strike_amount = ( fixed_point64::multiply_u128( (amount as u128) , strike_price ) as u64 );

        assert!( strike_amount > 0, ERR_ZERO_VALUE );

        let ( total, settlement_fee ) = calculate_options_prices(options_global, true, period, amount, strike);

        assert!( settlement_fee < total , ERR_PREMIUM_TOO_LOW  ); 

        let sui_coin_value = coin::value(sui_coin);
        assert!( sui_coin_value >= total, ERR_INSUFFICIENT_COIN_VALUE );

        let treasury_address = get_treasury_address(options_global);
        let premium = (total-settlement_fee);

        // Send premium to the pool 
        let coin_deposited = coin::split( sui_coin, total, ctx);
        let mut coin_deposited_balance = coin::into_balance( coin_deposited );
        transfer::public_transfer(
            coin::from_balance(balance::split(&mut coin_deposited_balance, settlement_fee) , ctx),
            treasury_address
        );
        balance::join(&mut options_global.call_pool.balance, coin_deposited_balance );

        options_global.call_pool.locked_premium = options_global.call_pool.locked_premium+premium;
        options_global.call_pool.locked_amount = options_global.call_pool.locked_amount+amount;

        update_expired_contracts( options_global, ctx );

        let option_id = vector::length(&options_global.option_contracts);

        vector::push_back(
            &mut options_global.option_contracts,
            Option {
                call_or_put: true,
                holder: tx_context::sender(ctx),
                strike,
                amount,
                premium,
                expiration: tx_context::epoch(ctx)+period,
                is_active: true,
                is_exercised: false,
                is_expired: false
            }
        );

        emit(
            CreateOptionEvent {
                global: object::id(options_global),
                option_id,
                holder: tx_context::sender(ctx),
                call_or_put: true,
                epoch: tx_context::epoch(ctx),
                expiration: tx_context::epoch(ctx)+period,
                option_amount: amount,
                premium_paid: premium,
                strike_price: strike
            }
        )
    }

    // Creates a new put option and pays the premium
    public entry fun create_put_option(
        options_global: &mut OptionsGlobal,
        period: u64, // The period must be between 1 and 30 epochs.
        amount: u64, // Option amount
        strike: u64, // Strike price
        stablecoin_coin: &mut Coin<MOCK_USDY>, // Sui used to pay the premium for the option
        ctx: &mut TxContext
    ) {
        assert!( period > 0 && period <= 30, ERR_INVALID_PERIOD );
        assert!( strike > 0, ERR_ZERO_VALUE );

        // TODO: check remaining assets on the pool

        let strike_price = fixed_point64::create_from_rational( (strike as u128), math128::pow(10, (DECIMALS as u128)) );
        let strike_amount = ( fixed_point64::multiply_u128( (amount as u128) , strike_price ) as u64 );

        assert!( strike_amount > 0, ERR_ZERO_VALUE );

        let ( total, settlement_fee ) = calculate_options_prices(options_global, false, period, amount, strike);

        assert!( settlement_fee < total , ERR_PREMIUM_TOO_LOW  ); 

        let stablecoin_coin_value = coin::value(stablecoin_coin);
        assert!( stablecoin_coin_value >= total, ERR_INSUFFICIENT_COIN_VALUE );

        let treasury_address = get_treasury_address(options_global);
        let premium = (total-settlement_fee);

        // Send premium to the pool 
        let coin_deposited = coin::split( stablecoin_coin, total, ctx);
        let mut coin_deposited_balance = coin::into_balance( coin_deposited );
        transfer::public_transfer(
            coin::from_balance(balance::split(&mut coin_deposited_balance, settlement_fee) , ctx),
            treasury_address
        );
        balance::join(&mut options_global.put_pool.balance, coin_deposited_balance );

        options_global.put_pool.locked_premium = options_global.put_pool.locked_premium+premium;
        options_global.put_pool.locked_amount = options_global.put_pool.locked_amount+amount;

        update_expired_contracts( options_global, ctx );

        let option_id = vector::length(&options_global.option_contracts);

        vector::push_back(
            &mut options_global.option_contracts,
            Option {
                call_or_put: false,
                holder: tx_context::sender(ctx),
                strike,
                amount,
                premium,
                expiration: tx_context::epoch(ctx)+period,
                is_active: true,
                is_exercised: false,
                is_expired: false
            }
        );

        emit(
            CreateOptionEvent {
                global: object::id(options_global),
                option_id,
                holder: tx_context::sender(ctx),
                call_or_put: false,
                epoch: tx_context::epoch(ctx),
                expiration: tx_context::epoch(ctx)+period,
                option_amount: amount,
                premium_paid: premium,
                strike_price: strike
            }
        )

    }

    // Exercise a call option contract if eligible and provide the profit
    public entry fun exercise_call_option(options_global: &mut OptionsGlobal, option_id: u64, ctx: &mut TxContext) {
        assert!( vector::length( &options_global.option_contracts ) > option_id, ERR_INVALID_OPTION_ID );

        let current_price = get_sui_price(options_global);
        let option = vector::borrow_mut( &mut options_global.option_contracts, option_id );
        assert!( option.expiration >= tx_context::epoch(ctx), ERR_OPTION_EXPIRED );
        assert!( option.is_active, ERR_NOT_ACTIVE);
        assert!( option.call_or_put == true , ERR_WRONG_TYPE );
        assert!( option.holder == tx_context::sender(ctx), ERR_INVALID_HOLDER);

        // TODO: check remaining assets on the pool

        option.is_active = false;
        option.is_exercised = true;

        let strike_price = fixed_point64::create_from_rational( (option.strike as u128), math128::pow(10, (DECIMALS as u128)) );

        // Ensure the current price is greater than or equal to the strike price
        assert!( fixed_point64::greater_or_equal( current_price, strike_price ), ERR_CURRENT_PRICE_TOO_LOW );

        let mut profit = 0;

        // Transfer profit, if the current price is greater than the strike price
        if ( fixed_point64::greater( current_price, strike_price )  ) {
            let multiplier = math_fixed64::mul_div( fixed_point64::sub( current_price, strike_price), fixed_point64::create_from_u128(1) , current_price );
            profit = (fixed_point64::multiply_u128( (option.amount as u128), multiplier ) as u64);

            transfer::public_transfer(
                coin::from_balance(balance::split(&mut options_global.call_pool.balance, profit) , ctx),
                tx_context::sender(ctx)
            );
        
        };

        // Unlock funds
        options_global.call_pool.locked_premium = if (options_global.call_pool.locked_premium > option.premium) {
            options_global.call_pool.locked_premium-option.premium
        } else {
            0
        };

        options_global.call_pool.locked_amount = if (options_global.call_pool.locked_amount > option.amount) {
            options_global.call_pool.locked_amount-option.amount
        } else {
            0
        };

        update_expired_contracts( options_global, ctx );

        emit(
            ExerciseOptionEvent {
                global: object::id(options_global),
                option_id,
                holder: tx_context::sender(ctx),
                call_or_put: true,
                epoch: tx_context::epoch(ctx),
                profit
            }
        )

    }

    // Exercise a put option contract if eligible and provide the profit
    public entry fun exercise_put_option(options_global: &mut OptionsGlobal, option_id: u64, ctx: &mut TxContext) {
        assert!( vector::length( &options_global.option_contracts ) > option_id, ERR_INVALID_OPTION_ID );

        let current_price = get_sui_price(options_global);
        let option = vector::borrow_mut( &mut options_global.option_contracts, option_id );
        assert!( option.expiration >= tx_context::epoch(ctx), ERR_OPTION_EXPIRED );
        assert!( option.is_active, ERR_NOT_ACTIVE);
        assert!( option.call_or_put == false , ERR_WRONG_TYPE );
        assert!( option.holder == tx_context::sender(ctx), ERR_INVALID_HOLDER);

        // TODO: check remaining assets on the pool

        option.is_active = false;
        option.is_exercised = true;

        let strike_price = fixed_point64::create_from_rational( (option.strike as u128), math128::pow(10, (DECIMALS as u128)) );

        // Ensure the current price is greater than or equal to the strike price
        assert!( fixed_point64::greater_or_equal( strike_price, current_price ), ERR_CURRENT_PRICE_TOO_HIGH );

        let mut profit = 0;

        // Transfer profit, if the strike price is greater than the current price
        if ( fixed_point64::greater( strike_price, current_price )  ) {
            let multiplier = fixed_point64::sub( strike_price, current_price);
            profit = (fixed_point64::multiply_u128( (option.amount as u128), multiplier ) as u64);

            transfer::public_transfer(
                coin::from_balance(balance::split(&mut options_global.put_pool.balance, profit) , ctx),
                tx_context::sender(ctx)
            );
        };

        // Unlock funds
        options_global.put_pool.locked_premium = if (options_global.put_pool.locked_premium > option.premium) {
            options_global.put_pool.locked_premium-option.premium
        } else {
            0
        };

        options_global.put_pool.locked_amount = if (options_global.put_pool.locked_amount > option.amount) {
            options_global.put_pool.locked_amount-option.amount
        } else {
            0
        };

        update_expired_contracts( options_global, ctx );

        emit(
            ExerciseOptionEvent {
                global: object::id(options_global),
                option_id,
                holder: tx_context::sender(ctx),
                call_or_put: false,
                epoch: tx_context::epoch(ctx),
                profit
            }
        )
    }

    // Provides liquidity by depositing SUI coins into the pool,
    // allowing for short call options and earning premiums from long traders.
    public entry fun provide_sui(
        options_global: &mut OptionsGlobal, 
        sui_coin: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let sui_coin_value = coin::value(&sui_coin);
        assert!(sui_coin_value >= 0, ERR_ZERO_VALUE);

        let sui_coin_balance = coin::into_balance(sui_coin);
        let lp_supply = balance::supply_value(&options_global.call_pool.lp_supply);
        let current_balance = balance::value(&options_global.call_pool.balance);

        // Calculate the amount of LP tokens to mint
        let lp_amount_to_mint = if (lp_supply == 0) {
            // Check if initial liquidity is sufficient.
            assert!(sui_coin_value > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

            let minimal_liquidity = balance::increase_supply(
                &mut options_global.call_pool.lp_supply,
                MINIMAL_LIQUIDITY
            );
            balance::join(&mut options_global.call_pool.min_liquidity, minimal_liquidity);
            // Calculate the initial LP amount
            sui_coin_value - MINIMAL_LIQUIDITY
        } else {
            let ratio = fixed_point64::create_from_rational((sui_coin_value as u128) , (current_balance as u128));
            let total_share = fixed_point64::multiply_u128( (lp_supply as u128) , ratio);
            (total_share as u64)
        };

         // Ensure a valid amount of LP tokens 
        assert!(lp_amount_to_mint > 0, ERR_INSUFFICIENT_LIQUIDITY_MINTED);

        // Deposit the SUI balance into the pool.
        balance::join(&mut options_global.call_pool.balance, sui_coin_balance);

        // Mint LP shares to the sender
        let balance = balance::increase_supply(&mut options_global.call_pool.lp_supply, lp_amount_to_mint);
        let lp_coin = coin::from_balance(balance, ctx);

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));

        update_expired_contracts( options_global, ctx );

        emit(
            AddLiquidityEvent {
                global: object::id(options_global),
                sui_or_stable: true,
                input_amount: sui_coin_value,
                lp_share: lp_amount_to_mint,
                epoch: tx_context::epoch(ctx),
                sender: tx_context::sender(ctx)
            }
        )
    }

    // Provides liquidity by depositing stablecoins into the pool,
    // allowing for short put options and earning premiums from long traders.
    public entry fun provide_stable(
        options_global: &mut OptionsGlobal,
        usdy_coin: Coin<MOCK_USDY>,
        ctx: &mut TxContext
    ) {
        let usdy_coin_value = coin::value(&usdy_coin);
        assert!(usdy_coin_value >= 0, ERR_ZERO_VALUE);

        let usdy_coin_balance = coin::into_balance(usdy_coin);
        let lp_supply = balance::supply_value(&options_global.put_pool.lp_supply);
        let current_balance = balance::value(&options_global.put_pool.balance);

        // Calculate the amount of LP tokens to mint
        let lp_amount_to_mint = if (lp_supply == 0) {
            // Check if initial liquidity is sufficient.
            assert!(usdy_coin_value > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);

            let minimal_liquidity = balance::increase_supply(
                &mut options_global.put_pool.lp_supply,
                MINIMAL_LIQUIDITY
            );
            balance::join(&mut options_global.put_pool.min_liquidity, minimal_liquidity);
            // Calculate the initial LP amount
            usdy_coin_value - MINIMAL_LIQUIDITY
        } else {
            let ratio = fixed_point64::create_from_rational((usdy_coin_value as u128) , (current_balance as u128));
            let total_share = fixed_point64::multiply_u128( (lp_supply as u128) , ratio);
            (total_share as u64)
        };

        // Ensure a valid amount of LP tokens 
        assert!(lp_amount_to_mint > 0, ERR_INSUFFICIENT_LIQUIDITY_MINTED);

        // Deposit the USDY balance into the pool.
        balance::join(&mut options_global.put_pool.balance, usdy_coin_balance);

        // Mint LP shares to the sender
        let balance = balance::increase_supply(&mut options_global.put_pool.lp_supply, lp_amount_to_mint);
        let lp_coin = coin::from_balance(balance, ctx);

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));

        update_expired_contracts( options_global, ctx );

        emit(
            AddLiquidityEvent {
                global: object::id(options_global),
                sui_or_stable: false,
                input_amount: usdy_coin_value,
                lp_share: lp_amount_to_mint,
                epoch: tx_context::epoch(ctx),
                sender: tx_context::sender(ctx)
            }
        )

    }
    
    // Burns WRITE_SUI LP tokens and withdraws SUI from the liquidity pool
    public entry fun withdraw_sui(options_global: &mut OptionsGlobal, lp_coin: Coin<WRITE_SUI>,ctx: &mut TxContext) {
        let lp_coin_value = coin::value(&lp_coin);
        assert!(lp_coin_value >= 0, ERR_ZERO_VALUE);

        // Calculate the multiplier based on the current pool balance / total LP supply
        let multiplier = fixed_point64::create_from_rational( ( balance::value( &options_global.call_pool.balance)  as u128), ( balance::supply_value( &options_global.call_pool.lp_supply)  as u128) );
        // Calculate the amount of SUI to withdraw
        let sui_amount = (fixed_point64::multiply_u128( (lp_coin_value as u128), multiplier) as u64);
        
        // Ensure the pool has sufficient SUI
        assert!( (balance::value( &options_global.call_pool.balance) - options_global.call_pool.locked_amount ) >= sui_amount, ERR_INSUFFICIENT_BALANCE );

        balance::decrease_supply(&mut options_global.call_pool.lp_supply, coin::into_balance(lp_coin));

        transfer::public_transfer(
            coin::from_balance(balance::split(&mut options_global.call_pool.balance, sui_amount) , ctx),
            tx_context::sender(ctx)
        );

        // Update any expired option contracts
        update_expired_contracts( options_global, ctx );

        emit(
            RemoveLiquidityEvent {
                global: object::id(options_global),
                sui_or_stable: true,
                lp_amount: lp_coin_value,
                output_amount: sui_amount,
                epoch: tx_context::epoch(ctx),
                sender: tx_context::sender(ctx)
            }
        )
    }

    // Burns WRITE_STABLE LP tokens and withdraws stablecoins from the liquidity pool
    public entry fun withdraw_stable(options_global: &mut OptionsGlobal, lp_coin: Coin<WRITE_STABLE>,ctx: &mut TxContext) {
        let lp_coin_value = coin::value(&lp_coin);
        assert!(lp_coin_value >= 0, ERR_ZERO_VALUE);

        // Calculate the multiplier based on the current pool balance / total LP supply
        let multiplier = fixed_point64::create_from_rational( ( balance::value( &options_global.put_pool.balance)  as u128), ( balance::supply_value( &options_global.put_pool.lp_supply)  as u128) );
        // Calculate the amount of stablecoins to withdraw
        let stable_amount = (fixed_point64::multiply_u128( (lp_coin_value as u128), multiplier) as u64);

        // Ensure the pool has sufficient tokens
        assert!( (balance::value( &options_global.put_pool.balance) - options_global.put_pool.locked_amount ) >= stable_amount, ERR_INSUFFICIENT_BALANCE );

        balance::decrease_supply(&mut options_global.put_pool.lp_supply, coin::into_balance(lp_coin));

        transfer::public_transfer(
            coin::from_balance(balance::split(&mut options_global.put_pool.balance, stable_amount) , ctx),
            tx_context::sender(ctx)
        );

        // Update any expired option contracts
        update_expired_contracts( options_global, ctx );

        emit(
            RemoveLiquidityEvent {
                global: object::id(options_global),
                sui_or_stable: false,
                lp_amount: lp_coin_value,
                output_amount: stable_amount,
                epoch: tx_context::epoch(ctx),
                sender: tx_context::sender(ctx)
            }
        )

    }


    // ======== Public Functions =========

    // Returns the current SUI price and its decimal places.
    public fun get_sui_price(global: &OptionsGlobal) : (FixedPoint64) {
        let feed_name = string::utf8(into_bytes(into_string(get<SUI>())));
        assert!( table::contains(&global.feeds, feed_name), ERR_FEED_NOT_SETUP);

        let current_feed = table::borrow( &global.feeds, feed_name);
        (fixed_point64::create_from_rational( (current_feed.price as u128), math128::pow(10, (current_feed.decimal as u128)) ))
    }

    // Calculate the actual options prices
    // Premium is the sum of period fees and strike fees
    public fun calculate_options_prices(global: &OptionsGlobal, call_or_put: bool, period: u64, amount: u64, strike: u64) : (u64, u64) {

        let current_price = get_sui_price(global);
        let strike_price = fixed_point64::create_from_rational( (strike as u128), math128::pow(10, (DECIMALS as u128)) );
        let settlement_fee = get_fee_to_treasury( global.settlement_fee, amount );
        let period_fee = get_period_fee(call_or_put, global.iv_rate, amount, period, strike_price, current_price);
        let strike_fee = get_strike_fee(call_or_put, amount, strike_price, current_price);

        let premium_fee = period_fee+strike_fee;

        (premium_fee, settlement_fee)
    }

    public fun get_fee_to_treasury(current_fee: FixedPoint64, input: u64): (u64) { 
        (fixed_point64::multiply_u128( (input as u128), current_fee) as u64)
    }

    public fun get_period_fee(call_or_put: bool, iv_rate: u64, amount: u64, period: u64, strike_price: FixedPoint64, current_price: FixedPoint64): u64 {
        if (call_or_put) {
            let numerator = math128::sqrt(( period  as u128) * 86400) * (iv_rate as u128);
            let multiplier = math_fixed64::mul_div( current_price, fixed_point64::create_from_rational(numerator, 100000000), strike_price );
            (fixed_point64::multiply_u128( (amount as u128), multiplier) as u64)
        } else {
            let numerator = math128::sqrt(( period  as u128) * 86400) * (iv_rate as u128);
            let multiplier = math_fixed64::mul_div( strike_price, fixed_point64::create_from_rational(numerator, 100000000), current_price );
            (fixed_point64::multiply_u128( (amount as u128), multiplier) as u64)
        }
    }

    public fun get_strike_fee(call_or_put: bool, amount: u64, strike_price: FixedPoint64, current_price: FixedPoint64): u64 {
        if (call_or_put && fixed_point64::less( strike_price, current_price )) {
            let multiplier = math_fixed64::mul_div( fixed_point64::sub( current_price, strike_price ), fixed_point64::create_from_u128(1) , current_price );
            (fixed_point64::multiply_u128( (amount as u128), multiplier) as u64)
        } else if (!call_or_put && fixed_point64::greater( strike_price, current_price )) {
            let multiplier = math_fixed64::mul_div( fixed_point64::sub( strike_price, current_price ), fixed_point64::create_from_u128(1) , current_price );
            (fixed_point64::multiply_u128( (amount as u128), multiplier) as u64)
        } else {
            0
        }
    }

    // ======== Only Governance =========

    // Manual updates feed data for the given type of coin.
    public entry fun update_price_feed<X>(global: &mut OptionsGlobal, _manager_cap: &mut ManagerCap, price: u64, decimal: u64,  ctx: &mut TxContext) {
        assert!( price > 0 , ERR_ZERO_VALUE);
        assert!( decimal > 0 && decimal <= 18, ERR_INVALID_DECIMAL );
        
        let feed_name = string::utf8(into_bytes(into_string(get<X>())));
        let updated_epoch = tx_context::epoch(ctx);

        if (!table::contains(&global.feeds, feed_name)) { 
            table::add(
                &mut global.feeds,
                feed_name,
                Feed {
                    decimal,
                    price,
                    updated_epoch
                }
            );
        } else {
            let current_feed = table::borrow_mut( &mut global.feeds, feed_name);
            current_feed.price = price;
            current_feed.decimal = decimal;
            current_feed.updated_epoch = updated_epoch;
        };
    }

    // Used for adjusting the options prices while balancing asset's implied volatility 
    public entry fun update_iv_rate(global: &mut OptionsGlobal, _manager_cap: &mut ManagerCap, new_value: u64) {
        assert!( new_value >= 1000 , ERR_IV_TOO_LOW);
        global.iv_rate = new_value;
    }

    // Updates the settlement fee 
    public entry fun update_settlement_fee(global: &mut OptionsGlobal, _manager_cap: &mut ManagerCap, fee_numerator: u128, fee_denominator: u128 ) {
        global.settlement_fee = fixed_point64::create_from_rational( fee_numerator, fee_denominator )
    }

    // ======== Internal Functions =========

    fun get_treasury_address(global: &OptionsGlobal) : address {
        global.treasury
    }

    // Updates the status of expired option contracts
    fun update_expired_contracts( options_global: &mut OptionsGlobal, ctx: &mut TxContext ) {
        // Initialize counter
        let mut item_count = 0;
        let current_epoch = tx_context::epoch(ctx);
        let global = object::id(options_global);

        // Iterate over each option contract
        while (item_count < vector::length(&options_global.option_contracts)) {
            
            let this_option = vector::borrow_mut( &mut options_global.option_contracts, item_count );

            // Check if the option is active and expired
            if (this_option.is_active == true && this_option.expiration > current_epoch) {

                this_option.is_active = false;
                this_option.is_expired = true;

                if (this_option.call_or_put == true) {
                    options_global.call_pool.locked_premium = if (options_global.call_pool.locked_premium > this_option.premium) {
                        options_global.call_pool.locked_premium-this_option.premium
                    } else {
                        0
                    };

                    options_global.call_pool.locked_amount = if (options_global.call_pool.locked_amount > this_option.amount) {
                        options_global.call_pool.locked_amount-this_option.amount
                    } else {
                        0
                    };
                } else {
                    options_global.put_pool.locked_premium = if (options_global.put_pool.locked_premium > this_option.premium) {
                        options_global.put_pool.locked_premium-this_option.premium
                    } else {
                        0
                    };

                    options_global.put_pool.locked_amount = if (options_global.put_pool.locked_amount > this_option.amount) {
                        options_global.put_pool.locked_amount-this_option.amount
                    } else {
                        0
                    };
                };

                emit(
                    ExpireOptionEvent {
                        global,
                        option_id: item_count,
                        holder: tx_context::sender(ctx),
                        call_or_put: this_option.call_or_put
                    }
                );

            };

            item_count = item_count + 1;
        };

    }

    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

}