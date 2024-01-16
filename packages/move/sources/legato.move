// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::legato {

    use sui::object::{ Self, UID, ID  };
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::balance::{ Self, Supply  };
    use sui::coin::{Self, Coin };
    use sui::bag::{Self, Bag};
    use sui::sui::SUI; 
    use std::option::{Self};
    use std::vector;
    use std::string::{ String };

    use sui_system::staking_pool::{  StakedSui};
    use sui_system::sui_system::{  SuiSystemState };

    use legato::vault::{Self, Vault, TOKEN, YT, PT};
    use legato::amm::{Self, AMMGlobal};
    use legato::event::{new_vault_event, update_vault_apy_event};

    // ======== Constants ========

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

    struct LEGATO has drop {}

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
        let vault = vault::get_mut_vault<P>(&mut global.vaults);
        vault::perform_mint<P>(wrapper, vault, staked_sui, ctx);
    }
    
    // redeem when the vault reaches its maturity date
    public entry fun redeem<P>(wrapper: &mut SuiSystemState,  global: &mut Global, pt: Coin<TOKEN<P,PT>>, ctx: &mut TxContext) {
        let vault = vault::get_mut_vault<P>(&mut global.vaults);
        vault::perform_redeem<P>(wrapper, vault, pt, ctx);
    }

    // exit the position before to the vault matures
    public entry fun exit<P>(wrapper: &mut SuiSystemState,  global: &mut Global, amm_global: &mut AMMGlobal, deposit_id: u64, pt: Coin<TOKEN<P,PT>>,yt: Coin<TOKEN<P,YT>>, ctx: &mut TxContext) {
        let treasury_address = global.treasury;
        let vault = vault::get_mut_vault<P>(&mut global.vaults);

        let (input_yt_amount, needed_yt_amount, returned_yt) = vault::perform_exit<P>(wrapper, vault, deposit_id, pt, yt, ctx);

        // burn YT (swap for VT then burn it)
        if (input_yt_amount == needed_yt_amount) { 
            let vt = amm::swap_out_for_coin<TOKEN<P,YT>, LEGATO>(amm_global, returned_yt, 1, false, ctx);
            transfer::public_transfer(vt, treasury_address);
        } else {
            let burned_coin = coin::split(&mut returned_yt, input_yt_amount, ctx);
            let vt = amm::swap_out_for_coin<TOKEN<P,YT>, LEGATO>(amm_global, burned_coin, 1, false, ctx);
            transfer::public_transfer(vt, treasury_address);
            transfer::public_transfer(returned_yt, tx_context::sender(ctx));
        };
    }

    // ======== Only Governance =========

    public entry fun new_vault<P>(global: &mut Global, amm_global: &mut AMMGlobal, initial_apy: u64, maturity_epoch: u64, initial_liquidity: Coin<LEGATO>, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        assert!( maturity_epoch > tx_context::epoch(ctx) , E_INVALID_MATURITY);

        let vault_name = vault::vault_name<P>();    
        let has_registered = bag::contains_with_type<String, Vault<P>>(&global.vaults, vault_name);
        assert!(!has_registered, E_DUPLICATED_ENTRY);

        // prepare new vault
        let (vault, minted_yt) = vault::get_new_vault<P>( object::id(global), initial_apy, maturity_epoch, ctx );

        // setup AMM for YT
        let is_order = true;
        amm::register_pool<LEGATO, TOKEN<P,YT>>(amm_global, is_order);
        let pool = amm::get_mut_pool<LEGATO, TOKEN<P,YT>>(amm_global, is_order);

        let (lp, _) = amm::add_liquidity<LEGATO, TOKEN<P,YT>>( pool, initial_liquidity, 1, coin::from_balance(minted_yt, ctx), 1, is_order, ctx);

        transfer::public_transfer( lp , global.treasury);

        bag::add(&mut global.vaults, vault_name, vault);

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
    public entry fun add_vault_pool<P>(global: &mut Global, pool_id: ID, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let vault = vault::get_mut_vault<P>(&mut global.vaults);
        vault::add_pool<P>(vault, pool_id);
    }

    // remove pool
    public entry fun remove_vault_pool<P>(global: &mut Global, pool_id: ID, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let vault = vault::get_mut_vault<P>(&mut global.vaults);
        vault::remove_pool<P>(vault, pool_id);
    }

    // top-up pending pool
    public entry fun emergency_vault_topup<P>(global: &mut Global, sui: Coin<SUI>, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let vault = vault::get_mut_vault<P>(&mut global.vaults);
        vault::emergency_topup<P>(vault, sui);
    }

    // update vault config
    public entry fun update_vault_config<P>(global: &mut Global, enable_exit: bool, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let vault = vault::get_mut_vault<P>(&mut global.vaults);
        vault::update_config<P>(vault, enable_exit);
    }

    // update vault APY
    public entry fun update_vault_apy<P>(wrapper: &mut SuiSystemState, global: &mut Global, value: u64, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let id = object::id(global);
        let vault = vault::get_mut_vault<P>(&mut global.vaults);
        vault::update_apy(vault, value);

        let earning = vault::vault_accumulated_rewards(wrapper, vault, tx_context::epoch(ctx));
        let (principal_balance, _, debt_balance, pending_withdrawal) = vault::get_balances<P>(vault);

        // emit event
        update_vault_apy_event(
            id,
            vault::vault_name<P>(),
            value,
            tx_context::epoch(ctx),
            principal_balance,
            debt_balance,
            pending_withdrawal,
            earning
        )
    }

    // TODO: implement logic to control supply of VT

    public entry fun emergency_mint_vt(global: &mut Global, amount: u64, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let minted_balance = balance::increase_supply(&mut global.token_supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), tx_context::sender(ctx));
    }

    public entry fun emergency_burn_vt(global: &mut Global, vt: Coin<LEGATO>, ctx: &mut TxContext) {
        check_admin(global, tx_context::sender(ctx));
        let _ = balance::decrease_supply(&mut global.token_supply, coin::into_balance(vt));
    }

    // ======== Internal Functions =========

    public(friend) fun check_admin(global: &Global, sender: address) {
        let (contained, _) = vector::index_of<address>(&global.admin, &sender);
        assert!(contained,E_UNAUTHORIZED_USER);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init( LEGATO {} ,ctx);
    }

}