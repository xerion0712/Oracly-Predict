// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// A contract responsible for distributing coin rewards through staking must define the reward currency
// then deposit and define the amount to spend on each epoch


module legato::lp_staking {

    // use std::debug;

    use sui::object::{ Self, UID };
    use sui::tx_context::{ Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::bag::{Self,  Bag};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

    use legato::vault::{ManagerCap};
    use legato::vault_lib::{token_to_name};
    use legato::math::{mul_div};
    use legato::event::{stake_event, unstake_event, withdraw_rewards_event, deposit_rewards_event, snapshot_event};

    use std::vector;
    use std::string::{  String }; 

    // ======== Errors ========
    const E_PAUSED: u64 = 1;
    const E_INVALID_POOL: u64 = 2;
    const E_INSUFFICIENT_AMOUNT: u64 = 3;
    const E_NO_REWARD_SET: u64 = 4;
    const E_INVALID_COIN: u64 = 5;
    const E_TABLE_REWARD_ERROR: u64 = 6;

    // ======== Structs =========

    // The global config for Staking
    // FIXME: seperates struct
    struct Staking has key {
        id: UID,
        has_paused: bool,
        user_list: Table<String, vector<address>>,
        pool_reward: Table<String, String>, // each pool's reward currency
        deposits: Bag,
        balances: Bag,
        rewards: Bag,
        reward_table: Bag,
        claim_table: Bag,
        outstanding: Bag // already withdrawn
    }

    fun init(ctx: &mut TxContext) {

        let global = Staking {
            id: object::new(ctx),  
            has_paused: false,
            user_list: table::new(ctx),
            pool_reward: table::new(ctx),
            deposits: bag::new(ctx),
            balances: bag::new(ctx),
            rewards: bag::new(ctx),
            reward_table: bag::new(ctx),
            claim_table: bag::new(ctx),
            outstanding: bag::new(ctx)
        };

        transfer::share_object(global)
    }

    // ======== Public Functions =========

    public entry fun stake<P>(global: &mut Staking, input_coin: Coin<P>, ctx: &mut TxContext) {
        check_pause(global);
        let pool_name = token_to_name<P>();
        let has_registered = bag::contains_with_type<String, Balance<P>>(&global.deposits, pool_name);

        // register a pool if it does not exist
        if (!has_registered) {
            bag::add(&mut global.deposits, pool_name, balance::zero<P>());
            bag::add(&mut global.balances, pool_name, table::new<address, u64>(ctx));
        };

        let input_amount = coin::value<P>(&input_coin);

        let pool_deposit = bag::borrow_mut<String, Balance<P>>(&mut global.deposits, pool_name);
        let pool_balance = bag::borrow_mut<String, Table<address, u64>>(&mut global.balances, pool_name);

        balance::join(pool_deposit, coin::into_balance(input_coin));
        
        if (table::contains(pool_balance, tx_context::sender(ctx))) {
            *table::borrow_mut(pool_balance, tx_context::sender(ctx)) = *table::borrow(pool_balance, tx_context::sender(ctx))+input_amount;
        } else {
            table::add(pool_balance, tx_context::sender(ctx), input_amount);
        };

        // add user to the list
        if (table::contains(&global.user_list, pool_name)) {
            let user_list = table::borrow_mut(&mut global.user_list, pool_name);
            vector::push_back<address>(user_list, tx_context::sender(ctx));
        } else {
            let new_user_list = vector::empty<address>();
            vector::push_back<address>(&mut new_user_list, tx_context::sender(ctx));
            table::add(&mut global.user_list, pool_name, new_user_list);
        };

        // emit event
        stake_event(
            object::id(global),
            pool_name,
            input_amount,
            tx_context::epoch(ctx),
            tx_context::sender(ctx)
        );

    }

    public entry fun unstake<P>(global: &mut Staking, unstake_amount: u64, ctx: &mut TxContext) {
        check_pause(global);
        let pool_name = token_to_name<P>();
        assert!(bag::contains_with_type<String, Balance<P>>(&global.deposits, pool_name), E_INVALID_POOL);

        let pool_balance = bag::borrow_mut<String, Table<address, u64>>(&mut global.balances, pool_name);        
        let available_amount = *table::borrow(pool_balance, tx_context::sender(ctx));
        assert!( available_amount >= unstake_amount, E_INSUFFICIENT_AMOUNT);

        *table::borrow_mut(pool_balance, tx_context::sender(ctx)) = available_amount-unstake_amount;

        let pool_deposit = bag::borrow_mut<String, Balance<P>>(&mut global.deposits, pool_name);
        transfer::public_transfer(
                coin::from_balance(balance::split(pool_deposit, unstake_amount), ctx),
                tx_context::sender(ctx)
            );
        
        // emit event
        unstake_event(
            object::id(global),
            pool_name,
            unstake_amount,
            tx_context::epoch(ctx),
            tx_context::sender(ctx)
        );
    }

    public entry fun withdraw_rewards<X,Y>(global: &mut Staking, ctx: &mut TxContext) {
        let pool_name = token_to_name<X>();
        assert!( table::contains(&global.pool_reward, pool_name), E_NO_REWARD_SET );
        let reward_name = *table::borrow(&global.pool_reward, pool_name);
        assert!( reward_name == token_to_name<Y>(), E_INVALID_COIN );

        let claim_table = bag::borrow_mut<String, Table<u64, Table<address, u64>>>(&mut global.claim_table, pool_name);
        let current_epoch = tx_context::epoch(ctx);
        let sender = tx_context::sender(ctx);

        let total_reward_amount = 0;

        while (current_epoch > 0) {
            if (table::contains( claim_table, current_epoch )) {
                let claim_table_for_epoch = table::borrow(claim_table, current_epoch);
                if (table::contains( claim_table_for_epoch, sender )) {
                    let amount = *table::borrow(claim_table_for_epoch, sender);
                    total_reward_amount = total_reward_amount+amount;
                };
            };

            current_epoch = current_epoch-1;
        };
        
        // checking outstanding
        if (!bag::contains_with_type<String, Table<address, u64>>(&global.outstanding, reward_name)) {
            let new_table  = table::new<address, u64>(ctx);
            table::add(&mut new_table, sender, total_reward_amount);
            bag::add(&mut global.outstanding, reward_name, new_table);
        } else {
            let outstanding_balance = bag::borrow_mut<String, Table<address, u64>>(&mut global.outstanding, reward_name);
            if (!table::contains(outstanding_balance, sender)) {
                table::add(outstanding_balance, sender, total_reward_amount);
            } else {
                let total_my_outstanding = *table::borrow(outstanding_balance, sender);
                if (total_reward_amount > total_my_outstanding) {
                    *table::borrow_mut(outstanding_balance, sender) = total_my_outstanding+total_reward_amount;
                } else {
                    total_reward_amount = 0;
                };
            };
        };

        // sending rewards
        if (total_reward_amount > 0) {
            let pool_deposit = bag::borrow_mut<String, Balance<Y>>(&mut global.rewards, reward_name);
            transfer::public_transfer(
                    coin::from_balance(balance::split(pool_deposit, total_reward_amount), ctx),
                    tx_context::sender(ctx)
                );

            // emit event
            withdraw_rewards_event(
                object::id(global),
                pool_name,
                reward_name,
                total_reward_amount,
                tx_context::epoch(ctx),
                tx_context::sender(ctx)
            );

        };

    }

    public entry fun deposit_rewards<X,Y>(global: &mut Staking, input_coin: Coin<Y>, ctx: &mut TxContext) {
        let pool_name = token_to_name<X>();
        assert!( table::contains(&global.pool_reward, pool_name), E_NO_REWARD_SET );
        let reward_name = *table::borrow(&global.pool_reward, pool_name);
        assert!( reward_name == token_to_name<Y>(), E_INVALID_COIN );

        let has_registered = bag::contains_with_type<String, Balance<Y>>(&global.rewards, reward_name);

        // register a pool if it does not exist
        if (!has_registered) {
            bag::add(&mut global.rewards, reward_name, balance::zero<Y>());
        };

        let input_amount = coin::value(&input_coin);

        let pool_deposit = bag::borrow_mut<String, Balance<Y>>(&mut global.rewards, reward_name);
        balance::join(pool_deposit, coin::into_balance(input_coin));

        // emit event
        deposit_rewards_event(
            object::id(global),
            pool_name,
            reward_name,
            input_amount,
            tx_context::epoch(ctx),
            tx_context::sender(ctx)
        );

    }   

    // make the claimer list on the next epoch
    public entry fun snapshot<P>(global: &mut Staking, ctx: &mut TxContext) {
        let pool_name = token_to_name<P>();
        assert!(bag::contains_with_type<String, Balance<P>>(&global.deposits, pool_name), E_INVALID_POOL);
        assert!(table::contains(&global.pool_reward, pool_name), E_NO_REWARD_SET );
        assert!(bag::contains_with_type<String, Table<u64, u64>>(&global.reward_table, pool_name), E_TABLE_REWARD_ERROR);

        let reward_name = *table::borrow(&global.pool_reward, pool_name);
        let reward_table = bag::borrow_mut<String, Table<u64, u64>>(&mut global.reward_table, pool_name);
        let current_epoch = tx_context::epoch(ctx);
        let epoch_to_stamp = current_epoch+1;

        let total_rewards_to_spend = 0;

        // find the reward per epoch from the closest entry in the reward table
        while (current_epoch > 0) {
            if (table::contains(reward_table, current_epoch)) {
                total_rewards_to_spend = *table::borrow(reward_table, current_epoch);
                break
            };
            current_epoch = current_epoch-1;
        };

        if (total_rewards_to_spend > 0) {

            let pool_balance = bag::borrow_mut<String, Table<address, u64>>(&mut global.balances, pool_name);
            let user_list = *table::borrow_mut(&mut global.user_list, pool_name);
            let total_pool_amount = 0;
            let claim_list = table::new<address, u64>(ctx);

            while (vector::length(&user_list) > 0) {
                let user_address = vector::remove(&mut user_list, 0);
                let user_amount = *table::borrow_mut(pool_balance, user_address);
                total_pool_amount = total_pool_amount+user_amount;
            };

            // replace values on claim table
            user_list = *table::borrow_mut(&mut global.user_list, pool_name);
            while (vector::length(&user_list) > 0) {
                let user_address = vector::remove(&mut user_list, 0);
                let user_amount = *table::borrow_mut(pool_balance, user_address);
                let reward_amount = mul_div(total_rewards_to_spend, user_amount, total_pool_amount);
                table::add(&mut claim_list, user_address, reward_amount);
            };

            let has_registered = bag::contains_with_type<String, Table<u64, Table<address, u64>>>(&global.claim_table, pool_name);
            if (!has_registered) {
                let new_table = table::new<u64, Table<address, u64>>(ctx);
                table::add(&mut new_table, epoch_to_stamp, claim_list);
                bag::add(&mut global.claim_table, pool_name, new_table );
            } else {
                let claim_table = bag::borrow_mut<String, Table<u64, Table<address, u64>>>(&mut global.claim_table, pool_name);
                table::add(claim_table, epoch_to_stamp, claim_list);
            };

        };

        // emit event
        snapshot_event(
            object::id(global),
            pool_name,
            reward_name,
            total_rewards_to_spend,
            tx_context::epoch(ctx),
            tx_context::sender(ctx)
        );

    }

    // ======== Only Governance =========

    public entry fun pause( global: &mut Staking, _manager_cap: &mut ManagerCap) {
        global.has_paused = true;
    }

    public entry fun unpause( global: &mut Staking, _manager_cap: &mut ManagerCap) {
        global.has_paused = false;
    }
    
    public entry fun set_reward<X,Y>(global: &mut Staking, _manager_cap: &mut ManagerCap) {
        set_reward_<X,Y>(global);
    }

    public entry fun set_reward_table<P>(global: &mut Staking, _manager_cap: &mut ManagerCap, from_epoch: u64, reward_amount: u64, ctx: &mut TxContext) {
        let pool_name = token_to_name<P>();
        let has_registered = bag::contains_with_type<String, Table<u64, u64>>(&global.reward_table, pool_name);

        // register a pool if it does not exist
        if (!has_registered) {
            let new_table = table::new<u64, u64>(ctx);
            table::add(&mut new_table, from_epoch, reward_amount);
            bag::add(&mut global.reward_table, pool_name, new_table );
        } else {
            let reward_table = bag::borrow_mut<String, Table<u64, u64>>(&mut global.reward_table, pool_name);
            if (table::contains(reward_table, from_epoch)) 
                *table::borrow_mut(reward_table, from_epoch) = reward_amount
            else table::add(reward_table, from_epoch, reward_amount);
        };

    }

    // ======== Internal Functions =========

    fun check_pause(global: &Staking) {
        assert!( !global.has_paused, E_PAUSED );
    }

    fun set_reward_<X,Y>(global: &mut Staking) {
        let pool_name = token_to_name<X>();

        if (table::contains(&global.pool_reward, pool_name)) 
            *table::borrow_mut(&mut global.pool_reward, pool_name) = token_to_name<Y>()
        else table::add(&mut global.pool_reward, pool_name, token_to_name<Y>());
    }

    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}