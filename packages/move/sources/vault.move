// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::vault {

    use sui::math;
    use sui::table::{ Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::object::{ Self,  ID, UID };
    use sui::balance::{ Self, Supply , Balance };
    use sui::sui::SUI;
    use std::vector;
    use sui::transfer;
    use sui::coin::{Self, Coin };
    use std::ascii::{  into_bytes};
    use std::type_name::{get, into_string};
    use std::string::{Self, String };
    use sui::bag::{Self, Bag};
    
    use sui_system::staking_pool::{  Self, StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState };

    use legato::apy_reader::{Self}; 
    use legato::event::{ mint_event, redeem_event, exit_event};

    friend legato::legato;

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

    // ======== Structs =========

    struct PT has drop {}
    struct YT has drop {}

    struct TOKEN<phantom P, phantom T> has drop {}

    struct Vault<phantom P> has key, store {
        id: UID,
        global: ID,
        created_epoch: u64, // TODO: started epoch
        maturity_epoch: u64,
        vault_apy: u64,
        pools: vector<ID>, // supported staking pools
        deposit_items: Table<u64, StakedSui>,
        deposit_count: u64,
        pending_withdrawal: Balance<SUI>,
        pt_supply: Supply<TOKEN<P, PT>>,
        yt_supply: Supply<TOKEN<P, YT>>,
        principal: u64,
        principal_rewards: u64, // accumulated rewards at the time of conversion
        debt: u64,
        enable_exit: bool
    }

    // ======== Public Functions =========

    // convert Staked SUI to PT
    public fun perform_mint<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, staked_sui: StakedSui, ctx: &mut TxContext) {
        assert!(vault.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!(staking_pool::staked_sui_amount(&staked_sui) >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);

        let pool_id = staking_pool::pool_id(&staked_sui);
        assert!(vector::contains(&vault.pools, &pool_id), E_UNAUTHORIZED_POOL);

        let asset_object_id = object::id(&staked_sui);

        // Take the Staked SUI
        let principal_amount = staking_pool::staked_sui_amount(&staked_sui);
        let rewards_amount = 
            if (tx_context::epoch(ctx) > staking_pool::stake_activation_epoch(&staked_sui))
                apy_reader::earnings_from_staked_sui(wrapper, &staked_sui, tx_context::epoch(ctx))
            else 0;

        let deposit_id = receive_staked_sui(vault, staked_sui);

        // Calculate PT to send out
        let debt_amount = calculate_pt_debt_from_epoch(vault.vault_apy, tx_context::epoch(ctx), vault.maturity_epoch, principal_amount+rewards_amount);
        let minted_pt_amount = principal_amount+rewards_amount+debt_amount;

        increment_balances( vault, principal_amount, rewards_amount, debt_amount );

        // Mint PT to the user
        mint_pt(vault, minted_pt_amount, ctx);

        let earning_balance = vault_accumulated_rewards(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance, pending_withdrawal) = get_balances(vault);

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

    // redeem when the vault reaches its maturity date
    public fun perform_redeem<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, pt: Coin<TOKEN<P,PT>>, ctx: &mut TxContext) {
        assert!(tx_context::epoch(ctx) > vault.maturity_epoch, E_VAULT_NOT_MATURED);
        assert!(coin::value<TOKEN<P,PT>>(&pt) >= MIN_PT_TO_REDEEM, E_MIN_THRESHOLD);

        let paidout_amount = coin::value<TOKEN<P,PT>>(&pt);

        prepare_withdrawal<P>(wrapper, vault, paidout_amount, ctx);

        // withdraw 
        withdraw_sui(vault, paidout_amount, tx_context::sender(ctx) , ctx );

        // burn PT tokens
        let burned_balance = balance::decrease_supply(&mut vault.pt_supply, coin::into_balance(pt));

        let earning_balance = vault_accumulated_rewards<P>(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance, pending_withdrawal) = get_balances<P>(vault);

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

    public(friend) fun perform_exit<P>(
        wrapper: &mut SuiSystemState, 
        vault: &mut Vault<P>,  
        deposit_id: u64,
        pt: Coin<TOKEN<P,PT>>,
        yt: Coin<TOKEN<P,YT>>,
        ctx: &mut TxContext 
    ) : (u64, u64, Coin<TOKEN<P,YT>>) {
        assert!(vault.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!(table::contains(&vault.deposit_items, deposit_id), E_NOT_FOUND);
        assert!(vault.enable_exit == true, E_EXIT_DISABLED);

        let staked_sui = table::borrow(&vault.deposit_items, deposit_id);
        let asset_object_id = object::id(staked_sui);

        // PT needed calculates from the principal + accumurated rewards
        let needed_pt_amount = staking_pool::staked_sui_amount(staked_sui)+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, tx_context::epoch(ctx));

        // YT covers of the remaining debt until the vault matures at 1:10 ratio
        let pt_outstanding_debts = calculate_pt_debt_from_epoch(vault.vault_apy, tx_context::epoch(ctx), vault.maturity_epoch, needed_pt_amount);
        let needed_yt_amount = 10 * pt_outstanding_debts;

        if (MIN_YT_FOR_EXIT > needed_yt_amount) needed_yt_amount = MIN_YT_FOR_EXIT;

        let input_pt_amount = coin::value<TOKEN<P,PT>>(&pt);
        let input_yt_amount = coin::value<TOKEN<P,YT>>(&yt);
        
        assert!( input_pt_amount >= needed_pt_amount , E_INSUFFICIENT_AMOUNT);
        assert!( input_yt_amount >= needed_yt_amount , E_INSUFFICIENT_AMOUNT);

        // burn PT
        if (input_pt_amount == needed_pt_amount) {
            balance::decrease_supply(&mut vault.pt_supply, coin::into_balance(pt));
        } else {
            let burned_coin = coin::split(&mut pt, input_pt_amount, ctx);
            balance::decrease_supply(&mut vault.pt_supply, coin::into_balance(burned_coin));
            transfer::public_transfer(pt, tx_context::sender(ctx));
        };

        // // burn YT (swap for VT then burn it)
        // if (input_yt_amount == needed_yt_amount) { 
        //     let vt = amm::swap_out_for_coin<TOKEN<P,YT>, LEGATO>(amm_global, yt, 1, false, ctx);
        //     transfer::public_transfer(vt, treasury_address);
        // } else {
        //     let burned_coin = coin::split(&mut yt, input_yt_amount, ctx);
        //     let vt = amm::swap_out_for_coin<TOKEN<P,YT>, LEGATO>(amm_global, burned_coin, 1, false, ctx);
        //     transfer::public_transfer(vt, treasury_address);
        //     transfer::public_transfer(yt, tx_context::sender(ctx));
        // };

        // send out Staked SUI
        transfer::public_transfer( table::remove(&mut vault.deposit_items, deposit_id), tx_context::sender(ctx) );

        decrement_balances(vault, needed_pt_amount, pt_outstanding_debts);

        let earning_balance = vault_accumulated_rewards(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance, pending_withdrawal) = get_balances(vault);

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

    // create new vault
    public(friend) fun get_new_vault<P>(global_id: ID, initial_apy: u64, maturity_epoch: u64, ctx: &mut TxContext) : (Vault<P>, Balance<TOKEN<P,YT>>) {

        // setup PT
        let pt_supply = balance::create_supply(TOKEN<P,PT> {});
        // setup YT
        let yt_supply = balance::create_supply(TOKEN<P,YT> {});
        let minted_yt = balance::increase_supply(&mut yt_supply, YT_TOTAL_SUPPLY);
        
        (Vault {
            id: object::new(ctx),
            global: global_id ,
            created_epoch: tx_context::epoch(ctx),
            maturity_epoch,
            vault_apy: initial_apy,
            pools : vector::empty<ID>(),
            deposit_items: table::new(ctx),
            deposit_count: 0,
            pending_withdrawal: balance::zero(),
            pt_supply,
            yt_supply,
            principal: 0,
            principal_rewards: 0,
            debt: 0,
            enable_exit : false
        }, minted_yt)
    }

    // add pool
    public(friend) fun add_pool<P>(vault: &mut Vault<P>, pool_id: ID) {
        assert!(!vector::contains(&vault.pools, &pool_id), E_DUPLICATED_ENTRY);
        vector::push_back<ID>(&mut vault.pools, pool_id);
    }

    // remove pool
    public(friend) fun remove_pool<P>(vault: &mut Vault<P>, pool_id: ID) {
        let (contained, index) = vector::index_of<ID>(&vault.pools, &pool_id);
        assert!(contained, E_NOT_FOUND);
        vector::remove<ID>(&mut vault.pools, index);
    }

    // topup
    public(friend) fun emergency_topup<P>(vault: &mut Vault<P>, sui: Coin<SUI>) {
        let balance = coin::into_balance(sui);
        balance::join<SUI>(&mut vault.pending_withdrawal, balance);
    }

    public(friend) fun update_config<P>(vault: &mut Vault<P>, enable_exit: bool) {
        vault.enable_exit = enable_exit;
    }

    public(friend) fun update_apy<P>(vault: &mut Vault<P>, value: u64) {
        vault.vault_apy = value;
    }

    public fun vault_name<P>(): String {
        let vault_name = string::utf8(b"");
        string::append_utf8(&mut vault_name, b"VAULT-");
        string::append_utf8(&mut vault_name, into_bytes(into_string(get<P>())));
        vault_name
    }

    public fun get_mut_vault<P>(vaults: &mut Bag): &mut Vault<P> {
        let vault_name = vault_name<P>();
        let has_registered = bag::contains_with_type<String, Vault<P>>(vaults, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        bag::borrow_mut<String, Vault<P>>(vaults, vault_name)
    }

    public fun vault_accumulated_rewards<P>(wrapper: &mut SuiSystemState, vault: &Vault<P>, epoch: u64): u64 {
        let count = table::length(&vault.deposit_items);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            if (table::contains(&vault.deposit_items, i)) {
                let staked_sui = table::borrow(&vault.deposit_items, i);
                let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);
                if (epoch > activation_epoch) total_sum = total_sum+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);
            };
            i = i + 1;
        };
        total_sum
    }

    public fun get_balances<P>(vault: &Vault<P>) : (u64, u64, u64, u64) {
        (vault.principal, vault.principal_rewards, vault.debt, balance::value(&vault.pending_withdrawal))
    }

    // ======== Internal Functions =========


    fun receive_staked_sui<P>(vault: &mut Vault<P>, staked_sui: StakedSui) : u64 {
        let deposit_id = vault.deposit_count;

        table::add(
            &mut vault.deposit_items,
            deposit_id,
            staked_sui
        );

        vault.deposit_count = vault.deposit_count + 1;
        deposit_id
    }

    fun mint_pt<P>(vault: &mut Vault<P>, amount: u64, ctx: &mut TxContext) {
        let minted_balance = balance::increase_supply(&mut vault.pt_supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), tx_context::sender(ctx));
    }

    // initiates the withdrawal by performing the unstaking of locked Staked SUI objects and keeping SUI tokens for redemption one by one at a time
    fun prepare_withdrawal<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, paidout_amount: u64, ctx: &mut TxContext) {
        
        // ignore if there are sufficient SUI to pay out 
        if (paidout_amount > balance::value(&vault.pending_withdrawal)) {
             // extract all asset IDs to be withdrawn
            let asset_ids = locate_withdrawable_asset(wrapper, vault, paidout_amount, tx_context::epoch(ctx));

            // unstake assets
            let sui_balance = unstake_staked_sui(wrapper, vault, asset_ids, ctx);
            balance::join<SUI>(&mut vault.pending_withdrawal, sui_balance);
            
        };
    }

    fun locate_withdrawable_asset<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, paidout_amount: u64, epoch: u64):  vector<u64> {

        let count = 0;
        let asset_ids = vector::empty();
        let amount_to_unwrap = paidout_amount-balance::value(&vault.pending_withdrawal);

        while (amount_to_unwrap > 0) {
            if (table::contains(&vault.deposit_items, count)) {
                let staked_sui = table::borrow(&vault.deposit_items, count);
                let amount_with_rewards = staking_pool::staked_sui_amount(staked_sui)+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);

                vector::push_back<u64>(&mut asset_ids, count);

                amount_to_unwrap =
                    if (paidout_amount >= amount_with_rewards)
                        paidout_amount - amount_with_rewards
                    else 0;
            };

            count = count + 1;

            if (count == vault.deposit_count) amount_to_unwrap = 0
            
        };

        asset_ids
    }

    fun unstake_staked_sui<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, asset_ids: vector<u64>, ctx: &mut TxContext) : Balance<SUI> {

        let balance_sui = balance::zero();

        while (vector::length<u64>(&asset_ids) > 0) {
            let asset_id = vector::pop_back(&mut asset_ids);
            let staked_sui = table::remove(&mut vault.deposit_items, asset_id);

            let principal_amount = staking_pool::staked_sui_amount(&staked_sui);
            let balance_each = sui_system::request_withdraw_stake_non_entry(wrapper, staked_sui, ctx);

            let reward_amount =
                if (balance::value(&balance_each) >= principal_amount)
                    balance::value(&balance_each) - principal_amount
                else 0;

            balance::join<SUI>(&mut balance_sui, balance_each);

            decrement_balances(vault, principal_amount, reward_amount);
        };

        balance_sui
    }

    fun withdraw_sui<P>(vault: &mut Vault<P>, amount: u64, recipient: address , ctx: &mut TxContext) {
        assert!( balance::value(&vault.pending_withdrawal) >= amount, E_INVALID_AMOUNT);

        let payout_balance = balance::split(&mut vault.pending_withdrawal, amount);
        transfer::public_transfer(coin::from_balance(payout_balance, ctx), recipient);
    }

    fun increment_balances<P>(vault: &mut Vault<P>, principal_amount: u64, rewards_amount: u64, debt_amount: u64) {
        vault.principal = vault.principal+principal_amount;
        vault.principal_rewards = vault.principal_rewards+rewards_amount;
        vault.debt = vault.debt+debt_amount;
    }

    fun decrement_balances<P>(vault: &mut Vault<P>, principal_amount: u64, rewards_amount: u64) {
        vault.principal = vault.principal-principal_amount;
        
        let diff =
            if (rewards_amount >= vault.principal_rewards)
                rewards_amount-vault.principal_rewards
            else 0;
        
        vault.principal_rewards =
            if (vault.principal_rewards >= rewards_amount)
                vault.principal_rewards-rewards_amount
            else 0;
        
        vault.debt = 
            if (vault.debt >= diff)
                vault.debt-diff
            else 0;

    }

    fun calculate_pt_debt_from_epoch(apy: u64, from_epoch: u64, to_epoch: u64, input_amount: u64): u64 {
        let for_epoch = to_epoch-from_epoch;
        let (for_epoch, apy, input_amount) = ((for_epoch as u128), (apy as u128), (input_amount as u128));
        let result = (for_epoch*apy*input_amount) / (365_000_000_000);
        (result as u64)
    }

    // ======== Test-related Functions =========

    #[test_only]
    public fun median_apy<P>(wrapper: &mut SuiSystemState, vault: &Vault<P>, epoch: u64): u64 {
        let count = vector::length(&vault.pools);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            let pool_id = vector::borrow(&vault.pools, i);
            total_sum = total_sum+apy_reader::pool_apy(wrapper, pool_id, epoch);
            i = i + 1;
        };
        total_sum / i
    }

    #[test_only]
    public fun ceil_apy<P>(wrapper: &mut SuiSystemState, vault: &Vault<P>, epoch: u64): u64 {
        let count = vector::length(&vault.pools);
        let i = 0;
        let output = 0;
        while (i < count) {
            let pool_id = vector::borrow(&vault.pools, i);
            output = math::max( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
            i = i + 1;
        };
        output
    }

    #[test_only]
    public fun floor_apy<P>(wrapper: &mut SuiSystemState, vault: &Vault<P>, epoch: u64): u64 {

        let count = vector::length(&vault.pools);
        let i = 0;
        let output = 0;
        while (i < count) {
            let pool_id = vector::borrow(&vault.pools, i);
            if (output == 0)
                    output = apy_reader::pool_apy(wrapper, pool_id, epoch)
                else output = math::min( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
            i = i + 1;
        };
        output
    }

}