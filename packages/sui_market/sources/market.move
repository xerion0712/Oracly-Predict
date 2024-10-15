// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// Legato's market prediction system enables users to bet on BTC or SUI price movements using SUI tokens.
// The system leverages AI to estimate probabilities by analyzing external market data, news and price trends.

// Liquidity-Adjusted Probability Formula:
// P(adjusted) = P(outcome) * weight + (L(outcome) / L(pool)) * (1 - weight)

module legato_market::market {

    use sui::url;
    use sui::sui::SUI; 
    use sui::transfer; 
    use sui::balance::{ Self, Supply, Balance}; 
    use sui::tx_context::{ Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::object::{ Self, ID, UID };
    use sui::table::{ Self, Table};
    use sui::event::emit;
    use sui::table_vec::{Self, TableVec};
    use sui_system::sui_system::{  SuiSystemState }; 

    use std::option::{ Self, Option};
    use std::vector; 

    use legato::vault::{ Self, VAULT, VaultGlobal };
    use legato_math::fixed_point64::{Self, FixedPoint64};

    // ======== Constants ========

    const SCALE: u64 = 10000; // Scaling factor for fixed-point calculations
    const DEFAULT_COMMISSION_FEE: u64 = 1000; // Default commission fee
    const DEFAULT_RESERVE_RATIO: u64 = 8000; // Default reserve ratio
    // const DEFAULT_WITHDRAW_DELAY: u64 = 2; // Default withdrawal delay, set to 2 epoch
    const DEFAULT_WEIGHT: u64 = 7000; // Default weight, 70%
    const DEFAULT_RATIO: u64 = 17500; // Default normalized ratio, 1.75
    const DEFAULT_MAX_BET_AMOUNT: u64 = 10_00000000; // 10 SUI
    const DEFAULT_MAX_ODDS: u64 = 80000; // 8.0
    const MIN_ADD_LIQUIDITY_AMOUNT: u64 = 1_00000000; // 1 SUI 
    const MINIMAL_LIQUIDITY: u64 = 1000;

    // ======== Errors ========

    const ERR_UNAUTHORIZED: u64 = 1;
    const ERR_INVALID_VALUE: u64  = 2;
    const ERR_NOT_FOUND: u64 = 3;
    const ERR_NOT_RESOLVED: u64 = 4;
    const ERR_OUTCOME_NOT_AVAILABLE: u64 = 5;
    const ERR_DUPLICATED: u64 = 6;
    const ERR_RESOLVED: u64 = 7;
    const ERR_ZERO_VALUE: u64 = 8;
    const ERR_PAUSED: u64 = 9;
    const ERR_TOO_LOW: u64 = 10;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 11;
    const ERR_MAX_BET_AMOUNT: u64 = 12;
    const ERR_INSUFFICIENT_CAPACITY: u64 = 13;
    const ERR_EXPIRED: u64  = 14;
    const ERR_EMPTY_LIST: u64 = 15;
    const ERR_PAYOUT_NOT_ENOUGH: u64 = 16;

    // ======== Structs =========

    // Using ManagerCap for admin permission
    public struct ManagerCap has key {
        id: UID
    }

    // The Pool token that will be used to mark the pool share
    public struct MARKET has drop {}

    public struct MarketConfig has store {
        total_1: u64, // Total bets on outcome 1
        total_2: u64, // Total bets on outcome 2
        total_3: u64, // Total bets on outcome 3
        total_4: u64, // Total bets on outcome 4
        probability_1: u64, // Probability assigned to outcome 1
        probability_2: u64, // Probability assigned to outcome 2
        probability_3: u64, // Probability assigned to outcome 3
        probability_4: u64, // Probability assigned to outcome 4
        ratio: u64, // A ratio used to adjust the odds, default is 2.5
        resolved: bool, // Whether the market has been resolved
        winning_outcome: u8, // 0 = unresolved, 1 = Outcome 1 wins...
        expiration: u64
    }

    // Tracks a user's bet in the prediction market
    public struct Position has store {
        holder: address,
        market_type: u8, // 1 - BTC, 2 - SUI, 3 - CUSTOM 
        placing_odds: u64, // The odds at which the user placed
        amount: u64, // The amount of SUI the user has placed
        predicted_outcome: u8, // The outcome chosen
        round: u64, // The market round in which the bet was placed
        epoch: u64, // The time when the bet was placed
        is_open: bool // A flag indicating whether the position is still open or settled
    }

    // Liquidity Pool takes all incoming bets and distributes P&L,
    // acting as the party taking the opposite side of the bet.
    // Additionally, it earns passive income by staking SUI via Legato's liquid staking vault.
    public struct LiquidityPool has store {
        used_bet_amount: u64, // Tracks the total amount already used for betting
        lp_supply: Supply<MARKET>,
        min_liquidity: Balance<MARKET>,
        vault_balance: Balance<VAULT>, // Liquid assets locked 
        min_amount: u64, // Minimum amount required to deposit/withdraw
        // withdraw_delay: u64 // Delay withdrawal period specified in epochs
    }

    // Represents a request to withdraw SUI from the liquidity pool
    public struct Request has store, drop {
        sender: address, // Address of the user making the request
        amount: u64, // SUI amount to be sent out when available 
        epoch: u64 // Epoch at which the request was made
    }

    // The global state
    public struct MarketGlobal has key {
        id: UID, 
        admin_list: vector<address>,
        market_btc: Table<u64, MarketConfig>, // Table containing BTC market data for each round.
        market_sui: Table<u64, MarketConfig>,  // Table containing SUI market data for each round.
        market_custom: Table<u64, MarketConfig>, // Seasonal market.
        current_round: u64, // Tracks the current market round. 
        positions: Table<u64, Position>,  // Holds the list of user bet positions
        liquidity_pool: LiquidityPool, 
        commission_fee: u64, // Commission fee taken from winnings
        reserve_ratio: u64, // Proportion of liquidity pool value allowed for betting
        weight: u64, // Higher weight means greater reliance on liquidity pool size.
        max_bet_amount: u64, 
        max_odds: u64, // Cap the odds at a certain level
        treasury_address: address, // where all fees will be sent
        is_paused: bool, // whether the system is currently paused
        pending_fulfil: Balance<SUI>,  // Balance of SUI pending to be sent out
        request_list: TableVec<Request>,
        max_capacity: u64,
        total_vault_locked: u64,
        current_staking_amount: u64,
        current_fulfil_amount: u64
    }


    public struct AddMarketEvent has copy, drop {
        global: ID,
        round: u64,
        market_type: u8,
        probability_1: u64,
        probability_2: u64,
        probability_3: u64,
        probability_4: u64,
        ratio: u64,
        expiration: u64,
        epoch: u64,
        sender: address
    }

    public struct UpdateMarketEvent has copy, drop {
        global: ID,
        round: u64,
        market_type: u8,
        probability_1: u64,
        probability_2: u64,
        probability_3: u64,
        probability_4: u64,
        ratio: u64,
        epoch: u64, 
        sender: address
    }

    public struct ResolveMarketEvent has copy, drop {
        global: ID,
        round: u64,
        market_type: u8,
        winning_outcome: u8,
        epoch: u64, 
        sender: address
    }

    public struct AddLiquidityEvent has copy, drop {
        global: ID,
        deposit_amount: u64,
        lp_amount: u64,
        epoch: u64, 
        sender: address
    }

    public struct RequestWithdrawEvent has copy, drop {
        global: ID, 
        lp_amount: u64,
        withdraw_amount: u64,
        epoch: u64, 
        sender: address
    }

    public struct Redeem has copy, drop {
        global: ID,  
        withdraw_amount: u64,
        epoch: u64, 
        sender: address
    }

    public struct PlaceBetEvent has copy, drop {
        global: ID,
        round: u64,
        market_type: u8,
        bet_outcome: u8,
        bet_amount: u64,
        placing_odds: u64,
        position_id: u64,
        epoch: u64, 
        sender: address
    }

    public struct PayoutWinnersEvent has copy, drop {
        global: ID,
        round: u64,
        market_type: u8,
        from_id: u64,
        until_id: u64,
        total_winners: u64,
        total_payout_amount: u64,
        epoch: u64, 
        sender: address
    }

    // Initializes the market module
    fun init(witness: MARKET, ctx: &mut TxContext) {
    
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        let (treasury_cap, metadata) = coin::create_currency<MARKET>(witness, 9, b"MARKET", b"Legato Market Token", b"", option::some(url::new_unsafe_from_bytes(b"https://img.tamago.finance/legato-logo-icon.png")), ctx);
        transfer::public_freeze_object(metadata);

        // Create a new list for adding to the let ( winner_list, amount_list, all_eligible_iglobal state
        let mut admin_list = vector::empty<address>();
        vector::push_back<address>(&mut admin_list, tx_context::sender(ctx));
    
        let global = MarketGlobal {
            id: object::new(ctx),
            admin_list,
            market_btc: table::new<u64, MarketConfig>(ctx),
            market_sui: table::new<u64, MarketConfig>(ctx),
            market_custom: table::new<u64, MarketConfig>(ctx),
            current_round: 0,
            positions: table::new<u64, Position>(ctx),
            liquidity_pool: LiquidityPool {
                used_bet_amount: 0,
                lp_supply: coin::treasury_into_supply<MARKET>(treasury_cap),
                min_liquidity: balance::zero<MARKET>(),
                vault_balance: balance::zero<VAULT>(),
                min_amount: MIN_ADD_LIQUIDITY_AMOUNT,
                // withdraw_delay: DEFAULT_WITHDRAW_DELAY
            },
            commission_fee: DEFAULT_COMMISSION_FEE,
            reserve_ratio: DEFAULT_RESERVE_RATIO,
            treasury_address: tx_context::sender(ctx),
            max_bet_amount: DEFAULT_MAX_BET_AMOUNT,
            max_odds: DEFAULT_MAX_ODDS,
            weight: DEFAULT_WEIGHT,
            is_paused: false,
            pending_fulfil: balance::zero<SUI>(),
            request_list: table_vec::empty<Request>(ctx),
            max_capacity: 0, 
            total_vault_locked: 0,
            current_staking_amount: 0,
            current_fulfil_amount: 0
        };

        transfer::share_object(global)
    }

    // ======== Entry Functions =========

    public entry fun place_bet( global: &mut MarketGlobal, vault_global: &mut VaultGlobal, round: u64, market_type: u8, bet_outcome: u8, sui: Coin<SUI>, ctx: &mut TxContext ) {
        let bet_amount = coin::value(&sui);
        
        assert!(global.is_paused == false, ERR_PAUSED);
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( bet_outcome > 0 && bet_outcome <= 4, ERR_INVALID_VALUE );
        assert!( global.max_bet_amount >= bet_amount, ERR_MAX_BET_AMOUNT);
        assert!( global.max_capacity >= bet_amount, ERR_INSUFFICIENT_CAPACITY);

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_sui, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_sui, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_custom, round)
        };

        assert!(  market_config.expiration > tx_context::epoch(ctx), ERR_EXPIRED);
        assert!(  market_config.resolved  == false, ERR_RESOLVED);

        let (l_outcome, p_outcome) = update_market_outcomes( market_config, bet_outcome, bet_amount );
        let total_liquidity = total_outcomes(market_config);
        
        let p_adjusted = calculate_p_adjusted(p_outcome, global.weight, l_outcome, total_liquidity, market_config.ratio);
        
        let placing_odds = calculate_odds( p_adjusted, global.max_odds );

        let new_position = Position {
            holder: tx_context::sender(ctx),
            market_type,
            placing_odds,
            amount: bet_amount,
            predicted_outcome: bet_outcome,
            round,
            epoch: tx_context::epoch(ctx),
            is_open: true
        };

        let position_id = table::length( &global.positions );
        table::add( &mut global.positions, position_id, new_position );

        // Deposit SUI into the contract
        balance::join(&mut global.pending_fulfil, coin::into_balance(sui));

        // Update the states
        global.liquidity_pool.used_bet_amount = global.liquidity_pool.used_bet_amount+bet_amount;
    
        update(global, vault_global);
    
        // Emit an event 
        emit( PlaceBetEvent {
            global: object::id(global),
            round,
            market_type,
            bet_outcome,
            bet_amount,
            placing_odds,
            position_id,
            epoch: tx_context::epoch(ctx),
            sender: tx_context::sender(ctx)
        })
    }

    // Provides liquidity by depositing SUI coins into the pool
    // Receives LP tokens in return, which increase in value from incoming bets
    // Also earns passive income through liquid staking
    public entry fun provide(wrapper: &mut SuiSystemState, global: &mut MarketGlobal, vault_global: &mut VaultGlobal, sui: Coin<SUI>, ctx: &mut TxContext) {
        let input_amount = coin::value(&sui);

        assert!(global.is_paused == false, ERR_PAUSED);
        assert!(input_amount >= global.liquidity_pool.min_amount, ERR_TOO_LOW);

        let lp_supply = balance::supply_value(&global.liquidity_pool.lp_supply);

        let lp_amount_to_mint = if (lp_supply == 0) {
            // Check if initial liquidity is sufficient.
            assert!(input_amount > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);
            let minimal_liquidity = balance::increase_supply( &mut global.liquidity_pool.lp_supply, MINIMAL_LIQUIDITY);
            balance::join(&mut global.liquidity_pool.min_liquidity, minimal_liquidity);

            input_amount - MINIMAL_LIQUIDITY
        } else {
            let total_vault_locked = balance::value( &global.liquidity_pool.vault_balance);
            let current_staking_amount = get_current_staking_amount( vault_global, total_vault_locked );
            let current_balance = current_staking_amount+balance::value( &global.pending_fulfil );
            
            let ratio = fixed_point64::create_from_rational((input_amount as u128), (current_balance as u128));
            let total_share = fixed_point64::multiply_u128( (lp_supply as u128) , ratio); 

            (total_share as u64)
        };

        // Mint LP tokens
        let minted_balance = balance::increase_supply(&mut global.liquidity_pool.lp_supply, lp_amount_to_mint);
        let minted_coin =  coin::from_balance(minted_balance, ctx);
        transfer::public_transfer( minted_coin , tx_context::sender(ctx));

        let vault_token = vault::mint_non_entry( wrapper, vault_global, sui, ctx );
        balance::join<VAULT>(&mut global.liquidity_pool.vault_balance, coin::into_balance(vault_token));

        update(global, vault_global);

        // Emit an event
        emit(
            AddLiquidityEvent {
                global: object::id(global),
                deposit_amount: input_amount,
                lp_amount: lp_amount_to_mint,
                epoch: tx_context::epoch(ctx),
                sender: tx_context::sender(ctx)
            }
        )
    }

    // Update necessary values in the object for the frontend to fetch and calculate.
    public entry fun update(global: &mut MarketGlobal, vault_global: &mut VaultGlobal) {
        update_capacity(global, vault_global);
    }

    // Initiates a withdrawal request by the sender
    public entry fun request_withdraw(global: &mut MarketGlobal, vault_global: &mut VaultGlobal, lp_coin: Coin<MARKET>, ctx: &mut TxContext) {
        let lp_amount = coin::value(&lp_coin);

        assert!(global.is_paused == false, ERR_PAUSED);
        assert!(lp_amount >= global.liquidity_pool.min_amount, ERR_TOO_LOW);

        let lp_supply = balance::supply_value(&global.liquidity_pool.lp_supply);
        let total_vault_locked = balance::value( &global.liquidity_pool.vault_balance);
        let current_staking_amount = get_current_staking_amount( vault_global, total_vault_locked );
        let current_balance = current_staking_amount+balance::value( &global.pending_fulfil );

        let multiplier = fixed_point64::create_from_rational( (lp_amount as u128), ( lp_supply as u128));
        let withdrawal_amount = (fixed_point64::multiply_u128( (current_balance as u128), multiplier) as u64);

        table_vec::push_back( &mut global.request_list, Request {
            sender: tx_context::sender(ctx), 
            amount: withdrawal_amount,
            epoch: tx_context::epoch(ctx)
        });

        // Burn the LP tokens
        balance::decrease_supply(&mut global.liquidity_pool.lp_supply, coin::into_balance(lp_coin));

        update(global, vault_global);

        // Emit an event
        emit( RequestWithdrawEvent {
            global: object::id(global),
            lp_amount,
            withdraw_amount: withdrawal_amount,
            epoch: tx_context::epoch(ctx),
            sender: tx_context::sender(ctx)
        })

    }

    // Fulfil unstaking requests for everyone in the list
    public entry fun fulfil_request(global: &mut MarketGlobal,  ctx: &mut TxContext ) {
        assert!( table_vec::length(&global.request_list) > 0, ERR_EMPTY_LIST );
      
        // Fulfil each eligible request
        while ( table_vec::length(&global.request_list) > 0) {

            let this_request = table_vec::pop_back(&mut global.request_list); 
            let withdrawn_balance = balance::split<SUI>(&mut global.pending_fulfil, this_request.amount);
            transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), this_request.sender);

            // Emit an event
            emit(
                Redeem { 
                    global: object::id(global),
                    withdraw_amount: this_request.amount, 
                    epoch: tx_context::epoch(ctx), 
                    sender: this_request.sender
                }
            );
        };

    }

    // This allows anyone to execute the payout of winners for a given market round.
    // It checks the payout amount, ensures sufficient funds, and distributes winnings to eligible participants.
    public entry fun payout_winners(global: &mut MarketGlobal, round: u64, market_type: u8, from_id: u64, until_id: u64,  ctx: &mut TxContext ) {

         // Get the list of winners, payout amounts, and all eligible bet position IDs.
        let ( winner_list, amount_list, mut all_eligible_ids ) = list_winners_and_payouts( global, round, market_type, from_id, until_id, ctx );

        let mut total_payout_amount = 0;
        let mut count = 0;
        let length = vector::length(&amount_list);

        // Calculate the total payout amount by summing all 
        while (count < length) {
            total_payout_amount = total_payout_amount+*vector::borrow( &amount_list, count );
            count = count+1;
        };

        let available_for_pay = balance::value( &global.pending_fulfil );
        // Ensure there is enough liquidity to cover the payouts.
        assert!( available_for_pay >= total_payout_amount, ERR_PAYOUT_NOT_ENOUGH );

        count = 0;

        let fee_ratio = fixed_point64::create_from_rational( (global.commission_fee as u128), 10000);
        let mut fees = 0; 

        // Payout the winnings to each eligible address.
        while ( count < vector::length(&winner_list)) {
            let winner_address = *vector::borrow( &winner_list, count);
            let payout_amount = *vector::borrow( &amount_list, count);
            let fee_amount = (fixed_point64::multiply_u128( (payout_amount as u128) , fee_ratio) as u64); 

            let payout_balance = balance::split<SUI>(&mut global.pending_fulfil, payout_amount-fee_amount);
            transfer::public_transfer(coin::from_balance(payout_balance, ctx), winner_address);

            fees = fees+fee_amount;
            count = count+1;
        };

        if (fees > 0) {
            let payout_balance = balance::split<SUI>(&mut global.pending_fulfil, fees);
            transfer::public_transfer(coin::from_balance(payout_balance, ctx), global.treasury_address);
        };

        let mut all_bet_amount = 0;

        while ( vector::length( &all_eligible_ids ) > 0 ) {
            let position_id = vector::pop_back( &mut all_eligible_ids);
            let entry = table::borrow_mut(&mut global.positions, position_id);
            all_bet_amount = all_bet_amount+entry.amount;
            entry.is_open = false;
        };

        global.liquidity_pool.used_bet_amount = if (global.liquidity_pool.used_bet_amount > all_bet_amount) {
            global.liquidity_pool.used_bet_amount-all_bet_amount
        } else {
            0
        };
        
        // Emit an event
        emit(
            PayoutWinnersEvent {
                global: object::id(global),
                round,
                market_type,
                from_id,
                until_id,
                total_winners: vector::length(&winner_list) ,
                total_payout_amount,
                epoch: tx_context::epoch(ctx), 
                sender: tx_context::sender(ctx)
            }
        )

    }

     public entry fun get_total_vault_locked(global: &MarketGlobal) : u64 {
        balance::value( &global.liquidity_pool.vault_balance)
    }

    public entry fun get_total_vault_balance(global: &MarketGlobal, vault_global: &VaultGlobal) : u64 {
        let total_vault_locked = balance::value( &global.liquidity_pool.vault_balance);
        let current_staking_amount = get_current_staking_amount( vault_global, total_vault_locked );
        let current_balance = current_staking_amount+balance::value( &global.pending_fulfil );
        (current_balance)
    }

    public entry fun check_betting_capacity(global: &MarketGlobal): u64 {
        (global.max_capacity)
    }

    public entry fun get_current_round(global: &MarketGlobal) : u64 {
        (global.current_round)
    }

    public entry fun get_market_info(global: &MarketGlobal, round: u64, market_type: u8): (vector<u64>, vector<u64>, bool, u8, u64, u64, u64) {
        (get_market_info_internal(global, round, market_type))
    }

    public entry fun get_market_adjusted_probabilities(global: &MarketGlobal, round: u64, market_type: u8) : (vector<u64>) {
        let (liquidity_outcome_list, p_outcome_list, _, _, _, ratio, total_liquidity ) = get_market_info_internal(global, round, market_type);
        let global_weight = global.weight;

        let mut output = vector::empty<u64>();
        let mut count = 0;

        while (count < 4) {
            let l_outcome = *vector::borrow( &liquidity_outcome_list, count );
            let p_outcome = *vector::borrow( &p_outcome_list, count );
            let p_adjusted = calculate_p_adjusted(p_outcome, global_weight, l_outcome, total_liquidity, ratio );
            vector::push_back(&mut output, p_adjusted);
            count = count+1;
        };

        (output)
    }

    public entry fun get_bet_position_ids(global: &MarketGlobal, market_type: u8, user_address: address): (vector<u64>) {
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);

        let mut count = 0;
        let mut result = vector::empty<u64>();

        while ( count < table::length( &global.positions) ) {
            let this_position = table::borrow( &global.positions, count );
            if ( market_type == this_position.market_type && user_address == this_position.holder ) {
                vector::push_back( &mut result, count );
            };
            count = count+1;
        };

        result
    }

    public entry fun get_bet_position(global: &MarketGlobal, position_id: u64): (u8, u64, u64, u8, u64, u64, bool ) {
        let entry = table::borrow( &global.positions, position_id );
        ( entry.market_type, entry.placing_odds, entry.amount, entry.predicted_outcome, entry.round, entry.epoch, entry.is_open )
    }

    public entry fun check_payout_amount( global: &MarketGlobal, round: u64, market_type: u8, from_id: u64, until_id: u64, ctx: &mut TxContext  )  : (u64, u64) {
        let (_, amount_list , _) = list_winners_and_payouts( global, round, market_type, from_id, until_id, ctx );
        let mut total_amount = 0;
        let mut count = 0;
        let length = vector::length(&amount_list);

        while (count < length) {
            total_amount = total_amount+*vector::borrow( &amount_list, count );
            count = count+1;
        };

        (length, total_amount)
    }

    public entry fun total_bet_positions(global: &MarketGlobal) : u64 {
        (table::length(&global.positions))
    }

    public entry fun available_for_immediate_payout(global: &MarketGlobal): u64 {
        (balance::value( &global.pending_fulfil ))
    }

    // ======== Public Functions =========

    public fun update_capacity(global: &mut MarketGlobal, vault_global: &mut VaultGlobal) {

        let total_vault_locked = balance::value( &global.liquidity_pool.vault_balance);
        let current_staking_amount = get_current_staking_amount( vault_global, total_vault_locked );
        let current_balance = current_staking_amount+balance::value( &global.pending_fulfil );

        let ratio = fixed_point64::create_from_rational(( global.reserve_ratio as u128), 10000);
        let max_available = (fixed_point64::multiply_u128( (current_balance as u128) , ratio) as u64);

        let capacity = if (max_available > global.liquidity_pool.used_bet_amount) {
            (max_available-global.liquidity_pool.used_bet_amount)
        } else {
            0
        };

        global.max_capacity = capacity;
        global.total_vault_locked = total_vault_locked;
        global.current_staking_amount = current_staking_amount;
        global.current_fulfil_amount = balance::value( &global.pending_fulfil );
    }

   

    // ======== Only Governance =========

    // Updates the treasury address that receives the commission fee.
    public entry fun update_treasury_adddress(global: &mut MarketGlobal, _manager_cap: &mut ManagerCap, new_address: address) {
        global.treasury_address = new_address;
    }

    // Adds a given address to the admin list.
    public entry fun add_admin(global: &mut MarketGlobal, _manager_cap: &mut ManagerCap, admin_address: address) {
        let (found, _) = vector::index_of<address>(&global.admin_list, &admin_address);
        assert!( found == false , ERR_DUPLICATED);
        vector::push_back(&mut global.admin_list, admin_address );
    }

    // Removes a given address from the admin list.
    public entry fun remove_admin(global: &mut MarketGlobal, _manager_cap: &mut ManagerCap, admin_address: address) {
        let (found, index) = vector::index_of<address>(&global.admin_list, &admin_address);
        assert!( found == true , ERR_NOT_FOUND);
        vector::swap_remove<address>(&mut global.admin_list, index );
    }

    // Pause and unpause the system. 
    public entry fun pause(global: &mut MarketGlobal, _manager_cap: &mut ManagerCap, is_paused: bool) {
        global.is_paused = is_paused;
    }

    // To top-up SUI into the fulfilment pool
    public entry fun topup_fulfilment_pool(global: &mut MarketGlobal, coin: Coin<SUI>) {
        let balance = coin::into_balance(coin);
        balance::join<SUI>(&mut global.pending_fulfil, balance);
    }

    // To withdraw SUI from the fulfilment pool
    public entry fun withdraw_fulfilment_pool(global: &mut MarketGlobal, _manager_cap: &mut ManagerCap, amount: u64, ctx: &mut TxContext) {
        let withdrawn_balance = balance::split<SUI>(&mut global.pending_fulfil, amount);
        transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), tx_context::sender(ctx));
    }

    // Stakes the locked SUI tokens to Legato's liquid staking vault
    public entry fun stake_locked_sui_to_legato_vault(wrapper: &mut SuiSystemState, global: &mut MarketGlobal, vault_global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, stake_amount: u64, ctx: &mut TxContext) {
        assert!( stake_amount > 0, ERR_ZERO_VALUE );

        let locked_balance = balance::split<SUI>(&mut global.pending_fulfil, stake_amount);
        let locked_coin = coin::from_balance(locked_balance, ctx);

        let vault_token = vault::mint_non_entry( wrapper, vault_global, locked_coin, ctx );
        balance::join<VAULT>(&mut global.liquidity_pool.vault_balance, coin::into_balance(vault_token));

        update( global, vault_global);
    }

    // Requests to unstake SUI tokens from Legato's liquid staking vault
    // SUI will be credited to the sender's account and the fulfillment pool must be topped up manually afterward
    public entry fun request_unstake_sui_from_legato_vault(wrapper: &mut SuiSystemState, global: &mut MarketGlobal, vault_global: &mut VaultGlobal, _manager_cap: &mut ManagerCap, unstake_amount: u64, ctx: &mut TxContext) {
        assert!( unstake_amount > 0, ERR_ZERO_VALUE );

        let total_vault_locked = balance::value( &global.liquidity_pool.vault_balance);
        let current_staking_amount = get_current_staking_amount( vault_global, total_vault_locked );
        let total_balance_in_vault = current_staking_amount+balance::value( &global.pending_fulfil );

        assert!( total_balance_in_vault >= unstake_amount, ERR_LIQUID_NOT_ENOUGH);

        let ratio = fixed_point64::create_from_rational((unstake_amount as u128), (total_balance_in_vault as u128));
        let vault_to_unstake = (fixed_point64::multiply_u128( (total_vault_locked as u128) , ratio) as u64);

        let locked_balance = balance::split<VAULT>(&mut global.liquidity_pool.vault_balance, vault_to_unstake);
        let locked_coin = coin::from_balance(locked_balance, ctx);

        vault::request_redeem( wrapper, vault_global, locked_coin, ctx );

        update( global, vault_global);
    }

    // Adds a market configuration for the given round.
    public entry fun add_market(
        global: &mut MarketGlobal,
        round: u64, 
        market_type: u8,
        probability_1: u64,
        probability_2: u64,
        probability_3: u64,
        probability_4: u64,
        expiration: u64,
        ctx: &mut TxContext
    ) {
        verify_admin( global, tx_context::sender(ctx) );
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( expiration >= tx_context::epoch(ctx), ERR_INVALID_VALUE );

        assert!( probability_1+probability_2+probability_3+probability_4 == 10000, ERR_INVALID_VALUE );

        let new_market = MarketConfig {
            total_1: 0,
            total_2: 0,
            total_3: 0,
            total_4: 0,
            probability_1,
            probability_2,
            probability_3,
            probability_4,
            ratio: DEFAULT_RATIO,
            resolved: false,
            winning_outcome: 0,
            expiration
        };

        if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ) == false, ERR_DUPLICATED);
            table::add( &mut global.market_btc, round, new_market );
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_sui, round ) == false, ERR_DUPLICATED);
            table::add( &mut global.market_sui, round, new_market );
        } else {
            assert!( table::contains( &global.market_custom, round ) == false, ERR_DUPLICATED);
            table::add( &mut global.market_custom, round, new_market );
        };

        // Update current round
        if (round > global.current_round) {
            global.current_round = round;
        };

        // Emit an event
        emit(
            AddMarketEvent {
                global: object::id(global),
                round,
                market_type,
                probability_1,
                probability_2,
                probability_3,
                probability_4,
                ratio: DEFAULT_RATIO,
                expiration,
                epoch: tx_context::epoch(ctx),
                sender: tx_context::sender(ctx)
            }
        )
    }

    // Updates the market outcome probabilities.
    public entry fun set_market_probabilities(global: &mut MarketGlobal, round: u64, market_type: u8, probability_1: u64, probability_2: u64, probability_3: u64, ratio: u64, probability_4: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) );
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( probability_1+probability_2+probability_3+probability_4 == 10000, ERR_INVALID_VALUE );

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_sui, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_sui, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_custom, round)
        };

        market_config.probability_1 = probability_1;
        market_config.probability_2 = probability_2;
        market_config.probability_3 = probability_3;
        market_config.probability_4 = probability_4;
        market_config.ratio = ratio;

        // Emit an event
        emit( UpdateMarketEvent {
            global: object::id(global),
            round,
            market_type,
            probability_1,
            probability_2,
            probability_3,
            probability_4,
            ratio,
            epoch: tx_context::epoch(ctx),
            sender: tx_context::sender(ctx)
        })
    }

    // Marks the market as resolved and assigns the winning outcome.
    public entry fun resolve_market(global: &mut MarketGlobal, round: u64, market_type: u8, winning_outcome: u8, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) );
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( winning_outcome > 0 , ERR_INVALID_VALUE );

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_sui, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_sui, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_custom, round)
        };

        assert!( market_config.resolved == false, ERR_RESOLVED );

        market_config.resolved = true;
        market_config.winning_outcome = winning_outcome;

        // Emit an event
        emit( ResolveMarketEvent {
            global: object::id(global),
            round,
            market_type,
            winning_outcome,
            epoch: tx_context::epoch(ctx),
            sender: tx_context::sender(ctx)
        })
    }

    // Updates the current round
    public entry fun update_round(global: &mut MarketGlobal, round: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        global.current_round = round;
    }

    public entry fun update_min_amount(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        assert!( new_value > 0, ERR_ZERO_VALUE ); 
        global.liquidity_pool.min_amount = new_value;
    }

    // public entry fun update_withdraw_delay(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
    //     verify_admin( global, tx_context::sender(ctx) ); 
    //     assert!( 30 >= new_value, ERR_INVALID_VALUE ); // No more 30 days 
    //     global.liquidity_pool.withdraw_delay = new_value;
    // }

    // Updates the commission fee.
    public entry fun update_commission_fee(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        assert!( new_value > 0 && new_value <= 4000, ERR_INVALID_VALUE ); // No more 40%
        global.commission_fee = new_value;
    }

    // Updates the reserve ratio value
    public entry fun update_reserve_ratio(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        assert!(  new_value > 0 && new_value <= 100000, ERR_INVALID_VALUE ); // No more 1,000%
        global.reserve_ratio = new_value;
    }

    // Updates the global weight.
    public entry fun update_weight(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        assert!( new_value > 0 && new_value <= 10000, ERR_INVALID_VALUE);
        global.weight = new_value;
    }

    // Updates the maximum bet amount.
    public entry fun update_max_bet_amount(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        assert!( new_value > 0, ERR_ZERO_VALUE );
        global.max_bet_amount = new_value;
    }

    // Updates the odds cap.
    public entry fun update_odds_cap(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        assert!( new_value >= 10000, ERR_ZERO_VALUE ); // more than 1.0
        global.max_odds = new_value;
    }

    // Manual updates the capacity
    public entry fun manual_set_capacity(global: &mut MarketGlobal, new_value: u64, ctx: &mut TxContext) {
        verify_admin( global, tx_context::sender(ctx) ); 
        assert!( new_value > 0, ERR_ZERO_VALUE );
        global.max_capacity = new_value;
    }


    // ======== Internal Functions =========

    fun verify_admin(global: &MarketGlobal , admin_address: address) {
        let (found, _) = vector::index_of<address>(&global.admin_list, &admin_address);
        assert!( found, ERR_UNAUTHORIZED );
    }

    fun get_current_staking_amount(vault_global: &VaultGlobal, current_vault_amount: u64) : u64 {
        let (pool_balance, pool_vault) = vault::get_amounts(vault_global);
        let ratio = fixed_point64::create_from_rational((current_vault_amount as u128), (pool_vault as u128));
        let result = fixed_point64::multiply_u128( (pool_balance as u128) , ratio);
        (result as u64)
    }

    fun get_market_info_internal(global: &MarketGlobal, round: u64, market_type: u8): (vector<u64>, vector<u64>, bool, u8, u64, u64, u64) {
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_sui, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_sui, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_custom, round)
        };

        let mut total_bets = vector::empty<u64>();
        let mut probabilities = vector::empty<u64>();

        vector::push_back(&mut total_bets,  market_config.total_1);
        vector::push_back(&mut total_bets,  market_config.total_2);
        vector::push_back(&mut total_bets,  market_config.total_3);
        vector::push_back(&mut total_bets,  market_config.total_4);

        vector::push_back(&mut probabilities,  market_config.probability_1);
        vector::push_back(&mut probabilities,  market_config.probability_2);
        vector::push_back(&mut probabilities,  market_config.probability_3);
        vector::push_back(&mut probabilities,  market_config.probability_4);

        (total_bets, probabilities, market_config.resolved, market_config.winning_outcome, market_config.expiration, market_config.ratio, (market_config.total_1+market_config.total_2+market_config.total_3+market_config.total_4))
    }

    // P(adjusted) = P(outcome) * weight + (L(outcome) / L(pool)) * (1 - weight)
    fun calculate_p_adjusted(p_outcome: u64, weight: u64, l_outcome: u64, l_pool: u64, ratio: u64) : u64 {
        let weight_ratio = fixed_point64::create_from_rational( (weight as u128), 10000 );
        let weighted_probability = fixed_point64::multiply_u128( (p_outcome as u128) , weight_ratio); 

        if (l_outcome != 0 || l_pool != 0 ) {
            // Calculate the adjusted liquidity contribution
            let liquidity_ratio = fixed_point64::create_from_rational( (l_outcome as u128), (l_pool as u128) );
            let liquidity_contribution = fixed_point64::multiply_u128( ((10000-weight) as u128), liquidity_ratio); 

            let normalized_ratio = fixed_point64::create_from_rational( (ratio as u128), 10000 );
            let result = fixed_point64::multiply_u128(  weighted_probability+liquidity_contribution, normalized_ratio); 

            (result as u64)
        } else {
            // TODO: Checks whether we need to apply normalization
            p_outcome
        }

    }

    fun update_market_outcomes(market_config: &mut MarketConfig, bet_outcome: u8, bet_amount: u64): (u64, u64) {
        if (bet_outcome == 1) {
            assert!( market_config.probability_1 != 0 , ERR_OUTCOME_NOT_AVAILABLE );
            market_config.total_1 = market_config.total_1+bet_amount;
            (market_config.total_1, market_config.probability_1)
        } else if (bet_outcome == 2) {
            assert!( market_config.probability_2 != 0 , ERR_OUTCOME_NOT_AVAILABLE );
            market_config.total_2 = market_config.total_2+bet_amount;
            (market_config.total_2, market_config.probability_2)
        } else if (bet_outcome == 3) {
            assert!( market_config.probability_3 != 0 , ERR_OUTCOME_NOT_AVAILABLE );
            market_config.total_3 = market_config.total_3+bet_amount;
            (market_config.total_3, market_config.probability_3)
        } else {
            assert!( market_config.probability_4 != 0 , ERR_OUTCOME_NOT_AVAILABLE );
            market_config.total_4 = market_config.total_4+bet_amount;
            (market_config.total_4, market_config.probability_4)
        }
    }

    fun total_outcomes(market_config: &MarketConfig): u64 {
        (market_config.total_1+market_config.total_2+market_config.total_3+market_config.total_4)
    }

    fun calculate_odds(p_adjusted: u64, odds_cap: u64): u64 {
        let output = ((10000 * 10000)/ p_adjusted);
        if (output >= odds_cap) {
            odds_cap
        } else {
            output
        }
    }

    // Returns the list of winners, the payout amount for each winner and all position IDs associated with the market.
    fun list_winners_and_payouts(global: &MarketGlobal, round: u64, market_type: u8, from_id: u64, until_id: u64, ctx: &TxContext) : (vector<address>, vector<u64>, vector<u64>) {
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( until_id > from_id, ERR_INVALID_VALUE);
        
        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_sui, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_sui, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_custom, round)
        };

        assert!( market_config.resolved == true , ERR_NOT_RESOLVED);

        let mut count = from_id;
        let count_length = if (until_id > table::length( &global.positions )) {
            table::length( &global.positions )
        } else {
            until_id
        };

        let mut winner_list = vector::empty<address>();
        let mut payout_amount_list = vector::empty<u64>();
        let mut all_ids = vector::empty<u64>(); 
        
        while ( count < count_length) {
            let entry = table::borrow( &global.positions, count );
            if (entry.is_open == true && entry.round == round && entry.market_type == market_type && tx_context::epoch(ctx) > market_config.expiration) {
                vector::push_back( &mut all_ids, count);
                if ( entry.predicted_outcome == market_config.winning_outcome ) { 
                    let ratio = fixed_point64::create_from_rational( (entry.placing_odds as u128), 10000 );
                    let winning_amount = (fixed_point64::multiply_u128( (entry.amount as u128) , ratio) as u64); 
                    
                    if (vector::contains( &winner_list, &entry.holder )) {
                        let (_, index) = vector::index_of( &winner_list, &entry.holder ); 
                        *vector::borrow_mut(&mut payout_amount_list, index ) = *vector::borrow(&payout_amount_list, index )+winning_amount;
                    } else {
                        vector::push_back( &mut winner_list, entry.holder );
                        vector::push_back( &mut payout_amount_list, winning_amount );
                    };
                };
            };
            count = count+1;
        };

        (winner_list,payout_amount_list,all_ids)
    }

    // ======== Test-related Functions =========

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(MARKET {}, ctx)
    }

}