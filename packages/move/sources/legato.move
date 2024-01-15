// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT


module legato::legato {
 
    // use std::debug;

    use sui::math;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{ Self, Table};
    use sui::balance::{ Self, Supply , Balance };
    use sui::transfer;
    use sui::object::{ Self, UID, ID };
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::bag::{Self, Bag};
    use std::vector;
    use std::ascii::{  into_bytes};
    use std::type_name::{get, into_string};
    use std::string::{Self, String };
    use std::option::{Self};

    use sui_system::staking_pool::{  Self, StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState };

    use legato::apy_reader::{Self};
    use legato::event::{new_vault_event, update_vault_apy_event, mint_event, redeem_event, exit_event};
    use legato::legato_lib::{Self, VaultBalances };
    use legato::amm::{Self, AMMGlobal };

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
    const E_EMPTY_VECTOR: u64 = 1;
    const E_INVALID_MATURITY: u64 = 2;
    const E_DUPLICATED_ENTRY: u64 = 3;
    const E_NOT_FOUND: u64 = 4;
    const E_VAULT_MATURED: u64 = 5;
    const E_MIN_THRESHOLD: u64 = 6;
    const E_UNAUTHORIZED_USER: u64 = 7;
    const E_UNAUTHORIZED_POOL: u64 = 8;
    const E_VAULT_NOT_MATURED: u64 = 9;
    const E_INVALID_AMOUNT: u64 = 10;
    const E_INVALID_ADDRESS: u64 = 11;
    const E_FIRST_CLAIM_EPOCH: u64 = 12;
    const E_CLAIM_DISABLED: u64 = 13;
    const E_ALREADY_CLAIM: u64 = 14;
    const E_SURPLUS_ZERO: u64 = 15;
    const E_NOT_REGISTERED: u64 = 16;
    const E_INSUFFICIENT_AMOUNT: u64 = 17;

    // ======== Structs =========

    struct Global has key {
        id: UID,
        admin: vector<address>,
        treasury: address,
        vaults: Bag,
        token_supply: Supply<LEGATO>,
    }

    struct PT has drop {}
    struct YT has drop {}

    struct LEGATO has drop {}

    struct TOKEN<phantom P, phantom T> has drop {}

    struct Vault<phantom P> has store {
        global: ID,
        created_epoch: u64,
        maturity_epoch: u64,
        vault_apy: u64,
        pools: vector<ID>, // supported staking pools
        holdings: Table<u64, StakedSui>,
        deposit_count: u64,
        pending_withdrawal: Balance<SUI>,
        pt_supply: Supply<TOKEN<P, PT>>,
        yt_supply: Supply<TOKEN<P, YT>>,
        balances: VaultBalances
    }

    fun init(witness: LEGATO, ctx: &mut TxContext) {
        
        let admin_list = vector::empty<address>();
        vector::push_back<address>(&mut admin_list, tx_context::sender(ctx));

        // setup VT
        // TODO: add logo url
        let (treasury_cap, metadata) = coin::create_currency<LEGATO>(witness, 9, b"LEGATO TOKEN", b"LEGATO", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);

        let token_supply = coin::treasury_into_supply<LEGATO>(treasury_cap);

        let global = Global {
            id: object::new(ctx),
            admin: admin_list, 
            treasury: tx_context::sender(ctx),
            vaults: bag::new(ctx),
            token_supply
        };

        transfer::share_object(global)
    }

    // ======== Public Functions =========

    // convert Staked SUI to PT
    public entry fun mint<P>(wrapper: &mut SuiSystemState, global: &mut Global, staked_sui: StakedSui, ctx: &mut TxContext) {
        let global_id = object::id(global);
        let vault = get_vault<P>(global);

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
        let debt_amount = legato_lib::calculate_pt_debt_from_epoch(vault.vault_apy, tx_context::epoch(ctx), vault.maturity_epoch, principal_amount+rewards_amount);
        let minted_pt_amount = principal_amount+rewards_amount+debt_amount;

        legato_lib::increment_balances( &mut vault.balances, principal_amount, rewards_amount, debt_amount );

        // Mint PT to the user
        mint_pt(vault, minted_pt_amount, ctx);

        let earning_balance = vault_accumulated_rewards(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance) = legato_lib::get_balances(&vault.balances);

        // emit event
        mint_event(
            global_id,
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
            balance::value(&vault.pending_withdrawal)
        );

    }

    // redeem when the vault reaches its maturity date
    public entry fun redeem<P>(wrapper: &mut SuiSystemState, global: &mut Global, pt: Coin<TOKEN<P,PT>>, ctx: &mut TxContext) {
        let global_id = object::id(global);
        let vault = get_vault<P>(global);

        assert!(tx_context::epoch(ctx) > vault.maturity_epoch, E_VAULT_NOT_MATURED);
        assert!(coin::value<TOKEN<P,PT>>(&pt) >= MIN_PT_TO_REDEEM, E_MIN_THRESHOLD);

        let paidout_amount = coin::value<TOKEN<P,PT>>(&pt);

        prepare_withdrawal<P>(wrapper, vault, paidout_amount, ctx);

        // withdraw 
        withdraw_sui(vault, paidout_amount, tx_context::sender(ctx) , ctx );

        // burn PT tokens
        let burned_balance = balance::decrease_supply(&mut vault.pt_supply, coin::into_balance(pt));

        let earning_balance = vault_accumulated_rewards(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance) = legato_lib::get_balances(&vault.balances);

        redeem_event(
            global_id,
            vault_name<P>(),
            burned_balance,
            paidout_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx),
            principal_balance,
            debt_balance,
            earning_balance,
            balance::value(&vault.pending_withdrawal)
        );
    }

    
    public entry fun exit<P>(
        wrapper: &mut SuiSystemState, 
        global: &mut Global, 
        amm_global: &mut AMMGlobal,
        deposit_id: u64,
        pt: Coin<TOKEN<P,PT>>,
        yt: Coin<TOKEN<P,YT>>,
        ctx: &mut TxContext) 
    {
        let global_id = object::id(global);
        let treasury_address = global.treasury;

        let vault = get_vault<P>(global);

        assert!(vault.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!(table::contains(&vault.holdings, deposit_id), E_NOT_FOUND);

        let staked_sui = table::borrow(&vault.holdings, deposit_id);
        let asset_object_id = object::id(staked_sui);

        // PT needed calculates from the principal + accumurated rewards
        let needed_pt_amount = staking_pool::staked_sui_amount(staked_sui)+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, tx_context::epoch(ctx));

        // YT covers of the remaining debt until the vault matures at 1:10 ratio
        let pt_outstanding_debts = legato_lib::calculate_pt_debt_from_epoch(vault.vault_apy, tx_context::epoch(ctx), vault.maturity_epoch, needed_pt_amount);
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
            transfer::public_transfer(
                pt,
                tx_context::sender(ctx)
            );
        };

        // burn YT (swap for VT then burn it)
        if (input_yt_amount == needed_yt_amount) { 
            let vt = amm::swap_out_for_coin<TOKEN<P,YT>, LEGATO>(amm_global, yt, 1, false, ctx);
            transfer::public_transfer(vt, treasury_address);
        } else {
            let burned_coin = coin::split(&mut yt, input_yt_amount, ctx);
            let vt = amm::swap_out_for_coin<TOKEN<P,YT>, LEGATO>(amm_global, burned_coin, 1, false, ctx);
            transfer::public_transfer(vt, treasury_address);
            transfer::public_transfer(yt, tx_context::sender(ctx));
        };

        // send out Staked SUI
        transfer::public_transfer(
            table::remove(&mut vault.holdings, deposit_id),
            tx_context::sender(ctx)
        );

        legato_lib::decrement_balances(&mut vault.balances, needed_pt_amount, pt_outstanding_debts);

        let earning_balance = vault_accumulated_rewards(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance) = legato_lib::get_balances(&vault.balances);

        exit_event(
            global_id,
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
            balance::value(&vault.pending_withdrawal)
        );

    }

    public fun get_vault<P>(global: &mut Global): &mut Vault<P> {
        let vault_name = vault_name<P>();
        let has_registered = bag::contains_with_type<String, Vault<P>>(&global.vaults, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        bag::borrow_mut<String, Vault<P>>(&mut global.vaults, vault_name)
    }

    public fun vault_name<P>(): String {
        let vault_name = string::utf8(b"");
        string::append_utf8(&mut vault_name, b"VAULT-");
        string::append_utf8(&mut vault_name, into_bytes(into_string(get<P>())));
        vault_name
    }

    // ======== Only Governance =========

    // create new vault
    public entry fun new_vault<P>(global: &mut Global, amm_global: &mut AMMGlobal, initial_apy: u64, maturity_epoch: u64, initial_liquidity: Coin<LEGATO>, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        assert!( maturity_epoch > tx_context::epoch(ctx) , E_INVALID_MATURITY);

        let vault_name = vault_name<P>();    
        let has_registered = bag::contains_with_type<String, Vault<P>>(&global.vaults, vault_name);
        assert!(!has_registered, E_DUPLICATED_ENTRY);

        // setup PT
        let pt_supply = balance::create_supply(TOKEN<P,PT> {});
        // setup YT
        let yt_supply = balance::create_supply(TOKEN<P,YT> {});
        let minted_yt = balance::increase_supply(&mut yt_supply, YT_TOTAL_SUPPLY);

        // setup AMM
        let is_order = true;
        amm::register_pool<LEGATO, TOKEN<P,YT>>(amm_global, is_order);
        let pool = amm::get_mut_pool<LEGATO, TOKEN<P,YT>>(amm_global, is_order);

        let (lp, _) = amm::add_liquidity<LEGATO, TOKEN<P,YT>>(
            pool,
            initial_liquidity,
            1,
            coin::from_balance(minted_yt, ctx),
            1,
            is_order,
            ctx
        );

        transfer::public_transfer( lp , tx_context::sender(ctx));

        bag::add(&mut global.vaults, vault_name, Vault {
            global: object::uid_to_inner(&global.id),
            created_epoch: tx_context::epoch(ctx),
            maturity_epoch,
            vault_apy: initial_apy,
            pools : vector::empty<ID>(),
            holdings: table::new(ctx),
            deposit_count: 0,
            pending_withdrawal: balance::zero(),
            pt_supply,
            yt_supply,
            balances: legato_lib::empty_balances()
        });

        // emit event
        new_vault_event(
            object::id(global),
            vault_name,
            tx_context::epoch(ctx),
            maturity_epoch,
            initial_apy
        )

    }

    // add new admin
    public entry fun add_admin(global: &mut Global, user: address, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        assert!(!vector::contains(&global.admin, &user),E_DUPLICATED_ENTRY);
        vector::push_back<address>(&mut global.admin, user);
    }

    // remove admin
    public entry fun remove_admin(global: &mut Global, user: address, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let (contained, index) = vector::index_of<address>(&global.admin, &user);
        assert!(contained,E_NOT_FOUND);
        vector::remove<address>(&mut global.admin, index);
    }

    // add pool
    public entry fun add_pool<P>(global: &mut Global, pool_id: ID, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let vault = get_vault<P>(global);
        assert!(!vector::contains(&vault.pools, &pool_id), E_DUPLICATED_ENTRY);
        vector::push_back<ID>(&mut vault.pools, pool_id);
    }

    // remove pool
    public entry fun remove_pool<P>(global: &mut Global, pool_id: ID, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let vault = get_vault<P>(global);
        let (contained, index) = vector::index_of<ID>(&vault.pools, &pool_id);
        assert!(contained, E_NOT_FOUND);
        vector::remove<ID>(&mut vault.pools, index);
    }

    // update vault APY
    public entry fun update_vault_apy<P>(wrapper: &mut SuiSystemState, global: &mut Global, value: u64, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let id = object::id(global);
        let vault = get_vault<P>(global);
        vault.vault_apy = value;

        let earning = vault_accumulated_rewards(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance) = legato_lib::get_balances(&vault.balances);

        // emit event
        update_vault_apy_event(
            id,
            vault_name<P>(),
            value,
            tx_context::epoch(ctx),
            principal_balance,
            debt_balance,
            balance::value(&vault.pending_withdrawal),
            earning
        )
    }

    // top-up pending pool
    public entry fun emergency_topup<P>(global: &mut Global, sui: Coin<SUI>, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let vault = get_vault<P>(global);
        let balance = coin::into_balance(sui);
        balance::join<SUI>(&mut vault.pending_withdrawal, balance);
    }

    // TODO: implement logic to control supply of VT

    public entry fun mint_vt(global: &mut Global, amount: u64, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let minted_balance = balance::increase_supply(&mut global.token_supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), tx_context::sender(ctx));
    }

    public entry fun burn_vt(global: &mut Global, vt: Coin<LEGATO>, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let _ = balance::decrease_supply(&mut global.token_supply, coin::into_balance(vt));
    }

    // ======== Internal Functions =========

    fun check_admin(global: &Global, sender: address) {
        let (contained, _) = vector::index_of<address>(&global.admin, &sender);
        assert!(contained,E_UNAUTHORIZED_USER);
    }

    fun vault_accumulated_rewards<P>(wrapper: &mut SuiSystemState, vault: &Vault<P>, epoch: u64): u64 {
        let count = table::length(&vault.holdings);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            if (table::contains(&vault.holdings, i)) {
                let staked_sui = table::borrow(&vault.holdings, i);
                let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);
                if (epoch > activation_epoch) total_sum = total_sum+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);
            };
            i = i + 1;
        };
        total_sum
    }

    fun receive_staked_sui<P>(vault: &mut Vault<P>, staked_sui: StakedSui) : u64 {
        let deposit_id = vault.deposit_count;

        table::add(
            &mut vault.holdings,
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
            if (table::contains(&vault.holdings, count)) {
                let staked_sui = table::borrow(&vault.holdings, count);
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
            let staked_sui = table::remove(&mut vault.holdings, asset_id);

            let principal_amount = staking_pool::staked_sui_amount(&staked_sui);
            let balance_each = sui_system::request_withdraw_stake_non_entry(wrapper, staked_sui, ctx);

            let reward_amount =
                if (balance::value(&balance_each) >= principal_amount)
                    balance::value(&balance_each) - principal_amount
                else 0;

            balance::join<SUI>(&mut balance_sui, balance_each);

            legato_lib::decrement_balances(&mut vault.balances, principal_amount, reward_amount);
        };

        balance_sui
    }

    fun withdraw_sui<P>(vault: &mut Vault<P>, amount: u64, recipient: address , ctx: &mut TxContext) {
        assert!( balance::value(&vault.pending_withdrawal) >= amount, E_INVALID_AMOUNT);

        let payout_balance = balance::split(&mut vault.pending_withdrawal, amount);
        transfer::public_transfer(coin::from_balance(payout_balance, ctx), recipient);
    }

    // ======== Test-related Functions =========

    #[test_only]
    public fun median_apy<P>(wrapper: &mut SuiSystemState, global: &mut Global, epoch: u64): u64 {
        let vault = get_vault<P>(global);

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
    public fun ceil_apy<P>(wrapper: &mut SuiSystemState, global: &mut Global, epoch: u64): u64 {
        let vault = get_vault<P>(global);
        
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
    public fun floor_apy<P>(wrapper: &mut SuiSystemState, global: &mut Global, epoch: u64): u64 {
        let vault = get_vault<P>(global);
        
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

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init( LEGATO {} ,ctx);
    }

}