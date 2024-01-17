// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::marketplace {

    // use std::debug;

    use sui::object::{ Self, UID , ID };
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::bag::{Self, Bag};
    use sui::coin::{Self, Coin};
    use sui::balance::{ Self,   Balance };
    use sui::event::{Self};
    
    use std::ascii::{  into_bytes};
    use std::type_name::{get, into_string};
    use std::string::{Self, String };
    

    use std::vector;

    // ======== Constants ========

    

    // ======== Errors ========
    const E_DUPLICATED_ENTRY: u64 = 301;
    const E_NOT_FOUND: u64 = 302;
    const E_UNAUTHORIZED_USER: u64 = 303;
    const E_ZERO_AMOUNT: u64 = 304;
    const E_INSUFFICIENT_AMOUNT: u64 = 305;

    // ======== Structs =========

    // struct LP<phantom X, phantom Y> has drop, store {}

    

    // SUI or USDC
    struct BaseMarket<phantom T> has store {
        id: UID,
        global: ID,
        pairs: Bag
    }

    struct TokenDeposit<phantom T> has store {
        coin: Balance<T>,
        balances: Table<address,u64>
    }

    /// The global config for Marketplace
    struct GlobalMarketplace has key {
        id: UID,
        admin: vector<address>,
        treasury: address,
        has_paused: bool,
        user_balances: Bag,
        markets: Bag
        // orders: Bag
    }

    struct DepositEvent has copy, drop {
        global: ID,
        token_name: String,
        input_amount: u64,
        sender: address
    }

    struct WithdrawEvent has copy, drop {
        global: ID,
        token_name: String,
        withdraw_amount: u64,
        sender: address
    }
    
    fun init(ctx: &mut TxContext) {

        let admin_list = vector::empty<address>();
        vector::push_back<address>(&mut admin_list, tx_context::sender(ctx));

        let global = GlobalMarketplace {
            id: object::new(ctx),
            admin: admin_list, 
            treasury: tx_context::sender(ctx),
            has_paused: false,
            user_balances: bag::new(ctx),
            markets: bag::new(ctx)
            // orders: bag::new(ctx)
        };

        transfer::share_object(global)

    }

    // ======== Public Functions =========

    // public entry fun list_coin<X, Y>(
    //     global :&mut GlobalMarketplace,
    //     input_coin: Coin<X>,
    //     ask_price: u64,
    //     ctx: &mut TxContext
    // ) {


    // }

    // public entry fun delist_coin() {

    // }

    // public entry fun list_staked_sui() {

    // }

    // public entry fun delist_staked_sui() {

    // }

    // public entry fun buy() {

    // }

    // public entry fun sell() {

    // }

    public entry fun deposit<T>(global :&mut GlobalMarketplace , input_coin: Coin<T>, ctx: &mut TxContext) {

        let token_name = token_to_name<T>();
        let input_amount = coin::value(&input_coin);

        let has_registered = bag::contains_with_type<String, TokenDeposit<T>>(&global.user_balances, token_name);
        if (!has_registered) {
            
            let init_coin = balance::zero<T>();
            balance::join<T>(&mut init_coin, coin::into_balance(input_coin));

            let init_table = table::new(ctx);
            table::add(&mut init_table, tx_context::sender(ctx), input_amount);

            let new_token_deposit = TokenDeposit {
                coin: init_coin,
                balances: init_table
            };
            
            bag::add(&mut global.user_balances, token_name, new_token_deposit);
        } else {

            let token_deposit = bag::borrow_mut<String, TokenDeposit<T>>(&mut global.user_balances, token_name);
            balance::join<T>(&mut token_deposit.coin, coin::into_balance(input_coin));

            if (table::contains(&token_deposit.balances, tx_context::sender(ctx))) {
                let user_amount = table::remove( &mut token_deposit.balances, tx_context::sender(ctx) );
                table::add(&mut token_deposit.balances, tx_context::sender(ctx), user_amount+input_amount);
            } else {
                table::add(&mut token_deposit.balances, tx_context::sender(ctx), input_amount);
            };

        };

        // emit event
        event::emit(
            DepositEvent {
                global : object::id(global),
                token_name,
                input_amount,
                sender: tx_context::sender(ctx)
            }
        )

    }

    public entry fun withdraw<T>(global :&mut GlobalMarketplace, withdraw_amount: u64, ctx: &mut TxContext) {

        let token_name = token_to_name<T>();
        let has_registered = bag::contains_with_type<String, TokenDeposit<T>>(&global.user_balances, token_name);
        assert!(has_registered, E_NOT_FOUND);

        let token_deposit = bag::borrow_mut<String, TokenDeposit<T>>(&mut global.user_balances, token_name);
        assert!(table::contains(&token_deposit.balances, tx_context::sender(ctx)), E_ZERO_AMOUNT);

        let available_amount = table::remove(&mut token_deposit.balances, tx_context::sender(ctx));
        assert!(available_amount >= withdraw_amount, E_INSUFFICIENT_AMOUNT);
        table::add(&mut token_deposit.balances, tx_context::sender(ctx), available_amount-withdraw_amount);

        let to_sender = balance::split(&mut token_deposit.coin, withdraw_amount);
        transfer::public_transfer( coin::from_balance(to_sender, ctx) , tx_context::sender(ctx));

        // emit event
        event::emit(
            WithdrawEvent {
                global : object::id(global),
                token_name,
                withdraw_amount,
                sender: tx_context::sender(ctx)
            }
        )

    }

    public fun token_to_name<T>(): String {
        string::utf8(into_bytes(into_string(get<T>())))
    }

    // ======== Only Governance =========

    public entry fun setup_market<T>( global :&mut GlobalMarketplace , ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));

        let market_name = token_to_name<T>();
        let has_registered = bag::contains_with_type<String, BaseMarket<T>>(&global.markets, market_name);
        assert!(!has_registered, E_DUPLICATED_ENTRY);

        let new_market = BaseMarket<T> {
            id: object::new(ctx),
            global: object::id(global),
            pairs: bag::new(ctx)
        };
        bag::add(&mut global.markets, market_name, new_market);
    }

    // add new admin
    public entry fun add_admin(global: &mut GlobalMarketplace, user: address, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        assert!(!vector::contains(&global.admin, &user),E_DUPLICATED_ENTRY);
        vector::push_back<address>(&mut global.admin, user);
    }

    // remove admin
    public entry fun remove_admin(global: &mut GlobalMarketplace, user: address, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let (contained, index) = vector::index_of<address>(&global.admin, &user);
        assert!(contained,E_NOT_FOUND);
        vector::remove<address>(&mut global.admin, index);
    }

    // ======== Internal Functions =========

    fun check_admin(global: &GlobalMarketplace, sender: address) {
        let (contained, _) = vector::index_of<address>(&global.admin, &sender);
        assert!(contained,E_UNAUTHORIZED_USER);
    }

    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

}