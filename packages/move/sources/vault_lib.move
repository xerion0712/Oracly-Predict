// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::vault_lib {

    use sui::math;
    use sui::balance::{  Self, Supply, Balance };
    use sui::object::{ Self, ID, UID }; 
    use sui::table::{ Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::bag::{Self, Bag};
    use sui::coin::{Self, Coin };

    use sui_system::staking_pool::{ Self, StakedSui};
    use sui_system::sui_system::{  Self, SuiSystemState };

    use std::vector;
    use std::string::{ Self, String };
    use std::ascii::{ into_bytes};
    use std::type_name::{get, into_string};

    use legato::apy_reader::{Self}; 
    use legato::event::{ mint_event, redeem_event, exit_event };

    friend legato::vault;

    // ======== Constants ========
    const MIST_PER_SUI : u64 = 1_000_000_000;
    const MIN_SUI_TO_STAKE : u64 = 1_000_000_000; // 1 Sui
    const MIN_YT_TO_DEPOSIT: u64 = 1_000_000_000;
    const MIN_PT_TO_REDEEM: u64 = 1_000_000_000; // 1 PT
    const MIN_YT_FOR_EXIT: u64 = 1_000_000_000; // 1 YT
    const MAX_EPOCH: u64 = 365;
    const COOLDOWN_EPOCH: u64 = 3;
    const CLAIM_EPOCH: u64 = 3; // able to claim at every 3 epoch
    const YT_TOTAL_SUPPLY: u64 = 100_000_000 * 1_000_000_000; // 100 Mil. 

    // ======== Errors ========
    const E_NOT_REGISTERED: u64 = 201;
    const E_DUPLICATED_ENTRY: u64 = 202; 
    const E_NOT_FOUND: u64 = 203;
    const E_INVALID_AMOUNT: u64 = 204;
    const E_UNAUTHORIZED_POOL: u64 = 205;
    const E_VAULT_MATURED: u64 = 206;
    const E_MIN_THRESHOLD: u64 = 207;
    const E_VAULT_NOT_MATURED: u64 = 208;
    const E_INSUFFICIENT_AMOUNT: u64 = 209;
    const E_EXIT_DISABLED: u64 = 210;
    const E_INVALID_EPOCH: u64 = 211;
    const E_VAULT_NOT_STARTED: u64 = 212;
    const E_INVALID_VAULT_CONFIG: u64 = 213;

    // ======== Structs =========

    struct PT has drop {}
    struct YT has drop {}

    struct TOKEN<phantom P, phantom T> has drop {}

    // fixed-term vault pool for Staked SUI object
    struct PoolConfig has key, store {
        id: UID,
        name: String,
        global: ID,
        created_epoch: u64,
        started_epoch: u64,
        maturity_epoch: u64,
        vault_apy: u64,
        staking_pools: vector<ID>, // supported staking pools (if Staked SUI)
        enable_mint: bool,
        enable_exit: bool
    }

    struct PoolReserve<phantom P> has key, store {
        id: UID,
        global: ID,
        principal_staked_sui: Table<u64, StakedSui>,
        principal_count: u64,
        pt_supply: Supply<TOKEN<P, PT>>,
        yt_supply: Supply<TOKEN<P, YT>>,
        pending_withdrawal: Balance<SUI>,
        total_principal: u64,
        total_principal_rewards: u64, // accumulated rewards at the time of conversion
        total_debt: u64
    }

    // ======== Public Functions =========

    // convert Staked SUI to PT
    public fun mint_non_entry<P>(wrapper: &mut SuiSystemState, vault_config: &mut PoolConfig, vault_reserve: &mut PoolReserve<P>, staked_sui: StakedSui, ctx: &mut TxContext) {
        assert!( vault_config.name == vault_name<P>(),E_INVALID_VAULT_CONFIG);
        assert!(vault_config.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!(tx_context::epoch(ctx) >= vault_config.started_epoch, E_VAULT_NOT_STARTED);
        assert!(staking_pool::staked_sui_amount(&staked_sui) >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);

        let pool_id = staking_pool::pool_id(&staked_sui);
        assert!(vector::contains(&vault_config.staking_pools, &pool_id), E_UNAUTHORIZED_POOL);

        let asset_object_id = object::id(&staked_sui);

        // Take the Staked SUI
        let principal_amount = staking_pool::staked_sui_amount(&staked_sui);
        let total_earnings = 
            if (tx_context::epoch(ctx) > staking_pool::stake_activation_epoch(&staked_sui))
                apy_reader::earnings_from_staked_sui(wrapper, &staked_sui, tx_context::epoch(ctx))
            else 0;

        let deposit_id = receive_staked_sui<P>(vault_reserve, staked_sui);

        // Calculate PT to send out
        let debt_amount = calculate_pt_debt_from_epoch(vault_config.vault_apy, tx_context::epoch(ctx), vault_config.maturity_epoch, principal_amount+total_earnings);
        let minted_pt_amount = principal_amount+total_earnings+debt_amount;

        increment_balances<P>( vault_reserve, principal_amount, total_earnings, debt_amount );

        // Mint PT to the user
        mint_pt<P>(vault_reserve, minted_pt_amount, ctx);

        let earning_balance = vault_accumulated_rewards<P>(wrapper, vault_reserve, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance, pending_withdrawal) = get_balances<P>(vault_reserve);

        // emit event
        mint_event(
            vault_name<P>(),
            pool_id,
            principal_amount,
            minted_pt_amount,
            deposit_id,
            asset_object_id,
            tx_context::sender(ctx),
            tx_context::epoch(ctx),
            principal_balance,
            debt_balance,
            earning_balance,
            pending_withdrawal
        );
    }

    public fun redeem_non_entry<P>(wrapper: &mut SuiSystemState, vault_config: &mut PoolConfig, vault_reserve: &mut PoolReserve<P>, pt: Coin<TOKEN<P,PT>>, ctx: &mut TxContext) {
        assert!( vault_config.name == vault_name<P>(),E_INVALID_VAULT_CONFIG);
        assert!(tx_context::epoch(ctx) > vault_config.maturity_epoch, E_VAULT_NOT_MATURED);
        assert!(coin::value<TOKEN<P,PT>>(&pt) >= MIN_PT_TO_REDEEM, E_MIN_THRESHOLD);

        let paidout_amount = coin::value<TOKEN<P,PT>>(&pt);
        
        prepare_withdrawal<P>(wrapper, vault_reserve, paidout_amount, ctx);

        // withdraw 
        withdraw_sui(vault_reserve, paidout_amount, tx_context::sender(ctx) , ctx );

        // burn PT tokens
        let burned_balance = balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(pt));

        let earning_balance = vault_accumulated_rewards<P>(wrapper, vault_reserve, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance, pending_withdrawal) = get_balances<P>(vault_reserve);

        redeem_event(
            vault_name<P>(),
            burned_balance,
            paidout_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx),
            principal_balance,
            debt_balance,
            earning_balance,
            pending_withdrawal,
        );

    }

    public(friend) fun exit_non_entry<P>(
        wrapper: &mut SuiSystemState,
        vault_config: &mut PoolConfig, 
        vault_reserve: &mut PoolReserve<P>,
        deposit_id: u64,
        pt: Coin<TOKEN<P,PT>>,
        yt: Coin<TOKEN<P,YT>>,
        ctx: &mut TxContext
    ): (u64, u64, Coin<TOKEN<P,YT>>) {
        assert!(vault_config.name == vault_name<P>(),E_INVALID_VAULT_CONFIG);
        assert!(vault_config.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!(table::contains(&vault_reserve.principal_staked_sui, deposit_id), E_NOT_FOUND);
        assert!(vault_config.enable_exit == true, E_EXIT_DISABLED);

        let staked_sui = table::borrow(&vault_reserve.principal_staked_sui, deposit_id);
        let asset_object_id = object::id(staked_sui);

        // PT needed calculates from the principal + accumurated rewards
        let needed_pt_amount = staking_pool::staked_sui_amount(staked_sui)+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, tx_context::epoch(ctx));

        // YT covers of the remaining debt until the vault matures at 1:10 ratio
        let pt_outstanding_debts = calculate_pt_debt_from_epoch(vault_config.vault_apy, tx_context::epoch(ctx), vault_config.maturity_epoch, needed_pt_amount);
        let needed_yt_amount = 10 * pt_outstanding_debts;

        if (MIN_YT_FOR_EXIT > needed_yt_amount) needed_yt_amount = MIN_YT_FOR_EXIT;

        let input_pt_amount = coin::value<TOKEN<P,PT>>(&pt);
        let input_yt_amount = coin::value<TOKEN<P,YT>>(&yt);

        assert!( input_pt_amount >= needed_pt_amount , E_INSUFFICIENT_AMOUNT);
        assert!( input_yt_amount >= needed_yt_amount , E_INSUFFICIENT_AMOUNT);

        // burn PT
        if (input_pt_amount == needed_pt_amount) {
            balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(pt));
        } else {
            let burned_coin = coin::split(&mut pt, input_pt_amount, ctx);
            balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(burned_coin));
            transfer::public_transfer(pt, tx_context::sender(ctx));
        };

        // send out Staked SUI
        transfer::public_transfer( table::remove(&mut vault_reserve.principal_staked_sui, deposit_id), tx_context::sender(ctx) );
        decrement_balances(vault_reserve, needed_pt_amount, pt_outstanding_debts);

        let earning_balance = vault_accumulated_rewards(wrapper, vault_reserve, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance, pending_withdrawal) = get_balances(vault_reserve);

        exit_event(
            vault_name<P>(),
            deposit_id,
            asset_object_id,
            needed_pt_amount,
            needed_yt_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx),
            principal_balance,
            debt_balance,
            earning_balance,
            pending_withdrawal
        );

        (input_pt_amount, needed_yt_amount, yt)
    } 

    public(friend) fun generate_staked_sui_vault<P>(global_id: ID, started_epoch: u64, maturity_epoch: u64, initial_apy: u64, ctx: &mut TxContext ) : (PoolConfig, PoolReserve<P>) {
        assert!(started_epoch >= tx_context::epoch(ctx), E_INVALID_EPOCH);
        assert!(maturity_epoch > started_epoch, E_INVALID_EPOCH);

        ( PoolConfig {
            id: object::new(ctx),
            name: vault_name<P>() ,
            global: global_id,
            created_epoch: tx_context::epoch(ctx),
            started_epoch,
            maturity_epoch,
            vault_apy: initial_apy,
            staking_pools: vector::empty<ID>(),
            enable_exit : false,
            enable_mint: true
        }, PoolReserve {
            id: object::new(ctx),
            global: global_id,
            principal_staked_sui: table::new(ctx),
            principal_count: 0,
            pt_supply: balance::create_supply(TOKEN<P,PT> {}),
            yt_supply: balance::create_supply(TOKEN<P,YT> {}),
            pending_withdrawal: balance::zero(),
            total_principal: 0,
            total_principal_rewards: 0,
            total_debt: 0
        } )
    }

    public(friend) fun setup_yt_supply<P>(pool: &mut PoolReserve<P>): Balance<TOKEN<P,YT>> {
        balance::increase_supply(&mut pool.yt_supply, YT_TOTAL_SUPPLY)
    }

    public fun vault_name<P>(): String {
        string::utf8(into_bytes(into_string(get<P>())))
    }

    public fun get_mut_vault<P>(vaults: &mut Bag): &mut PoolReserve<P> {
        let vault_name = vault_name<P>();
        let has_registered = bag::contains_with_type<String, PoolReserve<P>>(vaults, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        bag::borrow_mut<String, PoolReserve<P>>(vaults, vault_name)
    }

    public fun get_vault_config<P>(table: &mut Table<String, PoolConfig>): &mut PoolConfig {
        let vault_name = vault_name<P>();
        let has_registered = table::contains(table, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        table::borrow_mut<String, PoolConfig>(table, vault_name)
    }

    // add support staking pool
    public(friend) fun add_pool(vault: &mut PoolConfig, pool_id: ID) {
        assert!(!vector::contains(&vault.staking_pools, &pool_id), E_DUPLICATED_ENTRY);
        vector::push_back<ID>(&mut vault.staking_pools, pool_id);
    }

    // remove support staking pool
    public(friend) fun remove_pool(vault: &mut PoolConfig, pool_id: ID) {
        let (contained, index) = vector::index_of<ID>(&vault.staking_pools, &pool_id);
        assert!(contained, E_NOT_FOUND);
        vector::remove<ID>(&mut vault.staking_pools, index);
    }

    // topup
    public(friend) fun emergency_topup<P>(vault: &mut PoolReserve<P>, sui: Coin<SUI>) {
        let balance = coin::into_balance(sui);
        balance::join<SUI>(&mut vault.pending_withdrawal, balance);
    }

    public(friend) fun update_config(vault: &mut PoolConfig, enable_mint: bool, enable_exit: bool ) {
        vault.enable_mint = enable_mint;
        vault.enable_exit = enable_exit;
    }

    public(friend) fun update_apy(vault: &mut PoolConfig, value: u64) {
        vault.vault_apy = value;
    }

    public fun vault_accumulated_rewards<P>(wrapper: &mut SuiSystemState, vault: &PoolReserve<P>, epoch: u64): u64 {
        let count = table::length(&vault.principal_staked_sui);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            if (table::contains(&vault.principal_staked_sui, i)) {
                let staked_sui = table::borrow(&vault.principal_staked_sui, i);
                let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);
                if (epoch > activation_epoch) total_sum = total_sum+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);
            };
            i = i + 1;
        };
        total_sum
    }

    public fun get_balances<P>(vault: &PoolReserve<P>) : (u64, u64, u64, u64) {
        (vault.total_principal, vault.total_principal_rewards, vault.total_debt, balance::value(&vault.pending_withdrawal))
    }

    public fun pool_started_epoch(config: &PoolConfig): u64 {
        config.started_epoch
    }

    public fun pool_maturity_epoch(config: &PoolConfig): u64 {
        config.maturity_epoch
    }

    // ======== Internal Functions =========

    // initiates the withdrawal by performing the unstaking of locked Staked SUI objects and keeping SUI tokens for redemption one by one at a time
    fun prepare_withdrawal<P>(wrapper: &mut SuiSystemState, vault_reserve: &mut PoolReserve<P>, paidout_amount: u64, ctx: &mut TxContext) {
        
        // ignore if there are sufficient SUI to pay out 
        if (paidout_amount > balance::value(&vault_reserve.pending_withdrawal)) {
             // extract all asset IDs to be withdrawn
            let asset_ids = locate_withdrawable_asset(wrapper, vault_reserve, paidout_amount, tx_context::epoch(ctx));

            // unstake assets
            let sui_balance = unstake_staked_sui(wrapper, vault_reserve, asset_ids, ctx);
            balance::join<SUI>(&mut vault_reserve.pending_withdrawal, sui_balance);
            
        };
    }

    fun locate_withdrawable_asset<P>(wrapper: &mut SuiSystemState, vault_reserve: &mut PoolReserve<P>, paidout_amount: u64, epoch: u64):  vector<u64> {

        let count = 0;
        let asset_ids = vector::empty();
        let amount_to_unwrap = paidout_amount-balance::value(&vault_reserve.pending_withdrawal);

        while (amount_to_unwrap > 0) {
            if (table::contains(&vault_reserve.principal_staked_sui, count)) {
                let staked_sui = table::borrow(&vault_reserve.principal_staked_sui, count);
                let amount_with_rewards = staking_pool::staked_sui_amount(staked_sui)+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);

                vector::push_back<u64>(&mut asset_ids, count);

                amount_to_unwrap =
                    if (paidout_amount >= amount_with_rewards)
                        paidout_amount - amount_with_rewards
                    else 0;
            };

            count = count + 1;

            if (count == vault_reserve.principal_count) amount_to_unwrap = 0
            
        };

        asset_ids
    }

    fun unstake_staked_sui<P>(wrapper: &mut SuiSystemState, vault_reserve: &mut PoolReserve<P>, asset_ids: vector<u64>, ctx: &mut TxContext) : Balance<SUI> {

        let balance_sui = balance::zero();

        while (vector::length<u64>(&asset_ids) > 0) {
            let asset_id = vector::pop_back(&mut asset_ids);
            let staked_sui = table::remove(&mut vault_reserve.principal_staked_sui, asset_id);

            let principal_amount = staking_pool::staked_sui_amount(&staked_sui);
            let balance_each = sui_system::request_withdraw_stake_non_entry(wrapper, staked_sui, ctx);

            let reward_amount =
                if (balance::value(&balance_each) >= principal_amount)
                    balance::value(&balance_each) - principal_amount
                else 0;

            balance::join<SUI>(&mut balance_sui, balance_each);

            decrement_balances(vault_reserve, principal_amount, reward_amount);
        };

        balance_sui
    }

    fun receive_staked_sui<P>(vault_reserve: &mut PoolReserve<P>, staked_sui: StakedSui) : u64 {
        let deposit_id = vault_reserve.principal_count;

        table::add(
            &mut vault_reserve.principal_staked_sui,
            deposit_id,
            staked_sui
        );

        vault_reserve.principal_count = vault_reserve.principal_count + 1;
        deposit_id
    }

    fun mint_pt<P>(vault_reserve: &mut PoolReserve<P>, amount: u64, ctx: &mut TxContext) {
        let minted_balance = balance::increase_supply(&mut vault_reserve.pt_supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), tx_context::sender(ctx));
    }

    fun withdraw_sui<P>(vault_reserve: &mut PoolReserve<P>, amount: u64, recipient: address , ctx: &mut TxContext) {
        assert!( balance::value(&vault_reserve.pending_withdrawal) >= amount, E_INVALID_AMOUNT);

        let payout_balance = balance::split(&mut vault_reserve.pending_withdrawal, amount);
        transfer::public_transfer(coin::from_balance(payout_balance, ctx), recipient);
    }

    fun increment_balances<P>(vault: &mut PoolReserve<P>, principal_amount: u64, rewards_amount: u64, debt_amount: u64) {
        vault.total_principal = vault.total_principal+principal_amount;
        vault.total_principal_rewards = vault.total_principal_rewards+rewards_amount;
        vault.total_debt = vault.total_debt+debt_amount;
    }

    fun decrement_balances<P>(vault: &mut PoolReserve<P>, principal_amount: u64, rewards_amount: u64) {
        vault.total_principal = vault.total_principal-principal_amount;
        
        let diff =
            if (rewards_amount >= vault.total_principal_rewards)
                rewards_amount-vault.total_principal_rewards
            else 0;
        
        vault.total_principal_rewards =
            if (vault.total_principal_rewards >= rewards_amount)
                vault.total_principal_rewards-rewards_amount
            else 0;
        
        vault.total_debt = 
            if (vault.total_debt >= diff)
                vault.total_debt-diff
            else 0;

    }

    fun calculate_pt_debt_from_epoch(apy: u64, from_epoch: u64, to_epoch: u64, input_amount: u64): u64 {
        let for_epoch = to_epoch-from_epoch;
        let (for_epoch, apy, input_amount) = ((for_epoch as u128), (apy as u128), (input_amount as u128));
        let result = (for_epoch*apy*input_amount) / (365_000_000_000);
        (result as u64)
    }

    #[test_only]
    public fun median_apy(wrapper: &mut SuiSystemState, vault: &PoolConfig, epoch: u64): u64 {
        let count = vector::length(&vault.staking_pools);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            let pool_id = vector::borrow(&vault.staking_pools, i);
            total_sum = total_sum+apy_reader::pool_apy(wrapper, pool_id, epoch);
            i = i + 1;
        };
        total_sum / i
    }

    #[test_only]
    public fun ceil_apy(wrapper: &mut SuiSystemState, vault: &PoolConfig, epoch: u64): u64 {
        let count = vector::length(&vault.staking_pools);
        let i = 0;
        let output = 0;
        while (i < count) {
            let pool_id = vector::borrow(&vault.staking_pools, i);
            output = math::max( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
            i = i + 1;
        };
        output
    }

    #[test_only]
    public fun floor_apy(wrapper: &mut SuiSystemState, vault: &PoolConfig, epoch: u64): u64 {
        let count = vector::length(&vault.staking_pools);
        let i = 0;
        let output = 0;
        while (i < count) {
            let pool_id = vector::borrow(&vault.staking_pools, i);
            if (output == 0)
                    output = apy_reader::pool_apy(wrapper, pool_id, epoch)
                else output = math::min( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
            i = i + 1;
        };
        output
    }

}