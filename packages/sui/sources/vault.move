// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::vault {

    // use std::debug;

    use sui::math;
    use sui::object::{ Self, ID, UID }; 
    use sui::balance::{  Self, Supply, Balance};
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI; 
    use sui::transfer;
    use sui::bag::{Self,  Bag};
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self};

    use std::option::{Self, Option};
    use std::string::{  String }; 
    use std::vector;

    use sui_system::staking_pool::{ Self, StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState };

    use legato::vault_lib::{token_to_name, calculate_pt_debt_from_epoch, sort_items};
    use legato::event::{new_vault_event, mint_event, redeem_event, rebalance_event, exit_event};
    use legato::apy_reader::{Self};
    use legato::amm::{ Self, AMMGlobal };
    
    use legato::math::{mul_div}; 
    

    // ======== Constants ========
    const MIN_VAULT_SPAN: u64 = 30; // each vault's start epoch and maturity should last at least 30 epochs
    const COOLDOWN_EPOCH: u64 = 3;
    const MIN_SUI_TO_STAKE : u64 = 1_000_000_000; // 1 Sui
    const U64_MAX: u64 = 18446744073709551615;
    const MIN_PT_TO_REDEEM: u64 = 1_000_000_000; // 1 PT
    const MIN_PT_REBALANCE: u64 = 1_000;
    const MIN_YT_FOR_EXIT: u64 = 1_000_000; // 0.001 YT


    // ======== Errors ========
    const E_DUPLICATED_ENTRY: u64 = 1;
    const E_NOT_FOUND: u64 = 2;
    const E_INVALID_STARTED: u64 = 3;
    const E_TOO_SHORT: u64 = 4;
    const E_INVALID_MATURITY: u64 = 5;
    const E_PAUSED_STATE: u64 = 6;
    const E_NOT_ENABLED: u64 = 7;
    const E_VAULT_MATURED: u64 = 8;
    const E_VAULT_NOT_STARTED: u64 = 9;
    const E_MIN_THRESHOLD: u64 = 10;
    const E_NOT_REGISTERED: u64 = 11;
    const E_UNAUTHORIZED_POOL: u64 = 12;
    const E_VAULT_NOT_ORDER: u64 = 13;
    const E_VAULT_NOT_MATURED: u64 = 14;
    const E_INVALID_AMOUNT: u64 = 15;
    const E_EXIT_DISABLED: u64 = 16;
    const E_INVALID_DEPOSIT_ID: u64 = 17;
    const E_INSUFFICIENT_AMOUNT: u64 = 18;
    const E_CLAIM_DISABLED: u64 = 19;
    const E_SURPLUS_ZERO: u64 = 20;
    const E_DEPOSIT_CAP: u64 = 21;
    const E_YT_SUPPLY_NOT_EMPTY: u64 = 22;
    const E_ONLY_LIQUIDITY_ALLOWED: u64 = 23;
    const E_INVALID_LIQUIDITY: u64 = 24;
    const E_TOO_LOW: u64 = 25;
    const E_RATE_NOT_SET: u64 = 26;

    // ======== Structs =========

    // represent the future value at maturity date
    struct PT_TOKEN<phantom P> has drop {}

    // vault tokens for delta-hedging staking yield across vaults
    struct VAULT has drop {}

    // a fixed-term pool taking Staked SUI objects for fungible PT
    struct PoolConfig has store {
        started_epoch: u64,
        maturity_epoch: u64,
        vault_apy: u64,
        deposit_items: vector<StakedSui>,
        debt_balance: u64,
        exit_conversion_rate: Option<u64>, // rates for USDC/PT for the exit
        enable_mint: bool,
        enable_exit: bool,
        enable_redeem: bool
    }

    struct PoolReserve<phantom P> has store {
        pt_supply: Supply<PT_TOKEN<P>>,
        pending_burn: Balance<PT_TOKEN<P>>
    }

    struct Global has key {
        id: UID,
        staking_pools: vector<address>, // supported staking pools
        staking_pool_ids: vector<ID>, // supported staking pools in ID
        pool_list: vector<String>,
        pools: Table<String, PoolConfig>,
        pool_reserves: Bag,
        yt_supply: Supply<VAULT>,
        yt_in_circulation: Table<String, u64>,
        pending_withdrawal: Balance<SUI>, // where the redemption process takes place
        deposit_cap: Option<u64> // deposit no more than a certain amount
    }

    // using ManagerCap for admin permission
    struct ManagerCap has key {
        id: UID
    }

    fun init(witness: VAULT, ctx: &mut TxContext) {
        
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        // setup YT token
        let (treasury_cap, metadata) = coin::create_currency<VAULT>(witness, 9, b"Legato Yield Token", b"YT", b"", option::some(url::new_unsafe_from_bytes(b"https://img.tamago.finance/legato/legato-icon.png")), ctx);
        transfer::public_freeze_object(metadata);

        transfer::share_object(Global {
            id: object::new(ctx),
            staking_pools: vector::empty<address>(),
            staking_pool_ids: vector::empty<ID>(),
            pool_list: vector::empty<String>(),
            pools: table::new(ctx),
            pool_reserves: bag::new(ctx),
            deposit_cap: option::none<u64>(),
            yt_supply: coin::treasury_into_supply<VAULT>(treasury_cap),
            yt_in_circulation: table::new<String, u64>(ctx),
            pending_withdrawal: balance::zero()
        })

    }


    // ======== Public Functions =========


    // Convert SUI to Staked SUI and then PT on the given vault
    public entry fun mint_from_sui<P>(wrapper: &mut SuiSystemState, global: &mut Global, sui: Coin<SUI>, validator_address: address, ctx: &mut TxContext) {
        assert!(coin::value(&sui) >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);
        let staked_sui = sui_system::request_add_stake_non_entry(wrapper, sui, validator_address, ctx);
        mint<P>(wrapper, global, staked_sui , ctx);
    }

    // Convert Staked SUI to PT on the given vault
    public entry fun mint<P>(wrapper: &mut SuiSystemState, global: &mut Global, staked_sui: StakedSui, ctx: &mut TxContext) {
        check_not_paused(global, tx_context::epoch(ctx));

        let vault_config = get_vault_config<P>(&mut global.pools);
        let vault_reserve = get_vault_reserve<P>(&mut global.pool_reserves);

        assert!(vault_config.enable_mint == true, E_NOT_ENABLED);
        assert!(vault_config.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!(tx_context::epoch(ctx) >= vault_config.started_epoch, E_VAULT_NOT_STARTED);
        assert!(staking_pool::staked_sui_amount(&staked_sui) >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);

        // Checking Staked SUI staked on valid staking pools
        let pool_id = staking_pool::pool_id(&staked_sui);
        assert!(vector::contains(&global.staking_pool_ids, &pool_id), E_UNAUTHORIZED_POOL);
    
        let asset_object_id = object::id(&staked_sui);

        // Take the Staked SUI
        let principal_amount = staking_pool::staked_sui_amount(&staked_sui);
        if (option::is_some(&global.deposit_cap)) {
            assert!( *option::borrow(&global.deposit_cap) >= principal_amount, E_DEPOSIT_CAP);
            *option::borrow_mut(&mut global.deposit_cap) = *option::borrow(&global.deposit_cap)-principal_amount;
        };

        // Calculate earnings at the maturity date
        let total_earnings = 
            if (tx_context::epoch(ctx) > staking_pool::stake_activation_epoch(&staked_sui))
                apy_reader::earnings_from_staked_sui(wrapper, &staked_sui, tx_context::epoch(ctx))
            else 0;

        receive_staked_sui(vault_config, staked_sui);
    
        // Calculate PT to send out
        let debt_amount = calculate_pt_debt_from_epoch(vault_config.vault_apy, tx_context::epoch(ctx), vault_config.maturity_epoch, principal_amount+total_earnings);
        let minted_pt_amount = principal_amount+total_earnings+debt_amount;
        
        // Mint PT to the user
        mint_pt<P>(vault_reserve, minted_pt_amount, ctx);

        vault_config.debt_balance = vault_config.debt_balance+debt_amount;

        // emit event
        mint_event(
            token_to_name<P>(),
            pool_id,
            principal_amount,
            minted_pt_amount, 
            asset_object_id,
            tx_context::sender(ctx),
            tx_context::epoch(ctx)
        );
    }

    // redeem when the vault reaches its maturity date
    public entry fun redeem<P>(wrapper: &mut SuiSystemState, global: &mut Global, pt: Coin<PT_TOKEN<P>>, ctx: &mut TxContext) {
        let vault_config = get_vault_config<P>(&mut global.pools);
        assert!(vault_config.enable_redeem == true, E_NOT_ENABLED);
        assert!(tx_context::epoch(ctx) > vault_config.maturity_epoch, E_VAULT_NOT_MATURED);
        assert!(coin::value<PT_TOKEN<P>>(&pt) >= MIN_PT_TO_REDEEM, E_MIN_THRESHOLD);

        let paidout_amount = coin::value<PT_TOKEN<P>>(&pt);

        prepare_withdrawal(wrapper, global, paidout_amount, ctx);

        // withdraw 
        withdraw_sui(global, paidout_amount, tx_context::sender(ctx), ctx);

        let vault_reserve = get_vault_reserve<P>(&mut global.pool_reserves);

        // burn PT tokens
        let burned_balance = balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(pt));

        redeem_event(
            token_to_name<P>(),
            burned_balance,
            paidout_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx)
        );
    }

    // exit the position before the vault matures by using the combination of PT and VT to unlock Staked SUI objects (disabled by default)
    public entry fun exit<P, T>(wrapper: &mut SuiSystemState, global: &mut Global, amm_global: &mut AMMGlobal, deposit_id: u64, pt: Coin<PT_TOKEN<P>>,yt: Coin<VAULT>, ctx: &mut TxContext) {
        let vault_config = get_vault_config<P>(&mut global.pools);
        let vault_reserve = get_vault_reserve<P>(&mut global.pool_reserves);

        assert!(vault_config.enable_exit == true, E_EXIT_DISABLED);
        assert!(vault_config.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!( vector::length( &vault_config.deposit_items ) > deposit_id, E_INVALID_DEPOSIT_ID );
        assert!( option::is_some( &vault_config.exit_conversion_rate ), E_RATE_NOT_SET );

        let token_name = token_to_name<T>();
        assert!( table::contains(&global.yt_in_circulation, token_name), E_INVALID_LIQUIDITY);

        let staked_sui = vector::swap_remove(&mut vault_config.deposit_items, deposit_id);
        let asset_object_id = object::id(&staked_sui);

        // PT needed calculates from the principal + accumurated rewards
        let needed_pt_amount = staking_pool::staked_sui_amount(&staked_sui)+apy_reader::earnings_from_staked_sui(wrapper, &staked_sui, tx_context::epoch(ctx));

        // YT covers of the remaining debt until the vault matures
        let pt_outstanding_debts = calculate_pt_debt_from_epoch(vault_config.vault_apy, tx_context::epoch(ctx), vault_config.maturity_epoch, needed_pt_amount);

        // converts to USDC equivalent
        let pt_outstanding_debts_in_usdc = mul_div( pt_outstanding_debts, *option::borrow(&vault_config.exit_conversion_rate), 1_000_000_000 );

        let amm_pool = amm::get_mut_pool<VAULT, T>(amm_global, true);
        let (reserve_1, reserve_2, _) = amm::get_reserves_size<VAULT, T>(amm_pool);
        let needed_yt_amount = amm::get_amount_out(
                pt_outstanding_debts_in_usdc,
                reserve_1,
                reserve_2
        );
        if (MIN_YT_FOR_EXIT > needed_yt_amount) needed_yt_amount = MIN_YT_FOR_EXIT;

        let input_pt_amount = coin::value<PT_TOKEN<P>>(&pt);
        let input_yt_amount = coin::value<VAULT>(&yt);

        assert!( input_pt_amount >= needed_pt_amount , E_INSUFFICIENT_AMOUNT);
        assert!( input_yt_amount >= needed_yt_amount , E_INSUFFICIENT_AMOUNT);

        // burn PT
        if (input_pt_amount == needed_pt_amount) {
            balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(pt));
        } else {
            balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(coin::split(&mut pt, needed_pt_amount, ctx)));
            transfer::public_transfer(pt, tx_context::sender(ctx));
        };

        // burn YT
        if (input_yt_amount == needed_yt_amount) {
            balance::decrease_supply(&mut global.yt_supply, coin::into_balance(yt));
        } else {
            balance::decrease_supply(&mut global.yt_supply, coin::into_balance( coin::split(&mut yt, needed_yt_amount, ctx) ));
            transfer::public_transfer(yt, tx_context::sender(ctx));
        };

        // send out Staked SUI
        transfer::public_transfer(staked_sui, tx_context::sender(ctx)); 

        exit_event(
            token_to_name<P>(),
            deposit_id,
            asset_object_id,
            needed_pt_amount,
            needed_yt_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx)
        );
    }

    public fun get_vault_config<P>(table: &mut Table<String, PoolConfig>): &mut PoolConfig  {
        let vault_name = token_to_name<P>();
        let has_registered = table::contains(table, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        table::borrow_mut<String, PoolConfig>(table, vault_name)
    }

    public fun get_vault_reserve<P>(vaults: &mut Bag): &mut PoolReserve<P> {
        let vault_name = token_to_name<P>();
        let has_registered = bag::contains_with_type<String, PoolReserve<P>>(vaults, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        bag::borrow_mut<String, PoolReserve<P>>(vaults, vault_name)
    }

    public fun get_vault_epochs<P>(table: &Table<String, PoolConfig>) : (u64, u64) {
        let vault_name = token_to_name<P>();
        let has_registered = table::contains(table, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);
        let pool_config = table::borrow(table, vault_name );
        (pool_config.started_epoch, pool_config.maturity_epoch)
    }

    // ======== Only Governance =========

    // create new Staked SUI vault 
    public entry fun new_vault<P>(global: &mut Global, _manager_cap: &mut ManagerCap, started_epoch: u64, maturity_epoch: u64, initial_apy: u64, ctx: &mut TxContext) {
        assert!( maturity_epoch > tx_context::epoch(ctx) , E_INVALID_MATURITY);
        assert!(started_epoch >= tx_context::epoch(ctx) , E_INVALID_STARTED);
        assert!(maturity_epoch-started_epoch >= MIN_VAULT_SPAN, E_TOO_SHORT);

        // verify if the vault has been created
        let vault_name = token_to_name<P>();
        let has_registered = bag::contains_with_type<String, PoolReserve<P>>(&global.pool_reserves, vault_name);
        assert!(!has_registered, E_DUPLICATED_ENTRY);

        // the start epoch must be within the previous vault's start and maturity epochs
        if (vector::length(&global.pool_list) > 0) {
            let pool_name = *vector::borrow( &global.pool_list, vector::length(&global.pool_list)-1);
            let pool_config = table::borrow(&global.pools, pool_name);
            assert!((started_epoch > pool_config.started_epoch &&  pool_config.maturity_epoch > started_epoch) , E_INVALID_STARTED);
        };

        let pool_config = PoolConfig {
            started_epoch,
            maturity_epoch,
            vault_apy: initial_apy, 
            deposit_items: vector::empty<StakedSui>(),
            debt_balance: 0,
            exit_conversion_rate: option::none<u64>(),
            enable_exit : false,
            enable_mint: true,
            enable_redeem: true
        };

        let pool_reserve = PoolReserve {
            pt_supply: balance::create_supply(PT_TOKEN<P> {}),
            pending_burn: balance::zero<PT_TOKEN<P>>()
        };

        bag::add(&mut global.pool_reserves, vault_name, pool_reserve);
        table::add(&mut global.pools, vault_name, pool_config);
        vector::push_back<String>(&mut global.pool_list, vault_name);

        // emit event
        new_vault_event(
            object::id(global),
            vault_name,
            tx_context::epoch(ctx),
            started_epoch,
            maturity_epoch,
            initial_apy
        )
    }

    // add circulation for YT
    public entry fun add_yt_circulation<P>(global: &mut Global, amm_global: &mut AMMGlobal, _manager_cap: &mut ManagerCap, liquidity_coin: Coin<P>, mint_amount: u64, ctx: &mut TxContext ) {
        
        // coin to be liquidity
        let token_name = token_to_name<P>();

        // add to table for tracking
        if (table::contains(&global.yt_in_circulation, token_name)) {
            let total = *table::borrow(&global.yt_in_circulation, token_name);
            *table::borrow_mut(&mut global.yt_in_circulation, token_name) = total+mint_amount;
        } else {
            assert!(table::length(&global.yt_in_circulation) == 0, E_ONLY_LIQUIDITY_ALLOWED);
            table::add(&mut global.yt_in_circulation, token_name, mint_amount);
        };
        
        // mint YT
        let minted_balance = balance::increase_supply<VAULT>(&mut global.yt_supply, mint_amount);

        amm::add_liquidity<VAULT, P>( amm_global, coin::from_balance(minted_balance, ctx) , 1, liquidity_coin, 1, ctx );
    }

    // rebalance YT tokens
    public entry fun rebalance<P, T>(wrapper: &mut SuiSystemState, global: &mut Global, amm_global: &mut AMMGlobal, _manager_cap: &mut ManagerCap, liquidity_coin: Coin<T>, conversion_rate: u64 , ctx: &mut TxContext) {
        assert!( conversion_rate > MIN_PT_REBALANCE, E_TOO_LOW);
        assert!( coin::value(&liquidity_coin) > MIN_PT_REBALANCE, E_TOO_LOW);
        
        // vault to be base for rebalancing
        let vault_config = get_vault_config<P>( &mut global.pools);
        let vault_reserve = get_vault_reserve<P>(&mut global.pool_reserves);

        // coin as liquidity
        let token_name = token_to_name<T>();
        assert!( table::contains(&global.yt_in_circulation, token_name), E_INVALID_LIQUIDITY);

        let accumulated_rewards = vault_rewards(wrapper, vault_config , tx_context::epoch(ctx) );
        let outstanding_debts = vault_config.debt_balance;

        let surplus = 
            if (accumulated_rewards >= outstanding_debts)
                accumulated_rewards - outstanding_debts
            else 0;

        assert!( surplus > MIN_PT_REBALANCE, E_TOO_LOW);

        vault_config.debt_balance = vault_config.debt_balance+surplus;

        // mint PT to treasury. attached USDC will be used to buy YT
        let minted_balance = balance::increase_supply(&mut vault_reserve.pt_supply, surplus);
        balance::join<PT_TOKEN<P>>(&mut vault_reserve.pending_burn, minted_balance);

        let buy_amount = mul_div( surplus, conversion_rate, 1_000_000_000);

        let buying_coin = coin::split(&mut liquidity_coin, buy_amount, ctx);

        amm::swap<T, VAULT>(amm_global, buying_coin, 1, ctx);

        // send the remaining back
        transfer::public_transfer(liquidity_coin , tx_context::sender(ctx));

        // emit event
        rebalance_event( token_to_name<P>(), surplus, buy_amount, conversion_rate, tx_context::epoch(ctx) );

    }

    // add support staking pool
    public entry fun attach_pool(global: &mut Global, _manager_cap: &mut ManagerCap, pool_address:address, pool_id: ID) {
        assert!(!vector::contains(&global.staking_pools, &pool_address), E_DUPLICATED_ENTRY);
        vector::push_back<address>(&mut global.staking_pools, pool_address);
        vector::push_back<ID>(&mut global.staking_pool_ids, pool_id);
    }

    // remove support staking pool
    public entry fun detach_pool(global: &mut Global, _manager_cap: &mut ManagerCap, pool_address: address) {
        let (contained, index) = vector::index_of<address>(&global.staking_pools, &pool_address);
        assert!(contained, E_NOT_FOUND);
        vector::remove<address>(&mut global.staking_pools, index);
        vector::remove<ID>(&mut global.staking_pool_ids, index);
    }

    // enable exit for the given vault
    public entry fun enable_exit<P>(global: &mut Global, _manager_cap: &mut ManagerCap) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        vault_config.enable_exit = true;
    }

    // disable exit for the given vault
    public entry fun disable_exit<P>(global: &mut Global, _manager_cap: &mut ManagerCap) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        vault_config.enable_exit = false;
    }

    // enable mint for the given vault 
    public entry fun enable_mint<P>(global: &mut Global, _manager_cap: &mut ManagerCap) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        vault_config.enable_mint = true;
    }

    // disable mint for the given vault
    public entry fun disable_mint<P>(global: &mut Global, _manager_cap: &mut ManagerCap) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        vault_config.enable_mint = false;
    }

    // enable redeem for the given vault 
    public entry fun enable_redeem<P>(global: &mut Global, _manager_cap: &mut ManagerCap) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        vault_config.enable_redeem = true;
    }

    // disable redeem for the given vault
    public entry fun disable_redeem<P>(global: &mut Global, _manager_cap: &mut ManagerCap) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        vault_config.enable_redeem = false;
    }

    // update vault's fixed apy
    public entry fun update_vault_apy<P>(global: &mut Global, _manager_cap: &mut ManagerCap, value: u64) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        vault_config.vault_apy = value;
    }

    // set exit conversion rate for the given vault
    public entry fun set_exit_conversion_rate<P>(global: &mut Global, _manager_cap: &mut ManagerCap, conversion_rate: u64) {
        let vault_config = get_vault_config<P>( &mut global.pools);
        if (conversion_rate == 0)
            vault_config.exit_conversion_rate = option::none<u64>()
        else vault_config.exit_conversion_rate = option::some<u64>(conversion_rate);
    }

    // top-up redeem pool
    public entry fun emergency_topup_redemption_pool(global: &mut Global, _manager_cap: &mut ManagerCap, coin: Coin<SUI>, _ctx: &mut TxContext) {
        let balance = coin::into_balance(coin);
        balance::join<SUI>(&mut global.pending_withdrawal, balance);
    }

    // withdraw SUI from redeem pool
    public entry fun emergency_withdraw_redemption_pool(global: &mut Global, _manager_cap: &mut ManagerCap, amount: u64, ctx: &mut TxContext) {
        let withdrawn_balance = balance::split<SUI>(&mut global.pending_withdrawal, amount);
        transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), tx_context::sender(ctx));
    }

    // set amount as zero to ignore
    public entry fun set_deposit_cap(global: &mut Global, _manager_cap: &mut ManagerCap, amount: u64) {
        if (amount == 0)
            global.deposit_cap = option::none<u64>()
        else global.deposit_cap = option::some<u64>(amount);
    }

    // ======== Internal Functions =========

    // when there're 2 fixed-term vaults active simultaneously
    fun check_not_paused(global: &Global, current_epoch: u64) {
        assert!( vector::length(&global.pool_list) > 1 , E_PAUSED_STATE);
        let total = vector::length(&global.pool_list);
        let recent_pool_name = *vector::borrow( &global.pool_list, total-1);
        let recent_pool_config = table::borrow(&global.pools, recent_pool_name);
        assert!((recent_pool_config.maturity_epoch >= current_epoch) , E_PAUSED_STATE);

        let ref_pool_name = *vector::borrow( &global.pool_list, total-2);
        let ref_pool_config = table::borrow(&global.pools, ref_pool_name);
        assert!((ref_pool_config.maturity_epoch >= current_epoch) , E_PAUSED_STATE);
    }

    // initiates withdrawal by unstaking locked Staked SUI and retaining SUI tokens in the pool
    fun prepare_withdrawal(wrapper: &mut SuiSystemState, global: &mut Global, paidout_amount: u64, ctx: &mut TxContext) {
        // ignore if there are sufficient SUI to pay out 
        if (paidout_amount > balance::value(&global.pending_withdrawal)) {
            // extract all asset IDs to be withdrawn
            let pending_withdrawal = balance::value(&global.pending_withdrawal);
            let (pool_list, asset_ids) = locate_withdrawable_asset(wrapper, &global.pool_list, &mut global.pools, paidout_amount, pending_withdrawal, tx_context::epoch(ctx));

            // unstake assets
            let sui_balance = unstake_staked_sui(wrapper, &mut global.pools, pool_list, asset_ids, ctx);
            balance::join<SUI>(&mut global.pending_withdrawal, sui_balance);
        };
    }

    fun locate_withdrawable_asset(wrapper: &mut SuiSystemState, pool_list: &vector<String>, pools: &mut Table<String, PoolConfig> , paidout_amount: u64, pending_withdrawal: u64, epoch: u64): (vector<String>,vector<u64>)  {

        let pool_count = 0;
        let asset_pools = vector::empty();
        let asset_ids = vector::empty();
        let amount_to_unwrap = paidout_amount-pending_withdrawal;
        
        while (pool_count < vector::length(pool_list)) { 
            let pool_name = *vector::borrow(pool_list, pool_count);
            let pool = table::borrow_mut(pools, pool_name); 
            let item_count = 0;
            while (item_count < vector::length(&pool.deposit_items)) {
                let staked_sui = vector::borrow(&pool.deposit_items, item_count);
                let amount_with_rewards = staking_pool::staked_sui_amount(staked_sui)+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);
                
                vector::push_back<String>(&mut asset_pools, pool_name);
                vector::push_back<u64>(&mut asset_ids, item_count);

                amount_to_unwrap =
                    if (paidout_amount >= amount_with_rewards)
                        paidout_amount - amount_with_rewards
                    else 0;

                item_count = item_count+1;
                if (amount_to_unwrap == 0) break
            };

            pool_count = pool_count + 1;
            if (amount_to_unwrap == 0) break
        };

        (asset_pools,asset_ids)
    }

    // unstake Staked SUI from the validator
    fun unstake_staked_sui(wrapper: &mut SuiSystemState, pools: &mut Table<String, PoolConfig>, asset_pools:vector<String>, asset_ids: vector<u64>, ctx: &mut TxContext): Balance<SUI> {

        let balance_sui = balance::zero();

        while (vector::length<u64>(&asset_ids) > 0) {
            let pool_name = vector::pop_back(&mut asset_pools);
            let asset_id = vector::pop_back(&mut asset_ids);
            
            let pool = table::borrow_mut(pools, pool_name); 
            let staked_sui = vector::swap_remove(&mut pool.deposit_items, asset_id);
            let principal_amount = staking_pool::staked_sui_amount(&staked_sui);
            let balance_each = sui_system::request_withdraw_stake_non_entry(wrapper, staked_sui, ctx);
            
            let reward_amount =
                if (balance::value(&balance_each) >= principal_amount)
                    balance::value(&balance_each) - principal_amount
                else 0;
            
            balance::join<SUI>(&mut balance_sui, balance_each);

            pool.debt_balance = 
                if (pool.debt_balance >= reward_amount)
                    pool.debt_balance - reward_amount
                else 0;
        };

        balance_sui
    }

    fun receive_staked_sui(vault_config: &mut PoolConfig, staked_sui: StakedSui) {
        vector::push_back<StakedSui>(&mut vault_config.deposit_items, staked_sui);
        if (vector::length(&vault_config.deposit_items) > 1) sort_items(&mut vault_config.deposit_items);
    }

    fun mint_pt<P>(vault_reserve: &mut PoolReserve<P>, amount: u64, ctx: &mut TxContext) {
        let minted_balance = balance::increase_supply(&mut vault_reserve.pt_supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), tx_context::sender(ctx));
    }

    fun withdraw_sui(global: &mut Global, amount: u64, recipient: address , ctx: &mut TxContext) {
        assert!( balance::value(&global.pending_withdrawal) >= amount, E_INVALID_AMOUNT);

        let payout_balance = balance::split(&mut global.pending_withdrawal, amount);
        transfer::public_transfer(coin::from_balance(payout_balance, ctx), recipient);
    }

    // return accumulated rewards for the given vault config
    fun vault_rewards(wrapper: &mut SuiSystemState, vault_config: &PoolConfig, epoch: u64): u64 {
        let count = vector::length(&vault_config.deposit_items);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            let staked_sui = vector::borrow(&vault_config.deposit_items, i);
            let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);
            if (epoch > activation_epoch) total_sum = total_sum+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);
            i = i + 1;
        };
        total_sum
    }

    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(VAULT {}, ctx);
    }

    #[test_only]
    public fun median_apy(wrapper: &mut SuiSystemState, global: &Global, epoch: u64): u64 {
        let count = vector::length(&global.staking_pools);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            let pool_id = vector::borrow(&global.staking_pool_ids, i);
            total_sum = total_sum+apy_reader::pool_apy(wrapper, pool_id, epoch);
            i = i + 1;
        };
        total_sum / i
    }

    #[test_only]
    public fun ceil_apy(wrapper: &mut SuiSystemState, global: &Global, epoch: u64): u64 {
        let count = vector::length(&global.staking_pools);
        let i = 0;
        let output = 0;
        while (i < count) {
            let pool_id = vector::borrow(&global.staking_pool_ids, i);
            output = math::max( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
            i = i + 1;
        };
        output
    }

    #[test_only]
    public fun floor_apy(wrapper: &mut SuiSystemState,  global: &Global, epoch: u64): u64 {
        let count = vector::length(&global.staking_pools);
        let i = 0;
        let output = 0;
        while (i < count) {
            let pool_id = vector::borrow(&global.staking_pool_ids, i);
            if (output == 0)
                    output = apy_reader::pool_apy(wrapper, pool_id, epoch)
                else output = math::min( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
            i = i + 1;
        };
        output
    }

}   