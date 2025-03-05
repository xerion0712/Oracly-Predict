// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT


/// Legato Generalized Prediction Market
///
/// ## Key Features:
/// - **Market Creation & Management**: Supports the creation and administration of prediction markets.
/// - **Bet Placement & Resolution**: Users can place bets on outcomes, with automated result resolution.
/// - **Weighted Payout System**: Implements a flexible reward distribution using adjustable round weights.
/// - **Weight Assignment**: Utilizes an AI agent to dynamically adjust outcome weights.
///
/// ## Core Components:
/// - `MarketStore`: Stores all relevant market data, including outcomes, bets, and resolution states.
/// - `Bet Placement`: Functions to allow users to stake on various outcomes.
/// - `Payout Calculation`: Mechanism to fairly distribute rewards to winning bets.
/// - `Round-Based Processing`: Ensures markets operate efficiently with structured betting rounds.
///
/// ## Usage:
/// - Supports multiple prediction markets for different event categories.
/// - Can be extended to work with **DeFi, Sports Betting, Hackathons, and Crypto Price Predictions**.
///


module legato_market::generalized {

    use std::signer;
    use std::vector;
    use std::string::{  String  }; 

    use aptos_std::fixed_point64::{Self }; 
    use aptos_std::table_with_length::{Self, TableWithLength};
    use aptos_framework::fungible_asset::{
        Self, FungibleStore, Metadata,
    };
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    
    // ======== Constants ========

    const SCALE: u64 = 10000; // Scaling factor for fixed-point calculations 
    const DEFAULT_WINNING_FEE: u64 = 1000; // Default commission fee
    const DEFAULT_ROUND_INTERVAL: u64 = 604800; // 1 week in s

    // ======== Errors ========

    const ERR_UNAUTHORIZED: u64 = 1;
    const ERR_INVALID_VALUE: u64 = 2;
    const ERR_DUPLICATED: u64 = 3;
    const ERR_NOT_FOUND: u64 = 4;
    const ERR_EXCEED_CAP: u64 = 5;
    const ERR_INVALID_LENGTH: u64 = 6;
    const ERR_MAX_BET_AMOUNT: u64  = 7;
    const ERR_INSUFFICIENT_AMOUNT: u64 = 8;
    const ERR_PAUSED: u64 = 9;
    const ERR_ALREADY_RESOLVED: u64 = 10;
    const ERR_INVALID_ROUND: u64 = 11;
    const ERR_ROUND_ALREADY_ENDED: u64 = 12;
    const ERR_ROUND_NOT_ENDED: u64 = 13;
    const ERR_NOT_RESOLVED: u64 = 14;
    const ERR_NOT_HOLDER: u64 = 15;
    const ERR_ALREADY_CLAIMED: u64 = 16;
    const ERR_ALREADY_FINALIZED: u64 = 17;
    const ERR_NOT_DISPUTED: u64 = 18;


    // ======== Structs =========

    struct Round has store {
        total_bet_amount: u64, // Total amount of bets placed in the current round
        total_paid_amount: u64, // Total amount of bets paid in the current round
        total_disputed_amount: u64,// Total amount of bets in dispute cases
        outcome_ids: vector<u64>, // List of all outcome IDs associated with the current round
        position_ids: vector<u64>, // Track all position IDs within the round
        outcome_weights: TableWithLength<u64, u64>, // Mapping: Outcome ID -> Weight assigned. Default is 1.0.
        winning_outcomes: vector<u64>, // List of winning outcome IDs
        dispute_claims: vector<u64>, // List of dispute outcome IDs
        is_finalized: bool, // Flag indicating if the round has been finalized 
        is_resolved: bool, // Flag indicating if the round results have been resolved
        resolved_timestamp: u64, 
        finalized_timestamp: u64
    }

    struct MarketStore has store { 
        rounds: TableWithLength<u64, Round>, // Mapping: Round ID -> Round Data
        outcome_bets: TableWithLength<u64, u64>, // Mapping: Outcome ID -> Total bet amount placed
        bet_pool: Object<FungibleStore>, // Stores all bets in FA assets
        max_bet_amount: u64, // Maximum allowed 
        round_weights: TableWithLength<u64, u64>, // Mapping: Round ID -> Weight assigned, referring to the percentage of total bet amount that can be distributed. Default is 1.0.
        created_time: u64, // Timestamp (s) when the market was created
        round_interval: u64, // Time interval (s) between each round
        is_paused: bool // Whether the market is currently paused
    }

    // Tracks a user's bet in the prediction market
    struct Position has store {
        market_id: u64, // The ID of the market this bet belongs to
        outcome_id: u64, // The outcome ID the user is betting on
        round_id: u64, // The round ID 
        amount: u64, // The amount of token staked 
        holder: address, // Owner address 
        timestamp: u64, // The time when the bet was placed
        is_open: bool // A flag indicating whether the position is still open or settled
    }

    struct MarketManager has key {
        manager_list: vector<address>,
        extend_ref: ExtendRef,
        markets: TableWithLength<u64, MarketStore>, // Table containing market data
        positions: TableWithLength<u64, Position>, // Table containing position data
        winning_fee: u64,
        treasury_address: address, // where all fees will be sent
    }


    #[event]
    struct AddMarketEvent has drop, store {
        market_id: u64,
        bet_token: String,
        max_bet_amount: u64,
        timestamp: u64,
        sender: address
    }

    #[event]
    struct PlaceBetEvent has drop, store {
        market_id: u64,
        round_id: u64,
        outcome_id: u64,
        bet_amount: u64,
        position_id: u64,
        timestamp: u64,
        sender: address
    }

    #[event]
    struct ClaimPrizeEvent has drop, store {
        position_id: u64,
        payout_amount: u64,
        is_disputed: bool,
        timestamp: u64,
        sender: address
    }

    #[event]
    struct ResolveMarketEvent has drop, store {
        market_id: u64,
        round_id: u64,
        winning_outcomes: vector<u64>, 
        dispute_outcomes: vector<u64>,
        timestamp: u64, 
        sender: address
    }

    #[event]
    struct FinalizeMarketEvent has drop, store {
        market_id: u64,
        round_id: u64,
        outcomes: vector<u64>, 
        weights: vector<u64>,
        timestamp: u64, 
        sender: address
    }

    // Initializes the module
    fun init_module(sender: &signer) {
        
        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        let manager_list = vector::empty<address>();
        vector::push_back<address>(&mut manager_list, signer::address_of(sender));

        move_to(sender, MarketManager {
            manager_list,
            extend_ref,
            markets: table_with_length::new<u64, MarketStore>(),
            positions: table_with_length::new<u64, Position>(),
            treasury_address: signer::address_of(sender),
            winning_fee: DEFAULT_WINNING_FEE
        });
    }

    // ======== Entry Functions =========

    // Places a bet on a specific outcome within a market round
    public entry fun place_bet(sender: &signer, market_id: u64, round_id: u64, outcome_id: u64, bet_amount: u64) acquires MarketManager {
        let global = borrow_global_mut<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id); 
        let bet_token_metadata = fungible_asset::store_metadata(market_store.bet_pool);

        assert!(market_store.max_bet_amount >= bet_amount, ERR_MAX_BET_AMOUNT); 
        assert!(primary_fungible_store::balance(signer::address_of(sender), bet_token_metadata ) >= bet_amount, ERR_INSUFFICIENT_AMOUNT );
        assert!( market_store.is_paused == false, ERR_PAUSED );
        
        // Deposit the token bet into the contract
        let input_token = primary_fungible_store::withdraw(sender, bet_token_metadata, bet_amount);
        fungible_asset::deposit(market_store.bet_pool, input_token);

        // Update the total bets for the selected outcome
        if (table_with_length::contains( &market_store.outcome_bets, outcome_id)) {
            // If there is already a bet for this outcome, increase it
            *table_with_length::borrow_mut( &mut market_store.outcome_bets, outcome_id ) = *table_with_length::borrow( &market_store.outcome_bets, outcome_id )+bet_amount;
        } else {
            // Otherwise, add a new entry
            table_with_length::add( &mut market_store.outcome_bets, outcome_id, bet_amount );
        };

        let current_round = get_market_round_mut( market_store, round_id );

        // Ensure the market is still active and accepting bets
        assert!( current_round.is_finalized == false, ERR_ALREADY_FINALIZED );
        assert!( current_round.is_resolved == false, ERR_ALREADY_RESOLVED);

        let position_id = table_with_length::length( &global.positions );

        if (vector::contains( &current_round.outcome_ids, &outcome_id ) == false) {
            vector::push_back( &mut current_round.outcome_ids, outcome_id );
        };

        vector::push_back( &mut current_round.position_ids, position_id);

        // Update the total bets for the selected round
        current_round.total_bet_amount = current_round.total_bet_amount+bet_amount;

        // Create a new bet position
        let new_position = Position {
            market_id,
            outcome_id,
            round_id,
            amount: bet_amount,
            holder: signer::address_of(sender),
            timestamp: timestamp::now_seconds(),
            is_open: true
        };

        table_with_length::add( &mut global.positions, position_id, new_position );

        // Emit an event 
        event::emit(
            PlaceBetEvent {
                market_id,
                round_id,
                outcome_id,
                bet_amount, 
                position_id,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )

    }


    // Allows a user to claim their winnings after the market has been resolved.
    public entry fun claim_prize(sender: &signer, position_id: u64) acquires MarketManager {
        // Calculate the payout amount for the position
        let payout_amount = calculate_payout_amount(position_id);

        let global = borrow_global_mut<MarketManager>(@legato_market); 
        let current_position = table_with_length::borrow_mut( &mut global.positions, position_id );

        assert!( current_position.is_open == true , ERR_ALREADY_CLAIMED);

        let market_store = table_with_length::borrow_mut(&mut global.markets, current_position.market_id); 
        let bet_token_metadata = fungible_asset::store_metadata(market_store.bet_pool);
        let pool_signer = object::generate_signer_for_extending(&global.extend_ref);
        assert!( market_store.is_paused == false, ERR_PAUSED );

        // If there is a payout amount to be claimed
        if ( payout_amount > 0 ) {

            // takes a fee if there's a surplus            
            if ( payout_amount > current_position.amount) {
                // Apply a fee when the payout amount exceeds the original bet amount 
                let fee_ratio = fixed_point64::create_from_rational( (global.winning_fee as u128), 10000);
                let surplus_amount = payout_amount-current_position.amount;
                let fee_amount = (fixed_point64::multiply_u128( (surplus_amount as u128) , fee_ratio) as u64); 

                let token_out = fungible_asset::withdraw(&pool_signer, market_store.bet_pool, payout_amount);
                let token_fee = fungible_asset::extract(&mut token_out, fee_amount);

                // Send fees to the treasury
                primary_fungible_store::ensure_primary_store_exists(global.treasury_address, bet_token_metadata);
                let store = primary_fungible_store::primary_store(global.treasury_address, bet_token_metadata);
                fungible_asset::deposit(store, token_fee);

                // Send the remaining payout to the user
                primary_fungible_store::ensure_primary_store_exists(current_position.holder, bet_token_metadata);
                let store = primary_fungible_store::primary_store(current_position.holder, bet_token_metadata);
                fungible_asset::deposit(store, token_out);
                
            } else {
                // If there is no surplus, transfer the full payout amount to the user 
                let token_out = fungible_asset::withdraw(&pool_signer, market_store.bet_pool, payout_amount);
                primary_fungible_store::ensure_primary_store_exists(current_position.holder, bet_token_metadata);
                let store = primary_fungible_store::primary_store(current_position.holder, bet_token_metadata);
                fungible_asset::deposit(store, token_out);
            };

        };

        // Mark the position as claimed
        current_position.is_open = false;

        if (table_with_length::contains(&market_store.rounds, current_position.round_id) && payout_amount > 0 ) {
            let current_round = table_with_length::borrow_mut(&mut market_store.rounds, current_position.round_id);
            current_round.total_paid_amount = current_round.total_paid_amount+payout_amount;
        };
        
        // Emit an event
        event::emit(
            ClaimPrizeEvent {
                position_id,
                payout_amount,
                is_disputed: false,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    
    }


    // Refunds a bet to the user if the outcome is marked as disputed.
    public entry fun refund(sender: &signer, position_id: u64) acquires MarketManager {
        let global = borrow_global_mut<MarketManager>(@legato_market); 
        let current_position = table_with_length::borrow_mut( &mut global.positions, position_id );

        assert!( current_position.is_open == true , ERR_ALREADY_CLAIMED);

        let market_store = table_with_length::borrow_mut(&mut global.markets, current_position.market_id);          
        let pool_signer = object::generate_signer_for_extending(&global.extend_ref);
        let bet_token_metadata = fungible_asset::store_metadata(market_store.bet_pool);
        
        assert!(table_with_length::contains(&market_store.rounds, current_position.round_id), ERR_NOT_FOUND);
        let current_round = table_with_length::borrow( &market_store.rounds , current_position.round_id);

        // Check if the outcome associated with the position is a dispute outcome
        let (is_disputed, _) = vector::index_of<u64>(&current_round.dispute_claims, &(current_position.outcome_id));

        assert!( is_disputed == true, ERR_NOT_DISPUTED );

        let payout_amount = current_position.amount;

        let token_out = fungible_asset::withdraw(&pool_signer, market_store.bet_pool, payout_amount);
        primary_fungible_store::ensure_primary_store_exists(current_position.holder, bet_token_metadata);
        let store = primary_fungible_store::primary_store(current_position.holder, bet_token_metadata);
        fungible_asset::deposit(store, token_out);

        // Mark the position as claimed
        current_position.is_open = false;

        // Emit an event
        event::emit(
            ClaimPrizeEvent {
                position_id,
                payout_amount,
                is_disputed: true,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    }

    // ======== Public Functions =========

    // Retrieves the IDs of all bet positions for a given market and user address
    #[view]
    public fun get_bet_position_ids(market_id: u64, user_address: address) : (vector<u64>) acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market);
        
        let count = 0;
        let result = vector::empty<u64>();

        while ( count < table_with_length::length( &global.positions) ) {
            let this_position = table_with_length::borrow( &global.positions, count );
            if ( market_id == this_position.market_id && user_address == this_position.holder ) {
                vector::push_back( &mut result, count );
            };
            count = count+1;
        };
    
        result
    }

    #[view]
    public fun get_total_positions(): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market);
        ( table_with_length::length(&(global.positions)))
    }

    #[view]
    public fun check_payout_amount(position_id: u64): u64 acquires MarketManager {
        calculate_payout_amount(position_id)
    }

    #[view] 
    public fun check_winning_outcomes(market_id: u64, round_id: u64) : vector<u64> acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow(&global.markets, market_id); 
        assert!(table_with_length::contains(&market_store.rounds, round_id), ERR_NOT_FOUND);
        let current_round = table_with_length::borrow(&market_store.rounds, round_id);

        (current_round.winning_outcomes)
    }

    #[view] 
    public fun check_dispute_outcomes(market_id: u64, round_id: u64) : vector<u64> acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow(&global.markets, market_id); 
        assert!(table_with_length::contains(&market_store.rounds, round_id), ERR_NOT_FOUND);
        let current_round = table_with_length::borrow(&market_store.rounds, round_id);

        (current_round.dispute_claims)
    }

    // Returns the bet position for a given ID
    #[view]
    public fun get_bet_position(position_id: u64) : ( u64, u64, u64, u64, address, u64,  bool )  acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market);
        let entry = table_with_length::borrow( &global.positions, position_id );
        ( entry.market_id, entry.outcome_id, entry.round_id, entry.amount, entry.holder, entry.timestamp, entry.is_open )
    }
 
    #[view]
    public fun get_pool_object_address(): address acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market);
        let pool_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        signer::address_of(&pool_object_signer)
    }

    #[view]
    public fun get_market_bet_token_metadata(market_id: u64) : Object<Metadata> acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow(&global.markets, market_id); 
        fungible_asset::store_metadata(market_store.bet_pool)
    }

    #[view]
    public fun get_round_weights(market_id: u64, round_id: u64) : u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        
        let market_store = table_with_length::borrow(&global.markets, market_id);

        if (table_with_length::contains( &market_store.round_weights, round_id )) {
            *table_with_length::borrow(&market_store.round_weights, round_id)
        } else {
            (SCALE)
        }
    }

    #[view]
    public fun get_outcome_weights( market_id: u64, round_id: u64 ) : (vector<u64>, vector<u64>) acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);

        let market_store = table_with_length::borrow(&global.markets, market_id);
        assert!( table_with_length::contains( &market_store.rounds, round_id ), ERR_NOT_FOUND);
        
        let current_round = table_with_length::borrow( &market_store.rounds, round_id );

        let outcome_ids = vector::empty<u64>();
        let outcome_weights = vector::empty<u64>();

        let count = 0;

        while (count < vector::length(&( current_round.outcome_ids ))) {
            let outcome_id = *vector::borrow( &current_round.outcome_ids, count );
            let outcome_weight = if (table_with_length::contains( &current_round.outcome_weights, outcome_id )) {
                *table_with_length::borrow(&current_round.outcome_weights, outcome_id)
            } else {
                SCALE
            };

            vector::push_back<u64>(&mut outcome_ids, outcome_id);
            vector::push_back<u64>(&mut outcome_weights, outcome_weight);

            count = count+1;
        };

        ( outcome_ids, outcome_weights )
    }

    #[view]
    public fun get_market_data(market_id: u64) : (u64, u64, u64, u64, bool) acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow(&global.markets, market_id); 
    
        ( 
            fungible_asset::balance(market_store.bet_pool),
            market_store.max_bet_amount,
            market_store.created_time,
            market_store.round_interval,
            market_store.is_paused
        )
    }

    #[view]
    public fun get_market_outcome_bet_amount(market_id: u64, outcome_id: u64) : (u64) acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow(&global.markets, market_id); 
        assert!( table_with_length::contains( &market_store.outcome_bets, outcome_id ), ERR_NOT_FOUND);
        *table_with_length::borrow( &market_store.outcome_bets, outcome_id )
    }

    #[view]
    public fun get_market_round_bet_amount(market_id: u64, round_id: u64) : (u64, u64) acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow(&global.markets, market_id); 
        assert!(table_with_length::contains(&market_store.rounds, round_id), ERR_NOT_FOUND);
        let current_round = table_with_length::borrow(&market_store.rounds, round_id);

        (current_round.total_bet_amount, current_round.total_paid_amount)
    }

    // TODO: get round info

    // ======== Only Governance =========

    // Adds a new market 
    public entry fun add_market(
        sender: &signer, 
        bet_token: Object<Metadata>,
        max_bet_amount: u64
    ) acquires MarketManager {
        assert!( max_bet_amount > 0 , ERR_INVALID_VALUE );

        // Ensure that the caller has permission
        verify_caller(signer::address_of(sender));
        
        let global = borrow_global_mut<MarketManager>(@legato_market);
        let pool_signer = object::generate_signer_for_extending(&global.extend_ref);

        let new_market = MarketStore {
            rounds: table_with_length::new<u64, Round>(),
            outcome_bets: table_with_length::new<u64, u64>(), 
            bet_pool: create_token_store(&pool_signer, bet_token),
            max_bet_amount,
            round_weights: table_with_length::new<u64, u64>(),
            created_time: timestamp::now_seconds(),
            round_interval: DEFAULT_ROUND_INTERVAL,
            is_paused: false
        };

        let new_market_id = table_with_length::length( &global.markets ); 
        table_with_length::add( &mut global.markets, new_market_id, new_market );

        // Emit an event
        event::emit(
            AddMarketEvent {
                market_id: new_market_id,
                bet_token : fungible_asset::symbol(bet_token),
                max_bet_amount,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    }

    // Finalizes the market for a given round by locking in the final outcome weights.  
    // Prevents further bets from being placed and prepares the round for resolution.
    public entry fun finalize_market(sender: &signer, market_id: u64, round_id: u64, outcome_ids: vector<u64>, weights: vector<u64>) acquires MarketManager {
        assert!( vector::length(&outcome_ids) == vector::length(&(weights)) , ERR_INVALID_LENGTH );
        
        verify_caller(signer::address_of(sender));

        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);
        let current_round = get_market_round_mut(market_store, round_id);

        assert!( current_round.is_resolved == false, ERR_ALREADY_RESOLVED );

        let count = 0;

        while (count < vector::length(&(outcome_ids))) {

            let current_outcome_id = *vector::borrow_mut( &mut outcome_ids, count );
            let current_weights = *vector::borrow_mut( &mut weights, count);

            if (table_with_length::contains( &current_round.outcome_weights, current_outcome_id )) {
                *table_with_length::borrow_mut(&mut current_round.outcome_weights, current_outcome_id) = current_weights;
            } else {
                table_with_length::add( &mut current_round.outcome_weights, current_outcome_id, current_weights );
            };

            count = count+1;
        };

        current_round.is_finalized = true;
        current_round.finalized_timestamp = timestamp::now_seconds();

        // Emit an event
        event::emit(
            FinalizeMarketEvent {
                market_id,
                round_id,
                outcomes: outcome_ids,
                weights,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    }

    // Assigns the winning & dispute outcomes for the given market and round
    public entry fun resolve_market(sender: &signer, market_id: u64, round_id: u64, winning_outcomes: vector<u64>, dispute_outcomes: vector<u64> ) acquires MarketManager {

        verify_caller(signer::address_of(sender));
   
        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);
        let current_round = get_market_round_mut(market_store, round_id);

        // Assign winning and disputed outcomes
        current_round.winning_outcomes = winning_outcomes;
        current_round.dispute_claims = dispute_outcomes;
        current_round.is_resolved = true;
        current_round.resolved_timestamp = timestamp::now_seconds();

        // Calculate the total disputed amount
        let position_count = 0;

        while (position_count < vector::length( &(current_round.position_ids))) {
            let position_id = *vector::borrow( &(current_round.position_ids), position_count  );
            let this_position = table_with_length::borrow( &global.positions, position_id );
            let (is_disputed, _) = vector::index_of<u64>(&dispute_outcomes, &this_position.outcome_id);
            if (is_disputed) {
                current_round.total_disputed_amount = current_round.total_disputed_amount+this_position.amount;
            };
            position_count = position_count+1;
        };

        // Emit an event
        event::emit(
            ResolveMarketEvent {
                market_id,
                round_id,
                winning_outcomes,
                dispute_outcomes,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )

    }

    public entry fun update_market_max_bet_amount(sender: &signer, market_id: u64, new_bet_max_amount: u64) acquires MarketManager {
        assert!( new_bet_max_amount > 0 , ERR_INVALID_VALUE );
        // Ensure that the caller has permission
        verify_caller(signer::address_of(sender));

        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);
        market_store.max_bet_amount = new_bet_max_amount;
    }
    
    public entry fun update_market_round_interval(sender: &signer, market_id: u64, new_round_interval: u64 ) acquires MarketManager {
        assert!( new_round_interval > 0 , ERR_INVALID_VALUE );
        // Ensure that the caller has permission
        verify_caller(signer::address_of(sender));

        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);
        market_store.round_interval = new_round_interval;
    }

    public entry fun pause_market(sender: &signer, market_id: u64, is_paused: bool) acquires MarketManager { 
        // Ensure that the caller has permission
        verify_caller(signer::address_of(sender));

        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);
        market_store.is_paused = is_paused;
    }

    public entry fun update_created_time(sender: &signer, market_id: u64, new_created_time: u64) acquires MarketManager { 
        // Ensure that the caller has permission
        verify_caller(signer::address_of(sender));

        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);
        market_store.created_time = new_created_time;
    }

    public entry fun update_round_weights(sender: &signer, market_id: u64, round_id: u64, weights: u64 ) acquires MarketManager {
        assert!( weights >= 5000  , ERR_INVALID_VALUE );
        // Ensure that the caller has permission
        verify_caller(signer::address_of(sender));

        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);

        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);

        if (table_with_length::contains( &market_store.round_weights, round_id )) {
            *table_with_length::borrow_mut(&mut market_store.round_weights, round_id) = weights;
        } else {
            table_with_length::add( &mut market_store.round_weights, round_id, weights );
        };

    }

    public entry fun update_round_weights_bulk(sender: &signer, market_id: u64, round_ids: vector<u64>, weights: vector<u64>) acquires MarketManager {
        assert!( vector::length(&round_ids) == vector::length(&(weights)) , ERR_INVALID_LENGTH );
        
        // Ensure that the caller has permission
        verify_caller(signer::address_of(sender));

        let global = borrow_global_mut<MarketManager>(@legato_market);
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);

        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id);

        let count = 0;

        while (count < vector::length(&(round_ids))) {

            let current_round_id = *vector::borrow_mut( &mut round_ids, count );
            let current_weights = *vector::borrow_mut( &mut weights, count);

            if (table_with_length::contains( &market_store.round_weights, current_round_id )) {
                *table_with_length::borrow_mut(&mut market_store.round_weights, current_round_id) = current_weights;
            } else {
                table_with_length::add( &mut market_store.round_weights, current_round_id, current_weights );
            };

            count = count+1;
        };
    }

    // Adds a given address to the manager list.
    public entry fun add_manager(sender: &signer, manager_address: address) acquires MarketManager {
        assert!( signer::address_of(sender) == @legato_market , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@legato_market);
        let (found, _) = vector::index_of<address>(&global.manager_list, &manager_address);
        assert!( found == false , ERR_DUPLICATED);
        vector::push_back(&mut global.manager_list, manager_address );
    }

    // Removes a given address from the manager list.
    public entry fun remove_admin(sender: &signer, manager_address: address) acquires MarketManager {
        assert!( signer::address_of(sender) == @legato_market , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@legato_market);
        let (found, index) = vector::index_of<address>(&global.manager_list, &manager_address);
        assert!( found == true , ERR_NOT_FOUND);
        vector::swap_remove<address>(&mut global.manager_list, index );
    }

    // Updates the treasury address that receives the winning fee.
    public entry fun update_treasury_adddress(sender: &signer, new_address: address) acquires MarketManager {
        assert!( signer::address_of(sender) == @legato_market , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@legato_market);
        global.treasury_address = new_address;
    }

    // Emergency withdraw funds from the given market
    public entry fun emergency_withdraw(sender: &signer,  market_id: u64, withdraw_amount: u64) acquires MarketManager {
        assert!( signer::address_of(sender) == @legato_market , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id); 
        let bet_token_metadata = fungible_asset::store_metadata(market_store.bet_pool);
        let pool_signer = object::generate_signer_for_extending(&global.extend_ref);

        let token_out = fungible_asset::withdraw(&pool_signer, market_store.bet_pool, withdraw_amount);
        primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), bet_token_metadata);
        let store = primary_fungible_store::primary_store(signer::address_of(sender), bet_token_metadata);
        fungible_asset::deposit(store, token_out);
    }

    // Emergency deposit funds to the given market
    public entry fun emergency_deposit(sender: &signer, market_id: u64, deposit_amount: u64) acquires MarketManager {
        assert!( signer::address_of(sender) == @legato_market , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.markets, market_id ), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow_mut(&mut global.markets, market_id); 
        let bet_token_metadata = fungible_asset::store_metadata(market_store.bet_pool);
        let input_token = primary_fungible_store::withdraw(sender, bet_token_metadata, deposit_amount);
        fungible_asset::deposit(market_store.bet_pool, input_token);
    }

    // Updates the winning fee.
    public entry fun update_winning_fee(sender: &signer, new_value: u64) acquires MarketManager {
        verify_caller(signer::address_of(sender));
        assert!(  new_value > 0 && new_value <= 4000, ERR_INVALID_VALUE ); // No more 40%
        let global = borrow_global_mut<MarketManager>(@legato_market);
        global.winning_fee = new_value;
    }

    // ======== Internal Functions =========

    // Calculates the payout amount for a given position
    fun calculate_payout_amount(position_id: u64): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market); 
        assert!( table_with_length::contains( &global.positions, position_id ), ERR_NOT_FOUND);

        let current_position = table_with_length::borrow( &global.positions, position_id );
        let market_id = current_position.market_id;
        let outcome_id = current_position.outcome_id;
        let round_id = current_position.round_id;

        // Ensure the market exists
        assert!(table_with_length::contains(&global.markets, market_id), ERR_NOT_FOUND);
        let market_store = table_with_length::borrow(&global.markets, market_id);
        assert!(table_with_length::contains(&market_store.rounds, round_id), ERR_NOT_FOUND);
        let current_round = table_with_length::borrow(&market_store.rounds, round_id);

        // Ensure the round has been resolved
        assert!( current_round.is_resolved == true, ERR_NOT_RESOLVED);
    
        // Check if the outcome associated with the position is a winning outcome
        let (is_winner, _) = vector::index_of<u64>(&current_round.winning_outcomes, &outcome_id); 

        if (is_winner) {
            // Get total bet amount before the given round
            let previous_round_bets = get_bet_amount_before_round(&market_store.rounds, round_id);
            let this_round_amount = if (current_round.total_bet_amount > current_round.total_disputed_amount) {
                current_round.total_bet_amount-current_round.total_disputed_amount
            } else {
                0
            };
            let total_pool_amount = previous_round_bets+this_round_amount;
            
            let total_winning_bets: u64 = 0;
            let outcome_count: u64 = 0;
            let my_weight: u64 = 0;

            // Sum up the total bets placed on all winning outcomes
            while (outcome_count < vector::length(&current_round.winning_outcomes)) {
                let winning_outcome_id = *vector::borrow( &current_round.winning_outcomes, outcome_count );
                let outcome_weights = if (table_with_length::contains( &current_round.outcome_weights, winning_outcome_id )) {
                    *table_with_length::borrow(&current_round.outcome_weights, winning_outcome_id)
                } else {
                    SCALE
                };

                if ( outcome_id == winning_outcome_id ) {
                    my_weight = outcome_weights;
                };

                let outcome_weight_ratio = fixed_point64::create_from_rational( (outcome_weights as u128)  , (SCALE as u128) );
                let adjusted_bet_amount = if (table_with_length::contains( &market_store.outcome_bets, winning_outcome_id )) {
                    *table_with_length::borrow(&market_store.outcome_bets, winning_outcome_id)
                } else {
                    SCALE
                };

                total_winning_bets = total_winning_bets+(adjusted_bet_amount as u64);
                outcome_count = outcome_count+1;
            };

            // Retrieve the weight assigned to the round, defaulting to 1.0 if not set
            let current_round_weight = if (table_with_length::contains( &market_store.round_weights, round_id )) {
                *table_with_length::borrow( &market_store.round_weights, round_id )
            } else {
                SCALE
            };

            // Calculate weight ratio
            let weight_ratio = fixed_point64::create_from_rational( (current_round_weight as u128)  , (SCALE as u128) );
            // Adjust the pool amount based on the weight ratio
            let adjusted_pool_amount = fixed_point64::multiply_u128( (total_pool_amount as u128) , weight_ratio); 

            // Calculate the share of the pool based on the user's contribution to the total winning bets
            let my_outcome_weight_ratio = fixed_point64::create_from_rational( (my_weight as u128)  , (SCALE as u128) );
            let my_adjusted_amount = fixed_point64::multiply_u128( (current_position.amount as u128) , my_outcome_weight_ratio); 
            let user_bet_ratio = fixed_point64::create_from_rational( my_adjusted_amount, (total_winning_bets as u128));
            let payout_amount_for_holder = fixed_point64::multiply_u128( (adjusted_pool_amount) , user_bet_ratio);

            (payout_amount_for_holder as u64)
        } else {
            0
        }
    }

 
    fun get_bet_amount_before_round(rounds: &TableWithLength<u64, Round>, round_id: u64) : u64 {
        let count: u64 = 0;
        let total_amount: u64 = 0;

        while ( count < round_id) {

            if (table_with_length::contains( rounds, count )) {
                let current_round = table_with_length::borrow(rounds, count);
                let available_amount = if (current_round.total_bet_amount > current_round.total_paid_amount) {
                    current_round.total_bet_amount-current_round.total_paid_amount
                } else {
                    0
                };
                if (available_amount > current_round.total_disputed_amount) {
                    available_amount = available_amount-current_round.total_disputed_amount;
                };
                total_amount = total_amount+available_amount;
            };

            count = count+1;
        };

        (total_amount)
    }

    fun get_market_round_mut(market_store: &mut MarketStore, round_id: u64) : &mut Round {
        if (table_with_length::contains( &market_store.rounds , round_id )) {
            table_with_length::borrow_mut( &mut market_store.rounds, round_id )
        } else {
            let new_round = Round {
                total_bet_amount: 0,
                total_paid_amount: 0,
                total_disputed_amount: 0,
                outcome_ids: vector::empty<u64>(),
                position_ids: vector::empty<u64>(),
                outcome_weights: table_with_length::new<u64, u64>(),
                winning_outcomes: vector::empty<u64>(),
                dispute_claims: vector::empty<u64>(),
                is_finalized: false,
                is_resolved: false,
                resolved_timestamp: 0,
                finalized_timestamp: 0
            };
            table_with_length::add( &mut market_store.rounds, round_id, new_round );
            table_with_length::borrow_mut( &mut market_store.rounds, round_id )
        }
    }

    fun verify_caller(manager_address: address) acquires MarketManager {
        let global = borrow_global<MarketManager>(@legato_market);
        let (found, _) = vector::index_of<address>(&global.manager_list, &manager_address);
        assert!( found, ERR_UNAUTHORIZED );
    }

    inline fun create_token_store(pool_signer: &signer, token: Object<Metadata>): Object<FungibleStore> {
        let constructor_ref = &object::create_object_from_object(pool_signer);
        fungible_asset::create_store(constructor_ref, token)
    }

    #[test_only]
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}