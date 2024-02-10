// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// An order-book based marketplace aims to trade underlying fungible tokens in the system 
// with always zero fees and doesn't require upfront liquidity

module legato::marketplace {

    // use std::debug;

    use sui::balance::{ Self, Balance };
    use sui::object::{ Self,  UID };
    use sui::bag::{ Self, Bag};
    use sui::transfer;
    use sui::table::{ Table};
    use sui::tx_context::{ Self, TxContext};
    use sui::coin::{Self, Coin};
    
    use std::vector;
    use std::string::{  String };
   
    use legato::math::{mul_div};
    use legato::vault_lib::{token_to_name};
    use legato::event::{remove_order_event, update_order_event, new_order_event, trade_event};

    // ======== Constants ========

    const MIST_PER_SUI: u64 = 1_000_000_000;

    // ======== Errors ========
    const E_DUPLICATED_ENTRY: u64 = 301;
    const E_NOT_FOUND: u64 = 302;
    const E_UNAUTHORIZED_USER: u64 = 303;
    const E_ZERO_AMOUNT: u64 = 304;
    const E_INSUFFICIENT_AMOUNT: u64 = 305;
    const E_INVALID_QUOTE: u64 = 306;
    const E_INVALID_BASE: u64 = 307;
    const E_NO_ORDER_LISTING: u64 = 306;
    const E_INSUFFICIENT_BALANCE: u64 = 306;
    const E_INVALID_ORDER_ID: u64 = 307;
    const E_PAUSED: u64 = 308;

    // ======== Structs =========

    // The global config for Marketplace
    struct Marketplace has key {
        id: UID,
        has_paused: bool,
        user_balances: Bag,
        markets: Bag, // a collection of QuoteMarket
        order_count: u64 // tracks the total orders and generates unique IDs for distinct identification
    }

    // an easily referenceable currency like USDC or USDT
    struct QuoteMarket<phantom T> has store {
        id: UID,
        token_name: String,
        orders: Bag
    }

    struct Orders<phantom X, phantom Y> has store {
        token_name: String,
        bid_orders: vector<Order<Y>>,
        ask_orders: vector<Order<X>>
    }

    struct Order<phantom T> has store {
        order_id: u64,
        created_epoch: u64,
        balance: Balance<T>,
        unit_price: u64, // per 1 unit
        owner: address
    }

    // before trading, the user needs to deposit tokens first
    struct TokenDeposit<phantom T> has store {
        coin: Balance<T>,
        balances: Table<address,u64>,
        listing: Table<address,u64> // that has been listing
    }

    struct ManagerCap has key {
        id: UID
    }

    fun init(ctx: &mut TxContext) {

        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        let global = Marketplace {
            id: object::new(ctx),  
            has_paused: false,
            user_balances: bag::new(ctx),
            markets: bag::new(ctx),
            order_count: 0
        };

        transfer::share_object(global)
    }

    // ======== Public Functions =========

    // selling base token X for quote token Y. If no bid orders match, then a new ask order will be created
    public entry fun sell_and_listing<X, Y>(global :&mut Marketplace, base_token: Coin<X>, ask_price: u64, ctx: &mut TxContext) {
        check_pause(global);
        check_quote<Y>(global);

        let (remaining_token, quote_token) = matching_bid_orders<X,Y>(global, base_token, ask_price , ctx);
        
        if (coin::value(&quote_token) > 0)
            transfer::public_transfer(quote_token, tx_context::sender(ctx))
            else coin::destroy_zero(quote_token);

        add_ask_order<X,Y>(global, remaining_token, ask_price, ctx);
    }

    // buying base token Y with quote token X. if no ask orders match, then a new bid order will be created
    public entry fun buy_and_listing<X,Y>(global :&mut Marketplace, quote_token: Coin<X>, bid_price: u64, ctx: &mut TxContext) {
        check_pause(global);
        check_quote<X>(global);

        let (remaining_token, base_token) = matching_ask_orders<X,Y>(global, quote_token, bid_price , ctx);

        if (coin::value(&base_token) > 0)
            transfer::public_transfer(base_token, tx_context::sender(ctx))
            else coin::destroy_zero(base_token);


        add_bid_order<X,Y>(global, remaining_token, bid_price, ctx);
    }

    // buying base token Y with quote token X.
    public entry fun buy_only<X,Y>(global :&mut Marketplace, quote_token: Coin<X>, bid_price: u64, ctx: &mut TxContext) {
        check_pause(global);
        check_quote<X>(global);

        let (remaining_token, base_token) = matching_ask_orders<X,Y>(global, quote_token, bid_price , ctx);

        if (coin::value(&remaining_token) > 0)
                transfer::public_transfer(remaining_token, tx_context::sender(ctx))
            else coin::destroy_zero(remaining_token);

        if (coin::value(&base_token) > 0)
            transfer::public_transfer(base_token, tx_context::sender(ctx))
            else coin::destroy_zero(base_token);
        
    }

    public entry fun sell_only<X, Y>(global :&mut Marketplace, base_token: Coin<X>, ask_price: u64, ctx: &mut TxContext) {
        check_pause(global);
        check_quote<Y>(global);

        let (remaining_token, quote_token) = matching_bid_orders<X,Y>(global, base_token, ask_price , ctx);

        if (coin::value(&remaining_token) > 0)
                transfer::public_transfer(remaining_token, tx_context::sender(ctx))
            else coin::destroy_zero(remaining_token);

        if (coin::value(&quote_token) > 0)
            transfer::public_transfer(quote_token, tx_context::sender(ctx))
            else coin::destroy_zero(quote_token);
    }

    public fun buy<X,Y>(global :&mut Marketplace, quote_token: Coin<X>, bid_price: u64, ctx: &mut TxContext) : (Coin<X>, Coin<Y>) {
        matching_ask_orders<X,Y>(global, quote_token, bid_price, ctx)
    }

    public fun sell<X,Y>(global :&mut Marketplace, base_token: Coin<X>, ask_price: u64, ctx: &mut TxContext) : (Coin<X>, Coin<Y>)  {
        matching_bid_orders<X,Y>(global, base_token, ask_price , ctx)
    }

    // checking if the quote token T exists
    public fun check_quote<T>(global: &Marketplace) {
        assert!(bag::contains_with_type<String, QuoteMarket<T>>(&global.markets, token_to_name<T>()), E_INVALID_QUOTE);
    }

    public entry fun update_order<X, Y>(global : &mut Marketplace, order_id: u64, unit_price: u64, ctx: &mut TxContext) {
        check_quote<Y>(global); 

        let market = bag::borrow_mut<String, QuoteMarket<Y>>(&mut global.markets, token_to_name<Y>());
        assert!( bag::contains_with_type<String, Orders<X,Y>>(&market.orders, token_to_name<X>()), E_INVALID_BASE );
        let orders_set = bag::borrow_mut<String, Orders<X,Y>>(&mut market.orders, token_to_name<X>());

        let count = vector::length(&orders_set.ask_orders);
        let i = 0;
        let updated = false;
        while (i < count) {
            let order = vector::borrow_mut(&mut orders_set.ask_orders, i);
            if (order.order_id == order_id) {
                assert!( order.owner == tx_context::sender(ctx), E_UNAUTHORIZED_USER );
                order.unit_price = unit_price;
                updated = true;
                break
            };
            i = i + 1;
        };

        count = vector::length(&orders_set.bid_orders);
        i = 0;
        while (i < count) {
            let order = vector::borrow_mut(&mut orders_set.bid_orders, i);
            if (order.order_id == order_id) {
                assert!( order.owner == tx_context::sender(ctx), E_UNAUTHORIZED_USER );
                order.unit_price = unit_price;
                updated = true;
                break
            };
            i = i + 1;
        };

        assert!( updated,  E_INVALID_ORDER_ID);

        // emit event
        update_order_event(
            object::id(global),
            order_id,
            unit_price,
            tx_context::sender(ctx)
        );
    }

    public entry fun cancel_order<X, Y>(global : &mut Marketplace, order_id: u64, ctx: &mut TxContext) {
        check_quote<Y>(global); 

        let market = bag::borrow_mut<String, QuoteMarket<Y>>(&mut global.markets, token_to_name<Y>());
        assert!( bag::contains_with_type<String, Orders<X,Y>>(&market.orders, token_to_name<X>()), E_INVALID_BASE );
        let orders_set = bag::borrow_mut<String, Orders<X,Y>>(&mut market.orders, token_to_name<X>());

        let count = vector::length(&orders_set.ask_orders);
        let i = 0;
        let updated = false;
        while (i < count) {
            let order = vector::borrow(&orders_set.ask_orders, i);
            if (order.order_id == order_id) {
                assert!( order.owner == tx_context::sender(ctx), E_UNAUTHORIZED_USER );
                let Order<X> { order_id: _, created_epoch: _, balance, unit_price:_, owner:_} = vector::swap_remove(&mut orders_set.ask_orders, i);
                transfer::public_transfer(coin::from_balance(balance, ctx),tx_context::sender(ctx));
                updated = true;
                break
            };
            i = i + 1;
        };

        count = vector::length(&orders_set.bid_orders);
        i = 0;
        while (i < count) {
            let order = vector::borrow(&orders_set.bid_orders, i);
            if (order.order_id == order_id) {
                assert!( order.owner == tx_context::sender(ctx), E_UNAUTHORIZED_USER );
                let Order<Y> { order_id: _, created_epoch: _, balance, unit_price:_, owner:_} = vector::swap_remove(&mut orders_set.bid_orders, i);
                transfer::public_transfer(coin::from_balance(balance, ctx),tx_context::sender(ctx));
                updated = true;
                break
            };
            i = i + 1;
        };

        assert!( updated,  E_INVALID_ORDER_ID);

        // emit event
        remove_order_event(
            object::id(global),
            order_id,
            tx_context::sender(ctx)
        );
    }

    public fun order_balance<T>(orders: &vector<Order<T>>, order_id: u64): u64 {
        let order = vector::borrow(orders, order_id);
        balance::value<T>(&order.balance)
    }

    public fun order_unit_price<T>(orders: &vector<Order<T>>, order_id: u64): u64 {
        let order = vector::borrow(orders, order_id);
        order.unit_price 
    }

    // ======== Only Governance =========

    public entry fun setup_quote<T>( global: &mut Marketplace, _manager_cap: &mut ManagerCap, ctx: &mut TxContext) {
        let market_name = token_to_name<T>();
        let has_registered = bag::contains_with_type<String, QuoteMarket<T>>(&global.markets, market_name);
        assert!(!has_registered, E_DUPLICATED_ENTRY);

        bag::add(&mut global.markets, market_name, QuoteMarket<T> {
            id: object::new(ctx),
            token_name: market_name , 
            orders: bag::new(ctx)
        });
    }

    public entry fun pause( global: &mut Marketplace, _manager_cap: &mut ManagerCap) {
        global.has_paused = true;
    }

    public entry fun unpause( global: &mut Marketplace, _manager_cap: &mut ManagerCap) {
        global.has_paused = false;
    }

    // ======== Internal Functions =========

    fun check_pause(global: &Marketplace) {
        assert!( !global.has_paused, E_PAUSED );
    }

    // base -> quote
    fun add_ask_order<X, Y>(global:  &mut Marketplace, coin_in: Coin<X>, unit_price: u64, ctx: &mut TxContext) {
        
        let sender = tx_context::sender(ctx);
        global.order_count = global.order_count+1;
        let order_id = global.order_count;
        let listing_amount = coin::value(&coin_in);

        let new_order = Order { order_id, created_epoch: tx_context::epoch(ctx),balance: coin::into_balance(coin_in), unit_price, owner: sender };

        let token_name = token_to_name<X>();
        let market = bag::borrow_mut<String, QuoteMarket<Y>>(&mut global.markets, token_to_name<Y>());
        let has_registered = bag::contains_with_type<String, Orders<X,Y>>(&market.orders, token_name);

        if (!has_registered) {
                let bid_orders = vector::empty<Order<Y>>();
                let ask_orders = vector::empty<Order<X>>();
                
                vector::push_back<Order<X>>(&mut ask_orders, new_order);

                let new_orders_set = Orders {
                    token_name,
                    bid_orders,
                    ask_orders
                };
            
                bag::add(&mut market.orders, token_name, new_orders_set);

        } else {
            let orders_set = bag::borrow_mut<String, Orders<X,Y>>(&mut market.orders, token_name);
            vector::push_back<Order<X>>(&mut orders_set.ask_orders, new_order);
        };

        // emit event
        new_order_event(
            object::id(global),
            order_id,
            false,
            token_name,
            token_to_name<Y>(),
            listing_amount,
            unit_price,
            sender
        );

    }

    // quote -> base
    fun add_bid_order<X,Y>(global: &mut Marketplace, coin_in: Coin<X>, unit_price: u64, ctx: &mut TxContext) {

        let sender = tx_context::sender(ctx);
        global.order_count = global.order_count+1;
        let order_id = global.order_count;
        let listing_amount = coin::value(&coin_in);

        let new_order = Order { order_id, created_epoch: tx_context::epoch(ctx),balance: coin::into_balance(coin_in), unit_price, owner: sender };

        let token_name = token_to_name<Y>();
        let market = bag::borrow_mut<String, QuoteMarket<X>>(&mut global.markets, token_to_name<X>());
        let has_registered = bag::contains_with_type<String, Orders<Y,X>>(&market.orders, token_name);

        if (!has_registered) {
            let bid_orders = vector::empty<Order<X>>();
            let ask_orders = vector::empty<Order<Y>>();

            vector::push_back<Order<X>>(&mut bid_orders, new_order);

            let new_orders_set = Orders {
                token_name,
                bid_orders,
                ask_orders
            };
            
            bag::add(&mut market.orders, token_name, new_orders_set);
        } else {
            let orders_set = bag::borrow_mut<String, Orders<Y,X>>(&mut market.orders, token_name);
            vector::push_back<Order<X>>(&mut orders_set.bid_orders, new_order);
        };

        // emit event
        new_order_event(
            object::id(global),
            order_id,
            true,
            token_name,
            token_to_name<X>(),
            listing_amount,
            unit_price,
            sender
        );
    }

    // matching with ask orders
    // quote -> base
    fun matching_ask_orders<X,Y>(global: &mut Marketplace, coin_in: Coin<X>, from_price: u64, ctx: &mut TxContext ): (Coin<X>, Coin<Y>) {
        
        let global_id = object::id(global);
        let token_name = token_to_name<Y>();
        let market = bag::borrow_mut<String, QuoteMarket<X>>(&mut global.markets, token_to_name<X>());
        if (!bag::contains_with_type<String, Orders<Y,X>>(&market.orders, token_name)) {
            let new_orders_set = Orders { token_name, bid_orders: vector::empty<Order<X>>(), ask_orders: vector::empty<Order<Y>>() };
            bag::add(&mut market.orders, token_name, new_orders_set);
        };

        let orders_set = bag::borrow_mut<String, Orders<Y,X>>(&mut market.orders, token_name);

        let remaining_token = coin::into_balance(coin_in);
        let base_token = balance::zero<Y>();

        let input_amount = 0;
        let output_amount = 0;

        if (vector::length(&orders_set.ask_orders) > 0) {
            sort_orders<Y>(&mut orders_set.ask_orders);
            
            let order_ids = eligible_orders<Y>(&orders_set.ask_orders, from_price, false);
            let order_prices = order_unit_prices<Y>(&orders_set.ask_orders);
            let order_balances = order_balances<Y>(&orders_set.ask_orders);

            while (vector::length(&order_ids) > 0) {
                let order_id = vector::remove( &mut order_ids, 0);
                let order_balance = *vector::borrow(&order_balances, order_id);
                let order_unit_price = *vector::borrow(&order_prices, order_id);
                let available_base_in_quote = mul_div(order_balance, order_unit_price, MIST_PER_SUI);

                if (balance::value<X>(&remaining_token) >= available_base_in_quote) {
                        // input value >= order value, then we close the order entirely
                        let Order<Y> { order_id, created_epoch: _, balance, unit_price:_, owner} = vector::swap_remove(&mut orders_set.ask_orders, order_id);
                        let quote_to_transfer =
                            if  (balance::value(&remaining_token) >= available_base_in_quote)
                                available_base_in_quote
                            else balance::value(&remaining_token);

                        input_amount = input_amount+quote_to_transfer;
                        output_amount = output_amount+balance::value(&balance);
                        
                        transfer::public_transfer(coin::from_balance( balance::split(&mut remaining_token, quote_to_transfer), ctx), owner);
                        balance::join(&mut base_token, balance);

                        // emit remove event
                        remove_order_event(
                            global_id,
                            order_id,
                            owner
                        );

                } else {
                        // order value > input value, 
                        let amount = balance::value<X>(&remaining_token);
                        let amount_in_base = mul_div(amount, MIST_PER_SUI, order_unit_price);
                        let order_mut = vector::borrow_mut(&mut orders_set.ask_orders, order_id);

                        transfer::public_transfer(coin::from_balance( balance::split(&mut remaining_token, amount), ctx), order_mut.owner);
                        
                        let base_to_transfer =
                            if  (balance::value(&order_mut.balance) >= amount_in_base)
                                amount_in_base
                            else balance::value(&order_mut.balance);
                        
                        input_amount = input_amount+amount;
                        output_amount = output_amount+base_to_transfer;

                        balance::join(&mut base_token, balance::split(&mut order_mut.balance, base_to_transfer ) );

                };
                if (balance::value<X>(&remaining_token) == 0) break
            };



        };

        if (output_amount > 0) {
            // emit event
            trade_event(
                global_id,
                token_to_name<X>(),
                token_to_name<Y>(),
                input_amount,
                output_amount,
                tx_context::sender(ctx)
            );
        };

        (coin::from_balance(remaining_token, ctx), coin::from_balance(base_token, ctx))
    }

    // matching with bid orders
    // base -> quote
    fun matching_bid_orders<X,Y>(global: &mut Marketplace, coin_in: Coin<X>, from_price: u64, ctx: &mut TxContext ): (Coin<X>, Coin<Y>) {
        
        let global_id = object::id(global);
        let token_name = token_to_name<X>();
        let market = bag::borrow_mut<String, QuoteMarket<Y>>(&mut global.markets, token_to_name<Y>());
        if (!bag::contains_with_type<String, Orders<X,Y>>(&market.orders, token_name)) {
            let new_orders_set = Orders { token_name, bid_orders: vector::empty<Order<Y>>(), ask_orders: vector::empty<Order<X>>() };
            bag::add(&mut market.orders, token_name, new_orders_set);
        };

        let orders_set = bag::borrow_mut<String, Orders<X,Y>>(&mut market.orders, token_name);

        let remaining_token = coin::into_balance(coin_in);
        let quote_token = balance::zero<Y>();

        let input_amount = 0;
        let output_amount = 0;

        if (vector::length(&orders_set.bid_orders) > 0) {
            sort_orders(&mut orders_set.bid_orders);

            let order_ids = eligible_orders(&orders_set.bid_orders, from_price, true);
            let order_prices = order_unit_prices<Y>(&orders_set.bid_orders);
            let order_balances = order_balances<Y>(&orders_set.bid_orders);

            while (vector::length(&order_ids) > 0) {
                let order_id = vector::remove( &mut order_ids, 0);
                let order_balance = *vector::borrow(&order_balances, order_id);
                let order_unit_price = *vector::borrow(&order_prices, order_id);
                // let available_quote_in_base = mul_div(order_balance, MIST_PER_SUI, order_unit_price);
                let available_remaining_in_quote = mul_div(balance::value<X>(&remaining_token), order_unit_price, MIST_PER_SUI);

                // order_balance -> quote
                // remaining_token -> base

                if (available_remaining_in_quote >= order_balance) {
                    // input value >= order value, close the order entirely
                    let Order<Y> { order_id, created_epoch: _, balance, unit_price:_, owner} = vector::swap_remove(&mut orders_set.bid_orders, order_id);
                    let order_balance_in_base = mul_div(order_balance, MIST_PER_SUI, order_unit_price);

                    let base_to_transfer =
                            if  (balance::value(&remaining_token) >= order_balance_in_base)
                                order_balance_in_base
                            else balance::value(&remaining_token);
                    
                    input_amount = input_amount+base_to_transfer;
                    output_amount = output_amount+balance::value(&balance);

                    transfer::public_transfer(coin::from_balance( balance::split(&mut remaining_token, base_to_transfer ), ctx), owner);
                    balance::join(&mut quote_token, balance);

                    // emit remove event
                        remove_order_event(
                            global_id,
                            order_id,
                            owner
                        );
                } else {
                    // order value > input value
                    let order_mut = vector::borrow_mut(&mut orders_set.bid_orders, order_id);
                    let amount = balance::value<X>(&remaining_token);
                    transfer::public_transfer(coin::from_balance( balance::split(&mut remaining_token, amount), ctx), order_mut.owner);

                    let quote_to_transfer =
                            if  (balance::value(&order_mut.balance) >= available_remaining_in_quote)
                                available_remaining_in_quote
                            else balance::value(&order_mut.balance);
                    
                    input_amount = input_amount+amount;
                    output_amount = output_amount+quote_to_transfer;

                    balance::join(&mut quote_token, balance::split(&mut order_mut.balance, quote_to_transfer ) );
                };

                if (balance::value<X>(&remaining_token) == 0) break
            };

        };

        if (output_amount > 0) {
            // emit event
            trade_event(
                global_id,
                token_to_name<X>(),
                token_to_name<Y>(),
                input_amount,
                output_amount,
                tx_context::sender(ctx)
            );
        };

        (coin::from_balance(remaining_token, ctx), coin::from_balance(quote_token, ctx))
    }

    fun sort_orders<T>(orders: &mut vector<Order<T>>) {
        let length = vector::length(orders);
        let i = 1;
        while (i < length) {
            let cur = vector::borrow(orders, i);
            let cur_unit_price = cur.unit_price;
            let j = i;
            while (j > 0) {
                j = j - 1;
                let item = vector::borrow(orders, j);
                let unit_price = item.unit_price;
                if (unit_price > cur_unit_price) {
                    vector::swap(orders, j, j + 1);
                } else {
                    break
                };
            };
            i = i + 1;
        };
    }

    fun eligible_orders<T>(orders: &vector<Order<T>>, from_price: u64, is_bid: bool): vector<u64> {
        let count = vector::length(orders);
        let i = 0;
        let order_ids = vector::empty<u64>();
        while (i < count) {
            let order = vector::borrow(orders, i);
            if (!is_bid) {
                if (from_price >= order.unit_price) {
                    vector::push_back<u64>(&mut order_ids, i);
                };
            } else {
                if (order.unit_price >= from_price) {
                    vector::push_back<u64>(&mut order_ids, i);
                };
            };
            i = i + 1;
        };
        order_ids
    }

    fun order_unit_prices<T>(orders: &vector<Order<T>>): vector<u64> {
        let count = vector::length(orders);
        let i = 0;
        let result = vector::empty<u64>();
        while (i < count) {
            let order = vector::borrow(orders, i);
            vector::push_back<u64>(&mut result, order.unit_price);
            i = i + 1;
        };
        result
    }

    fun order_balances<T>(orders: &vector<Order<T>>): vector<u64> {
        let count = vector::length(orders);
        let i = 0;
        let result = vector::empty<u64>();
        while (i < count) {
            let order = vector::borrow(orders, i);
            vector::push_back<u64>(&mut result, balance::value(&order.balance));
            i = i + 1;
        };
        result
    }



    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

}