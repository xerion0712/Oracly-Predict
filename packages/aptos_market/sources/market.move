// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// Legato's market prediction system enables users to bet on BTC or APT price movements using APT tokens.
// The system leverages AI to estimate probabilities by analyzing external market data, news and price trends.

// Liquidity-Adjusted Probability Formula:
// P(adjusted) = P(outcome) * weight + (L(outcome) / L(pool)) * (1 - weight)

module market_addr::market {

    use std::signer;
    use std::string::{ String, utf8};
    use std::vector;
    use std::option;
    
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::fungible_asset::{ Self, FungibleStore, FungibleAsset, Metadata, MintRef, BurnRef, TransferRef };
    use aptos_framework::primary_fungible_store::{Self};
    use aptos_framework::coin::{Self}; 
 
    use aptos_std::fixed_point64::{Self, FixedPoint64};
    use aptos_std::math_fixed64::{Self};
    use aptos_std::table::{Self, Table};
    use aptos_std::table_with_length::{Self, TableWithLength};

    use legato_vault_addr::vault::{Self};

    // ======== Constants ========

    const SCALE: u64 = 10000; // Scaling factor for fixed-point calculations
    const DEFAULT_COMMISSION_FEE: u64 = 1000; // Default commission fee
    const DEFAULT_RESERVE_RATIO: u64 = 8000; // Default reserve ratio
    const DEFAULT_WITHDRAW_DELAY: u64 = 259200; // Default withdrawal delay, set to 3 days
    const DEFAULT_WEIGHT: u64 = 7000; // Default weight, 70%
    const DEFAULT_RATIO: u64 = 17500; // Default normalized ratio, 1.75
    const DEFAULT_MAX_BET_AMOUNT: u64 = 10_00000000; // 10 APT
    const DEFAULT_MAX_ODDS: u64 = 80000; // 8.0
    const MIN_ADD_LIQUIDITY_AMOUNT: u64 = 1_00000000; // 1 APT 
    const MINIMAL_LIQUIDITY: u64 = 1000;

    // ======== Errors ========

    const ERR_TOO_LOW: u64 = 1;
    const ERR_PAUSED: u64 = 2;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 3;
    const ERR_UNAUTHORIZED: u64 = 4;
    const ERR_NOT_ADMIN: u64 = 5;
    const ERR_DUPLICATED: u64 = 6;
    const ERR_NOT_FOUND: u64 = 7;
    const ERR_ZERO_VALUE: u64 = 8;
    const ERR_INVALID_VALUE: u64 = 9;
    const ERR_RESOLVED: u64 = 10;
    const ERR_INSUFFICIENT_AMOUNT: u64 = 11;
    const ERR_INSUFFICIENT_CAPACITY: u64 = 12;
    const ERR_EXPIRED: u64 = 13;
    const ERR_MAX_BET_AMOUNT: u64 = 14;
    const ERR_OUTCOME_NOT_AVAILABLE: u64 = 15;
    const ERR_NO_POSITION: u64 = 16;
    const ERR_INVALID_ID: u64 = 17;
    const ERR_NOT_EXPIRED: u64 = 18;
    const ERR_NOT_RESOLVED: u64 = 19;
    const ERR_PAYOUT_NOT_ENOUGH: u64 = 20;
    const ERR_EMPTY_LIST: u64 = 21;

    // ======== Structs =========

    struct MarketConfig has store {
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
    struct Position has store {
        holder: address,
        market_type: u8, // 1 - BTC, 2 - APT, 3 - CUSTOM 
        placing_odds: u64, // The odds at which the user placed
        amount: u64, // The amount of APT the user has placed
        predicted_outcome: u8, // The outcome chosen
        round: u64, // The market round in which the bet was placed
        timestamp: u64, // The time when the bet was placed
        is_open: bool // A flag indicating whether the position is still open or settled
    }

    // Liquidity Pool takes all incoming bets and distributes P&L,
    // acting as the party taking the opposite side of the bet.
    // Additionally, it earns passive income by staking APT via Legato's liquid staking vault.
    struct LiquidityPool has store { 
        used_bet_amount: u64, // Tracks the total amount already used for betting
        lp_mint: MintRef,
        lp_burn: BurnRef,
        lp_transfer: TransferRef,
        lp_metadata: Object<Metadata>, // Metadata for the LP token
        min_liquidity: Object<FungibleStore>,
        min_amount: u64, // Minimum amount required to deposit/withdraw
        withdraw_delay: u64 // Delay withdrawal period specified in seconds
    }

    // Represents a request to withdraw APT from the liquidity pool
    struct Request has store, drop {
        sender: address, // Address of the user making the request
        amount: u64, // APT amount to be sent out when available 
        timestamp: u64 // Timestamp at which the request was made
    }

    struct MarketManager has key {
        admin_list: vector<address>,
        extend_ref: ExtendRef,
        market_btc: Table<u64, MarketConfig>, // Table containing BTC market data for each round.
        market_apt: Table<u64, MarketConfig>,  // Table containing APT market data for each round.
        market_custom: Table<u64, MarketConfig>, // Seasonal market.
        current_round: u64, // Tracks the current market round. 
        positions: TableWithLength<u64, Position>,  // Holds the list of user bet positions
        liquidity_pool: LiquidityPool, 
        commission_fee: u64, // Commission fee taken from winnings
        reserve_ratio: u64, // Proportion of liquidity pool value allowed for betting
        weight: u64, // Higher weight means greater reliance on liquidity pool size.
        max_bet_amount: u64, 
        max_odds: u64, // Cap the odds at a certain level
        treasury_address: address, // where all fees will be sent
        is_paused: bool, // whether the system is currently paused
        pending_fulfil: u64,
        request_list: vector<Request>
    }

    #[event]
    struct PlaceBetEvent has drop, store {
        round: u64,
        market_type: u8,
        bet_outcome: u8,
        bet_amount: u64,
        placing_odds: u64,
        timestamp: u64,
        sender: address
    }

    #[event]
    struct AddLiquidity has drop, store {
        deposit_amount: u64,
        lp_amount: u64,
        timestamp: u64,
        sender: address
    }

    #[event]
    struct PayoutWinnersEvent has drop, store {
        round: u64,
        market_type: u8,
        from_id: u64,
        until_id: u64,
        total_winners: u64,
        total_payout_amount: u64,
        timestamp: u64,
        sender: address
    }

    #[event]
    struct AddMarketEvent has drop, store {
        round: u64,
        market_type: u8,
        probability_1: u64,
        probability_2: u64,
        probability_3: u64,
        probability_4: u64,
        ratio: u64,
        expiration: u64,
        timestamp: u64,
        sender: address
    }

    #[event]
    struct UpdateMarketEvent has drop, store {
        round: u64,
        market_type: u8,
        probability_1: u64,
        probability_2: u64,
        probability_3: u64,
        probability_4: u64,
        ratio: u64,
        timestamp: u64, 
        sender: address
    }

    #[event]
    struct ResolveMarketEvent has drop, store {
        round: u64,
        market_type: u8,
        winning_outcome: u8, 
        timestamp: u64, 
        sender: address
    }

    #[event]
    struct RequestWithdraw has drop, store {
        lp_amount: u64,
        withdraw_amount: u64,
        sender: address,
        timestamp: u64
    }

    #[event]
    struct Redeem has drop, store { 
        withdraw_amount: u64,
        sender: address,
        timestamp: u64
    }

    // Initializes the module
    fun init_module(sender: &signer) {

        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        
        let config_object_signer = object::generate_signer_for_extending(&extend_ref);

        // Initialize LP's token 
        let lp_token_ref = &object::create_named_object(&config_object_signer,  b"LP");

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            lp_token_ref,
            option::none(),
            utf8(b"Market LP Token"),
            utf8(b"LP"),
            8,
            utf8(b"https://img.tamago.finance/legato-logo-icon.png"),
            utf8(b"https://legato.finance"),
        );

        let lp_metadata = object::object_from_constructor_ref<Metadata>(lp_token_ref);
        let vault_metadata = vault::get_vault_metadata();

        let admin_list = vector::empty<address>();

        vector::push_back<address>(&mut admin_list, signer::address_of(sender));

        move_to(sender, MarketManager {
            admin_list,
            extend_ref,
            market_btc: table::new<u64, MarketConfig>(),
            market_apt: table::new<u64, MarketConfig>(),
            market_custom: table::new<u64, MarketConfig>(),
            current_round: 0,
            positions: table_with_length::new<u64, Position>(),
            liquidity_pool: LiquidityPool { 
                used_bet_amount: 0,
                lp_mint: fungible_asset::generate_mint_ref(lp_token_ref),
                lp_burn: fungible_asset::generate_burn_ref(lp_token_ref),
                lp_transfer: fungible_asset::generate_transfer_ref(lp_token_ref),
                lp_metadata, 
                min_liquidity: create_token_store(&config_object_signer, lp_metadata),
                min_amount: MIN_ADD_LIQUIDITY_AMOUNT,
                withdraw_delay: DEFAULT_WITHDRAW_DELAY
            },
            commission_fee: DEFAULT_COMMISSION_FEE,
            reserve_ratio: DEFAULT_RESERVE_RATIO,
            treasury_address: signer::address_of(sender),
            max_bet_amount: DEFAULT_MAX_BET_AMOUNT, 
            max_odds: DEFAULT_MAX_ODDS, 
            weight: DEFAULT_WEIGHT,
            is_paused: false,
            pending_fulfil: 0,
            request_list: vector::empty<Request>()
        });

    }

    // ======== Entry Functions =========

    public entry fun place_bet(sender: &signer, round: u64, market_type: u8, bet_outcome: u8, bet_amount: u64) acquires MarketManager {
        let max_capacity =  check_betting_capacity();
        
        let global = borrow_global_mut<MarketManager>(@market_addr);
        assert!(global.is_paused == false, ERR_PAUSED);
        assert!(coin::balance<AptosCoin>(signer::address_of(sender)) >= bet_amount, ERR_INSUFFICIENT_AMOUNT);
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( bet_outcome > 0 && bet_outcome <= 4, ERR_INVALID_VALUE );
        assert!( global.max_bet_amount >= bet_amount, ERR_MAX_BET_AMOUNT);
        assert!( max_capacity >= bet_amount, ERR_INSUFFICIENT_CAPACITY);

        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_apt, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_apt, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_custom, round)
        };

        assert!(  market_config.expiration > timestamp::now_seconds(), ERR_EXPIRED);
        assert!(  market_config.resolved  == false, ERR_RESOLVED);

        let (l_outcome, p_outcome) = update_market_outcomes( market_config, bet_outcome, bet_amount );
        let total_liquidity = total_outcomes(market_config);

        let p_adjusted = calculate_p_adjusted(p_outcome, global.weight, l_outcome, total_liquidity, market_config.ratio);

        let placing_odds = calculate_odds( p_adjusted, global.max_odds );

        let new_position = Position {
            holder: signer::address_of(sender),
            market_type,
            placing_odds,
            amount: bet_amount,
            predicted_outcome: bet_outcome,
            round,
            timestamp: timestamp::now_seconds(),
            is_open: true
        };

        let new_position_id = table_with_length::length( &global.positions );

        table_with_length::add( &mut global.positions, new_position_id, new_position );

        // Transfer APT to the object
        let input_coin = coin::withdraw<AptosCoin>(sender, bet_amount);
        if (!coin::is_account_registered<AptosCoin>(signer::address_of(&config_object_signer))) {
            coin::register<AptosCoin>(&config_object_signer);
        };

        coin::deposit(signer::address_of(&config_object_signer), input_coin);

        // Update the states
        global.liquidity_pool.used_bet_amount = global.liquidity_pool.used_bet_amount+bet_amount;

        // Emit an event 
        event::emit(
            PlaceBetEvent {
                round,
                market_type,
                bet_outcome,
                bet_amount,
                placing_odds,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )

    }

    // Provides liquidity by depositing APTOS coins into the pool
    // Receives LP tokens in return, which increase in value from incoming bets
    // Also earns passive income through liquid staking
    public entry fun provide(sender: &signer, deposit_amount: u64) acquires MarketManager {
        let global = borrow_global_mut<MarketManager>(@market_addr);
        assert!(global.is_paused == false, ERR_PAUSED);
        assert!(coin::balance<AptosCoin>(signer::address_of(sender)) >= global.liquidity_pool.min_amount, ERR_TOO_LOW);

        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        let lp_supply = option::destroy_some(fungible_asset::supply(global.liquidity_pool.lp_metadata));

        let lp_amount_to_mint = if (lp_supply == 0) {
            // Check if initial liquidity is sufficient.
            assert!(deposit_amount > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH);
            let min_lp_tokens = fungible_asset::mint(&global.liquidity_pool.lp_mint, MINIMAL_LIQUIDITY);
            fungible_asset::deposit(global.liquidity_pool.min_liquidity, min_lp_tokens);
            deposit_amount - MINIMAL_LIQUIDITY
        } else {
            let total_vault_locked = primary_fungible_store::balance( signer::address_of(&config_object_signer), vault::get_vault_metadata() );
            let current_staking_amount = get_current_staking_amount(total_vault_locked);
            let current_balance = current_staking_amount+coin::balance<AptosCoin>(signer::address_of(&config_object_signer));
            let ratio = fixed_point64::create_from_rational((deposit_amount as u128) , (current_balance as u128));
            let total_share = fixed_point64::multiply_u128( (lp_supply as u128) , ratio); 
            (total_share as u64)
        };
   
        // Mint LP tokens and deposit them into the sender's account 
        let lp_tokens = fungible_asset::mint(&global.liquidity_pool.lp_mint, lp_amount_to_mint);

        primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), global.liquidity_pool.lp_metadata );
        let lp_store = primary_fungible_store::primary_store(signer::address_of(sender), global.liquidity_pool.lp_metadata );
        fungible_asset::deposit(lp_store, lp_tokens);

        // Transfer APT to the object
        let input_coin = coin::withdraw<AptosCoin>(sender, deposit_amount);
        if (!coin::is_account_registered<AptosCoin>(signer::address_of(&config_object_signer))) {
            coin::register<AptosCoin>(&config_object_signer);
        };

        coin::deposit(signer::address_of(&config_object_signer), input_coin);

        vault::mint(&config_object_signer, deposit_amount );

        // Emit an event 
        event::emit(
            AddLiquidity {
                deposit_amount,
                lp_amount: lp_amount_to_mint,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    }

    // Initiates a withdrawal request by the sender
    public entry fun request_withdraw(sender:&signer, lp_amount: u64 ) acquires MarketManager {
        let global = borrow_global_mut<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        assert!(global.is_paused == false, ERR_PAUSED);
        assert!( primary_fungible_store::balance( signer::address_of(sender), global.liquidity_pool.lp_metadata ) >= lp_amount , ERR_INSUFFICIENT_AMOUNT );

        let lp_supply = option::destroy_some(fungible_asset::supply(global.liquidity_pool.lp_metadata));
        let total_vault_locked = primary_fungible_store::balance( signer::address_of(&config_object_signer), vault::get_vault_metadata() );
        let current_staking_amount = get_current_staking_amount(total_vault_locked);
        let current_balance = current_staking_amount+coin::balance<AptosCoin>(signer::address_of(&config_object_signer));

        let multiplier = fixed_point64::create_from_rational( (lp_amount as u128), ( lp_supply as u128));
        let withdrawal_amount = (fixed_point64::multiply_u128( (current_balance as u128), multiplier) as u64);

        global.pending_fulfil = global.pending_fulfil+withdrawal_amount;

        vector::push_back( &mut global.request_list, Request {
            sender: signer::address_of(sender), 
            amount: withdrawal_amount,
            timestamp: timestamp::now_seconds()
        });

        // Burn vault tokens on the sender's account 
        primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), global.liquidity_pool.lp_metadata );
        let lp_store = primary_fungible_store::primary_store(signer::address_of(sender), global.liquidity_pool.lp_metadata );
        fungible_asset::burn_from(&global.liquidity_pool.lp_burn, lp_store, lp_amount);

        // Emit an event
        event::emit(
            RequestWithdraw {
                lp_amount,
                withdraw_amount: withdrawal_amount, 
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )

    }

    // Fulfil unstaking requests for everyone in the list
    public entry fun fulfil_request() acquires MarketManager {
        let global = borrow_global_mut<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        assert!( vector::length(&global.request_list) > 0, ERR_EMPTY_LIST );

        let total_amount = 0;

        // Fulfil each eligible request
        while ( vector::length(&global.request_list) > 0) {
            let this_request = vector::pop_back(&mut global.request_list);
            let apt_coin = coin::withdraw<AptosCoin>(&config_object_signer, this_request.amount);
            coin::deposit(this_request.sender, apt_coin);

            total_amount = total_amount+this_request.amount;

            // Emit an event
            event::emit(
                Redeem { 
                    withdraw_amount: this_request.amount, 
                    timestamp: timestamp::now_seconds(),  
                    sender: this_request.sender
                }
            );
        };

        global.pending_fulfil = if (global.pending_fulfil > total_amount) {
            global.pending_fulfil-total_amount
        } else {
            0
        };
        
    }

    // This allows anyone to execute the payout of winners for a given market round.
    // It checks the payout amount, ensures sufficient funds, and distributes winnings to eligible participants.
    public entry fun payout_winners(sender: &signer, round: u64, market_type: u8, from_id: u64, until_id: u64) acquires MarketManager {

        // Get the list of winners, payout amounts, and all eligible bet position IDs.
        let ( winner_list, amount_list, all_eligible_ids ) = list_winners_and_payouts( round, market_type, from_id, until_id );

        let total_payout_amount = 0;
        let count = 0;
        let length = vector::length(&amount_list);

        // Calculate the total payout amount by summing all 
        while (count < length) {
            total_payout_amount = total_payout_amount+*vector::borrow( &amount_list, count );
            count = count+1;
        };

        let global = borrow_global_mut<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        let available_for_pay = (coin::balance<AptosCoin>(signer::address_of(&config_object_signer)));

        // Ensure there is enough liquidity to cover the payouts.
        assert!( available_for_pay >= total_payout_amount, ERR_PAYOUT_NOT_ENOUGH );

        count = 0;

        let fee_ratio = fixed_point64::create_from_rational( (global.commission_fee as u128), 10000);
        let fees = 0; 
        
        // Payout the winnings to each eligible address.
        while ( count < vector::length(&winner_list)) {
            let winner_address = *vector::borrow( &winner_list, count);
            let payout_amount = *vector::borrow( &amount_list, count);
            let fee_amount = (fixed_point64::multiply_u128( (payout_amount as u128) , fee_ratio) as u64); 

            let payout_coin = coin::withdraw<AptosCoin>(&config_object_signer, payout_amount-fee_amount);
            coin::deposit(winner_address, payout_coin);

            fees = fees+fee_amount;
            count = count+1;
        };
        
        if (fees > 0) {
            let payout_coin = coin::withdraw<AptosCoin>(&config_object_signer, fees);
            coin::deposit(global.treasury_address, payout_coin);
        };

        let all_bet_amount = 0;

        while ( vector::length( &all_eligible_ids ) > 0 ) {
            let position_id = vector::pop_back( &mut all_eligible_ids);
            let entry = table_with_length::borrow_mut(&mut global.positions, position_id);
            all_bet_amount = all_bet_amount+entry.amount;
            entry.is_open = false;
        };

        global.liquidity_pool.used_bet_amount = if (global.liquidity_pool.used_bet_amount > all_bet_amount) {
            global.liquidity_pool.used_bet_amount-all_bet_amount
        } else {
            0
        };
        
        // Emit an event
        event::emit(
            PayoutWinnersEvent {
                round,
                market_type,
                from_id,
                until_id,
                total_winners: vector::length(&winner_list) ,
                total_payout_amount,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )

    }

    // ======== Public Functions =========

    #[view]    
    public fun get_config_object_address(): address acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        signer::address_of(&config_object_signer)
    }

    // Return the address of LP's token metadata
    #[view]
    public fun get_lp_metadata(): Object<Metadata> acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr); 
        global.liquidity_pool.lp_metadata
    }

    // Returns the amount of LP's vault tokens currently locked in the contract.
    #[view]
    public fun get_total_vault_locked() : u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        let vault_metadata = vault::get_vault_metadata();
        (primary_fungible_store::balance( signer::address_of(&config_object_signer), vault_metadata ))
    }

    // Returns the amount of LP's all tokens locked equivalent to their APT value.
    #[view]
    public fun get_total_vault_balance(): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        let vault_metadata = vault::get_vault_metadata();
        let total_vault_locked = primary_fungible_store::balance( signer::address_of(&config_object_signer), vault_metadata );
        (get_current_staking_amount(total_vault_locked)+coin::balance<AptosCoin>(signer::address_of(&config_object_signer)))
    }

    #[view]
    public fun get_lp_share_from_apt(input_amount: u64): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        let lp_supply = option::destroy_some(fungible_asset::supply(global.liquidity_pool.lp_metadata));
        let total_vault_locked = primary_fungible_store::balance( signer::address_of(&config_object_signer), vault::get_vault_metadata() ); 
        let current_balance = get_current_staking_amount(total_vault_locked)+coin::balance<AptosCoin>(signer::address_of(&config_object_signer));
        let ratio = fixed_point64::create_from_rational((input_amount as u128) , (current_balance as u128));
        let total_share = fixed_point64::multiply_u128( (lp_supply as u128) , ratio); 
        (total_share as u64)
    }


    #[view]
    public fun get_apt_from_lp_share(lp_amount: u64): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);

        let lp_supply = option::destroy_some(fungible_asset::supply(global.liquidity_pool.lp_metadata));
        let total_vault_locked = primary_fungible_store::balance( signer::address_of(&config_object_signer), vault::get_vault_metadata() ); 
        let current_balance = get_current_staking_amount(total_vault_locked)+coin::balance<AptosCoin>(signer::address_of(&config_object_signer));
        let ratio = fixed_point64::create_from_rational((lp_amount as u128) , (lp_supply as u128));
        let result = fixed_point64::multiply_u128( (current_balance as u128) , ratio); 
        (result as u64)
    }

    // Returns the maximum amount of APT that can be bet.
    #[view]
    public fun check_betting_capacity(): u64 acquires MarketManager {
        let current_balance = get_total_vault_balance();

        let global = borrow_global<MarketManager>(@market_addr);
        let ratio = fixed_point64::create_from_rational(( global.reserve_ratio as u128), 10000);
        
        let max_available = (fixed_point64::multiply_u128( (current_balance as u128) , ratio) as u64);

        if (max_available > global.liquidity_pool.used_bet_amount) {
            (max_available-global.liquidity_pool.used_bet_amount)
        } else {
            0
        }
    }

    #[view]
    public fun get_current_round(): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        global.current_round
    }

    #[view]
    public fun get_market_info(round: u64, market_type: u8): (vector<u64>, vector<u64>, bool, u8, u64, u64, u64) acquires MarketManager {
        get_market_info_internal(round, market_type)
    }

    #[view]
    public fun get_market_adjusted_probabilities(round: u64, market_type: u8): (vector<u64>) acquires MarketManager {
        let (liquidity_outcome_list, p_outcome_list, _, _, _, ratio, total_liquidity ) = get_market_info_internal(round, market_type);

        let global = borrow_global<MarketManager>(@market_addr);
        let global_weight = global.weight;

        let output = vector::empty<u64>();

        let count = 0;

        while (count < 4) {
            let l_outcome = *vector::borrow( &liquidity_outcome_list, count );
            let p_outcome = *vector::borrow( &p_outcome_list, count );
            let p_adjusted = calculate_p_adjusted(p_outcome, global_weight, l_outcome, total_liquidity, ratio );
            vector::push_back(&mut output, p_adjusted);
            count = count+1;
        };

        output
    }

    // Retrieves the IDs of all bet positions for a given market type and user address.
    #[view]
    public fun get_bet_position_ids(market_type: u8, user_address: address) : (vector<u64>) acquires MarketManager {
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        
        let global = borrow_global<MarketManager>(@market_addr);
        
        let count = 0;
        let result = vector::empty<u64>();

        while ( count < table_with_length::length( &global.positions) ) {
            let this_position = table_with_length::borrow( &global.positions, count );
            if ( market_type == this_position.market_type && user_address == this_position.holder ) {
                vector::push_back( &mut result, count );
            };
            count = count+1;
        };
    
        result
    }

    // Returns the bet position for a given ID in the following order:
    // market_type, placing_odds, bet_amount, selected_outcome, round, timestamp and is_open
    #[view]
    public fun get_bet_position(position_id: u64) : (u8, u64, u64, u8, u64, u64, bool )  acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let entry = table_with_length::borrow( &global.positions, position_id );
        ( entry.market_type, entry.placing_odds, entry.amount, entry.predicted_outcome, entry.round, entry.timestamp, entry.is_open )
    }

    // Returns the total number of winners and the payout amount for the specified round and market type.
    #[view]
    public fun check_payout_amount(round: u64, market_type: u8, from_id: u64, until_id: u64) : (u64, u64) acquires MarketManager {
        let (_, amount_list , _) = list_winners_and_payouts( round, market_type, from_id, until_id );
        let total_amount = 0;
        let count = 0;
        let length = vector::length(&amount_list);

        while (count < length) {
            total_amount = total_amount+*vector::borrow( &amount_list, count );
            count = count+1;
        };

        (length, total_amount)
    }

    #[view]
    public fun total_bet_positions(): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        (table_with_length::length(&global.positions))
    }

    #[view]
    public fun available_for_immediate_payout(): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        (coin::balance<AptosCoin>(signer::address_of(&config_object_signer)))
    }

    #[view]
    public fun pending_fulfil(): u64 acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        (global.pending_fulfil)
    }

    // ======== Only Governance =========

    // Updates the treasury address that receives the commission fee.
    public entry fun update_treasury_adddress(sender: &signer, new_address: address) acquires MarketManager {
        assert!( signer::address_of(sender) == @market_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.treasury_address = new_address;
    }

    // Adds a given address to the admin list.
    public entry fun add_admin(sender: &signer, admin_address: address) acquires MarketManager {
        assert!( signer::address_of(sender) == @market_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@market_addr);
        let (found, _) = vector::index_of<address>(&global.admin_list, &admin_address);
        assert!( found == false , ERR_DUPLICATED);
        vector::push_back(&mut global.admin_list, admin_address );
    }

    // Removes a given address from the admin list.
    public entry fun remove_admin(sender: &signer, admin_address: address) acquires MarketManager {
        assert!( signer::address_of(sender) == @market_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@market_addr);
        let (found, index) = vector::index_of<address>(&global.admin_list, &admin_address);
        assert!( found == true , ERR_NOT_FOUND);
        vector::swap_remove<address>(&mut global.admin_list, index );
    }

    // Pause and unpause the system. 
    public entry fun pause(sender: &signer, is_paused: bool) acquires MarketManager {
        assert!( signer::address_of(sender) == @market_addr , ERR_UNAUTHORIZED);
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.is_paused = is_paused;
    }

    // Adds a market configuration for the given round.
    public entry fun add_market(
        sender: &signer, 
        round: u64, 
        market_type: u8,
        probability_1: u64,
        probability_2: u64,
        probability_3: u64,
        probability_4: u64,
        expiration: u64
    ) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( expiration >= timestamp::now_seconds(), ERR_INVALID_VALUE );
        
        let global = borrow_global_mut<MarketManager>(@market_addr);

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
            assert!( table::contains( &global.market_apt, round ) == false, ERR_DUPLICATED);
            table::add( &mut global.market_apt, round, new_market );
        } else {
            assert!( table::contains( &global.market_custom, round ) == false, ERR_DUPLICATED);
            table::add( &mut global.market_custom, round, new_market );
        };

        // Update current round
        if (round > global.current_round) {
            global.current_round = round;
        };

        // Emit an event
        event::emit(
            AddMarketEvent {
                round,
                market_type,
                probability_1,
                probability_2,
                probability_3,
                probability_4,
                ratio: DEFAULT_RATIO,
                expiration,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )

    }

    // Updates the market outcome probabilities.
    public entry fun set_market_probabilities(sender: &signer, round: u64, market_type: u8, probability_1: u64, probability_2: u64, probability_3: u64, probability_4: u64, ratio: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        
        let global = borrow_global_mut<MarketManager>(@market_addr);

        assert!( probability_1+probability_2+probability_3+probability_4 == 10000, ERR_INVALID_VALUE );

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_apt, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_apt, round)
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
        event::emit(
            UpdateMarketEvent {
                round,
                market_type,
                probability_1,
                probability_2,
                probability_3,
                probability_4, 
                ratio,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    }

    // Marks the market as resolved and assigns the winning outcome.
    public entry fun resolve_market(sender: &signer, round: u64, market_type: u8, winning_outcome: u8 ) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( winning_outcome > 0 , ERR_INVALID_VALUE );

        let global = borrow_global_mut<MarketManager>(@market_addr);

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_apt, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_apt, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow_mut(&mut global.market_custom, round)
        };

        assert!( market_config.resolved == false, ERR_RESOLVED );

        market_config.resolved = true;
        market_config.winning_outcome = winning_outcome;

        // Emit an event
        event::emit(
            ResolveMarketEvent {
                round,
                market_type,
                winning_outcome,
                timestamp: timestamp::now_seconds(),  
                sender: signer::address_of(sender)
            }
        )
    }

    // Updates the current round
    public entry fun update_round(sender: &signer, round: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.current_round = round;
    }

    public entry fun update_min_amount(sender: &signer, new_value: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( new_value > 0, ERR_ZERO_VALUE );
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.liquidity_pool.min_amount = new_value;
    }

    public entry fun update_withdraw_delay(sender: &signer, new_value: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( 2592000 >= new_value, ERR_INVALID_VALUE ); // No more 30 days
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.liquidity_pool.withdraw_delay = new_value;
    }

    // Updates the commission fee.
    public entry fun update_commission_fee(sender: &signer, new_value: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!(  new_value > 0 && new_value <= 4000, ERR_INVALID_VALUE ); // No more 40%
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.commission_fee = new_value;
    }

    // Updates the reserve ratio value
    public entry fun update_reserve_ratio(sender: &signer, new_value: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!(  new_value > 0 && new_value <= 100000, ERR_INVALID_VALUE ); // No more 1,000%
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.reserve_ratio = new_value;
    }

    // Updates the global weight.
    public entry fun update_weight(sender: &signer, new_value: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( new_value > 0 && new_value <= 10000, ERR_INVALID_VALUE);
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.weight = new_value;
    }

    // Updates the maximum bet amount.
    public entry fun update_max_bet_amount(sender: &signer, new_value: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( new_value > 0, ERR_ZERO_VALUE );
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.max_bet_amount = new_value;
    }

    // Updates the odds cap.
    public entry fun update_odds_cap(sender: &signer, new_value: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( new_value >= 10000, ERR_ZERO_VALUE ); // more than 1.0
        let global = borrow_global_mut<MarketManager>(@market_addr);
        global.max_odds = new_value;
    }

    // Stakes the locked APT tokens to Legato's liquid staking vault
    public entry fun stake_locked_apt_to_legato_vault(sender: &signer, stake_amount: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( stake_amount > 0, ERR_ZERO_VALUE );

        let global = borrow_global_mut<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref);
        
        assert!(coin::balance<AptosCoin>(signer::address_of(&config_object_signer)) >= stake_amount, ERR_INSUFFICIENT_AMOUNT);
    
        vault::mint(&config_object_signer, stake_amount);
    }

    // Requests to unstake APT tokens from Legato's liquid staking vault
    public entry fun request_unstake_apt_from_legato_vault(sender: &signer, unstake_amount: u64) acquires MarketManager {
        verify_admin(signer::address_of(sender));
        assert!( unstake_amount > 0, ERR_ZERO_VALUE );

        let global = borrow_global_mut<MarketManager>(@market_addr);
        let config_object_signer = object::generate_signer_for_extending(&global.extend_ref); 
        let total_vault_locked = primary_fungible_store::balance( signer::address_of(&config_object_signer), vault::get_vault_metadata() );
        let total_balance_in_vault = get_current_staking_amount(total_vault_locked);

        assert!( total_balance_in_vault >= unstake_amount, ERR_LIQUID_NOT_ENOUGH);

        let ratio = fixed_point64::create_from_rational((unstake_amount as u128), (total_balance_in_vault as u128));
        let vault_to_unstake = (fixed_point64::multiply_u128( (total_vault_locked as u128) , ratio) as u64);

        vault::request_redeem( &config_object_signer, vault_to_unstake);
    }

    // ======== Internal Functions =========

    inline fun create_token_store(vault_signer: &signer, token: Object<Metadata>): Object<FungibleStore> {
        let constructor_ref = &object::create_object_from_object(vault_signer);
        fungible_asset::create_store(constructor_ref, token)
    }

    fun verify_admin(admin_address: address) acquires MarketManager {
        let global = borrow_global<MarketManager>(@market_addr);
        let (found, _) = vector::index_of<address>(&global.admin_list, &admin_address);
        assert!( found, ERR_UNAUTHORIZED );
    }

    fun get_current_staking_amount(current_vault_amount: u64): u64 {
        let (pool_balance, pool_vault) = vault::get_amounts();
        let ratio = fixed_point64::create_from_rational((current_vault_amount as u128), (pool_vault as u128));
        let result = fixed_point64::multiply_u128( (pool_balance as u128) , ratio);
        (result as u64)
    }

    fun get_market_info_internal(round: u64, market_type: u8): (vector<u64>, vector<u64>, bool, u8, u64, u64, u64) acquires MarketManager {
        assert!( round > 0, ERR_INVALID_VALUE );
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);

        let global = borrow_global<MarketManager>(@market_addr);

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_apt, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_apt, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_custom, round)
        };

        let total_bets = vector::empty<u64>();
        let probabilities = vector::empty<u64>();

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
    fun list_winners_and_payouts(round: u64, market_type: u8, from_id: u64, until_id: u64) : (vector<address>, vector<u64>, vector<u64>) acquires MarketManager {
        assert!( market_type == 0 || market_type == 1 || market_type == 2, ERR_INVALID_VALUE);
        assert!( until_id > from_id, ERR_INVALID_VALUE);
        
        let global = borrow_global<MarketManager>(@market_addr);

        let market_config = if (market_type == 0) {
            assert!( table::contains( &global.market_btc, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_btc, round)
        } else if (market_type == 1) {
            assert!( table::contains( &global.market_apt, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_apt, round)
        } else {
            assert!( table::contains( &global.market_custom, round ), ERR_NOT_FOUND);
            table::borrow(&global.market_custom, round)
        };

        assert!( market_config.resolved == true , ERR_NOT_RESOLVED);

        let count = from_id;
        let count_length = if (until_id > table_with_length::length( &global.positions )) {
            table_with_length::length( &global.positions )
        } else {
            until_id
        };

        let winner_list = vector::empty<address>();
        let payout_amount_list = vector::empty<u64>();
        let all_ids = vector::empty<u64>(); 
        
        while ( count < count_length) {
            let entry = table_with_length::borrow( &global.positions, count );
            if (entry.is_open == true && entry.round == round && entry.market_type == market_type && timestamp::now_seconds() > market_config.expiration) {
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

    #[test_only]
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }


}