// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// Vault manager module creates a timelock vault with a specific maturity date and fixed APY
// Each vault contains its own derivative tokens of PT following a quarterly expiration (4 pt/yr.)
// When depositing SUI or Staked SUI, the staker will receive PT equivalent to the principal at the maturity date
// For example, depositing 1 SUI in a vault with a 3% fixed-rate will receive 1.03 PT, which can be redeemed for SUI at a 1:1 ratio after a year
// Since this is liquid staking, prior to the maturity date, there are many options stakers can choose. Check out https://docs.legato.finance

module legato::vault {

    use sui::sui::SUI; 
    use sui::transfer;
    use sui::table::{ Self, Table};
    use sui::bag::{ Self, Bag};
    use sui::balance::{ Self, Supply, Balance}; 
    use sui::tx_context::{ Self, TxContext};
    use sui::coin::{Self, Coin};

    use sui::object::{ Self, ID, UID };
    use sui_system::staking_pool::{ Self, StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState };
    use sui::random::{ Random};

    use std::string::{  Self, String }; 
    use std::option::{  Self, Option};
    use std::vector;
    use std::ascii::{ into_bytes};
    use std::type_name::{get, into_string};

    use legato::fixed_point64::{Self, FixedPoint64};
    use legato::stake_data_provider::{Self};
    use legato::vault_lib::{calculate_pt_debt_amount, get_amount_with_rewards, calculate_exit_amount, sort_items, matching_asset_to_ratio, reduce_pool_list, filter_asset_ids};
    use legato::event::{new_vault_event, update_vault_apy_event, mint_event, migrate_event, redeem_event, exit_event};

    // ======== Constants ========
    
    const FIRST_EPOCH_ON_THIS_YEAR : u64 = 264; // 1st epoch of 2024
    const EPOCH_PER_QUARTER: u64 = 90; 
    const COOLDOWN_EPOCH: u64 = 3; 
    const MIN_SUI_TO_STAKE : u64 = 1_000_000_000; // 1 Sui
    const MIN_PT_TO_REDEEM: u64 = 1_000_000_000; // 1 PT
    const MIN_PT_TO_MIGRATE : u64 = 1_000_000_000; // 1 PT
    const MIN_PT_TO_EXIT: u64 = 1_000_000_000; // 1 PT

    const DEFAULT_EXIT_FEE: u128 = 553402322211286548; // 3% in fixed-point

    // ======== Errors ========

    const E_DUPLICATED_ENTRY: u64 =  101;
    const E_NOT_FOUND: u64  = 102;
    const E_INVALID_FLAG: u64 = 103;
    const E_NOT_REGISTERED: u64 = 104;
    const E_INVALID_QUARTER: u64 = 105;
    const E_NOT_ENABLED: u64 = 106;
    const E_MIN_THRESHOLD: u64 = 107;
    const E_VAULT_MATURED: u64 = 108;
    const E_UNAUTHORIZED_POOL: u64 = 109;
    const E_DEPOSIT_CAP: u64 = 110;
    const E_MINT_PT_ERROR: u64 = 111;
    const E_VAULT_NOT_MATURED: u64 = 112;
    const E_INVALID_AMOUNT: u64 = 113;
    const E_VAULT_NOT_ORDER: u64 = 114;
    const E_EXIT_DISABLED: u64 = 115;
    const E_INSUFFICIENT: u64 = 116;

    // ======== Structs =========

    // Represents the future value at maturity date
    struct PT_TOKEN<phantom P> has drop {}

    // Vault's configuration
    struct VaultConfig has store {
        started_epoch: u64,
        maturity_epoch: u64,
        vault_apy: FixedPoint64, // Updated weekly with the average rate. Vaults with 6+ mo. rely on the team's estimation.
        staked_sui: vector<StakedSui>,
        debt_balance: u64, // Outstanding debts from issuing PT tokens
        enable_mint: bool,
        enable_exit: bool,
        enable_redeem: bool
    }

    // Vault's reserve
    struct VaultReserve<phantom P> has store {
        pt_supply: Supply<PT_TOKEN<P>>
    }

    // Using ManagerCap for admin permission
    struct ManagerCap has key {
        id: UID
    }

    // Global state
    struct Global has key {
        id: UID,
        staking_pools: vector<address>, // supported staking pools
        staking_pool_ids: vector<ID>, // supported staking pools in ID
        vault_list: vector<String>,
        vault_config: Table<String, VaultConfig>,
        vault_reserves: Bag,
        pending_withdrawal: Balance<SUI>, // where the redemption process takes place
        deposit_cap: Option<u64>, // deposit no more than a certain amount
        first_epoch_of_the_year: u64, // the epoch that is equivalent to the first day of the year
        exit_fee: FixedPoint64
    }

    fun init(ctx: &mut TxContext) {
        
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        transfer::share_object(Global {
            id: object::new(ctx),
            staking_pools: vector::empty<address>(),
            staking_pool_ids: vector::empty<ID>(), 
            vault_list: vector::empty<String>(),
            vault_config: table::new(ctx),
            vault_reserves: bag::new(ctx),
            pending_withdrawal: balance::zero(),
            deposit_cap: option::none<u64>(),
            first_epoch_of_the_year: FIRST_EPOCH_ON_THIS_YEAR,
            exit_fee: fixed_point64::create_from_raw_value( DEFAULT_EXIT_FEE )
        })

    }

    // ======== Public Functions =========

    // Convert SUI to Staked SUI and then PT on the given vault
    #[allow(lint(public_random))]
    public entry fun mint_from_sui<P>(wrapper: &mut SuiSystemState, global: &mut Global, r: &Random, sui: Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(&sui) >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);

        let validator_address = stake_data_provider::random_active_validator( wrapper, r, global.staking_pools , ctx );

        let staked_sui = sui_system::request_add_stake_non_entry(wrapper, sui, validator_address, ctx);
        mint<P>(wrapper, global, staked_sui , ctx);
    }
    
    // Mint PT represents the future value of Staked SUI at the time of maturity date. PT amount will be calculated by the formula below
    // - PT = Staked SUI * e^(rt)
    public entry fun mint<P>(
        wrapper: &mut SuiSystemState, 
        global: &mut Global, 
        staked_sui: StakedSui, 
        ctx: &mut TxContext
    ) {
        
        let vault_name = token_to_name<P>();
        let asset_object_id = object::id(&staked_sui);
        let input_amount = staking_pool::staked_sui_amount(&staked_sui);

        let (pt_token, _) = mint_non_entry<P>(wrapper, global, staked_sui, ctx);

        let pt_amount = coin::value(&pt_token);

        // Transfer PT to the user
        transfer::public_transfer( pt_token , tx_context::sender(ctx));

        mint_event(
            vault_name,
            input_amount,
            pt_amount,
            asset_object_id,
            tx_context::sender(ctx),
            tx_context::epoch(ctx)
        );
    }

    // Redeem SUI back at a 1:1 ratio with PT tokens when the vault reaches its maturity date
    public entry fun redeem<P>(wrapper: &mut SuiSystemState, global: &mut Global, pt: Coin<PT_TOKEN<P>>, ctx: &mut TxContext) {
        
        let vault_name = token_to_name<P>();
        
        let (sui_token, burned_balance) = redeem_non_entry<P>(
            wrapper,
            global,
            pt,
            ctx
        );

        let output_amount = coin::value(&(sui_token));

        transfer::public_transfer(sui_token, tx_context::sender(ctx));

        redeem_event(
            vault_name,
            burned_balance,
            output_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx)
        );

    }

    // Migrate PT tokens to other vault that is not backward in time
    public entry fun migrate<X,Y>(global: &mut Global, pt: Coin<PT_TOKEN<X>>, ctx: &mut TxContext) {
        check_vault_order<X,Y>(global);
        assert!(coin::value<PT_TOKEN<X>>(&pt) >= MIN_PT_TO_MIGRATE, E_MIN_THRESHOLD);

        let from_vault_name = token_to_name<X>();
        let to_vault_name = token_to_name<Y>();

        // PT burning in the 1st vault
        let from_vault_config = get_vault_config<X>(&mut global.vault_config);
        let from_epoch  = from_vault_config.maturity_epoch;
        let from_vault_reserve = get_vault_reserve<X>(&mut global.vault_reserves);
        let amount_to_migrate = coin::value(&pt);

        balance::decrease_supply(&mut from_vault_reserve.pt_supply, coin::into_balance(pt));

        // minting PT on the 2nd vault
        let to_vault_config = get_vault_config<Y>(&mut global.vault_config);
        let to_epoch  = to_vault_config.maturity_epoch;
        let to_vault_reserve = get_vault_reserve<Y>(&mut global.vault_reserves);
        assert!(to_vault_config.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);

        // Calculate extra PT to send out
        let minted_pt_amount = calculate_pt_debt_amount(to_vault_config.vault_apy, from_epoch, to_epoch, amount_to_migrate);
        let debt_amount =
                    if (amount_to_migrate >= amount_to_migrate)
                        amount_to_migrate - amount_to_migrate
                    else 0;

        to_vault_config.debt_balance = to_vault_config.debt_balance+debt_amount;

        transfer::public_transfer( mint_pt<Y>(to_vault_reserve, minted_pt_amount, ctx), tx_context::sender(ctx));
        
        migrate_event(
            from_vault_name,
            amount_to_migrate,
            to_vault_name,
            minted_pt_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx)
        );
    }

    // Exit the position before the vault matures. SUI tokens won't be received in full amount but obtained from the following formula, with the exit fee subtracted
    // - SUI = PT / e^(rt) - exit fee%
    public entry fun exit<P>(wrapper: &mut SuiSystemState, global: &mut Global, pt: Coin<PT_TOKEN<P>>, ctx: &mut TxContext) {
        assert!(coin::value<PT_TOKEN<P>>(&pt) >= MIN_PT_TO_EXIT, E_MIN_THRESHOLD);
        
        let vault_name = token_to_name<P>();
        let vault_config = get_vault_config<P>(&mut global.vault_config); 
    
        assert!(vault_config.enable_exit == true, E_EXIT_DISABLED);
        assert!(vault_config.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        
        let burned_amount = coin::value<PT_TOKEN<P>>(&pt);

        let exit_amount = calculate_exit_amount(vault_config.vault_apy, tx_context::epoch(ctx), vault_config.maturity_epoch, burned_amount);
    
        // Unstakes Staked SUI items closest in value to input PT amount for withdrawal

        prepare_withdrawal(wrapper, global, exit_amount, ctx);

        // Subtract fees and send to the sender, fees remain in the pending withdrawal pool
        let paidout_amount = ( fixed_point64::multiply_u128( (exit_amount as u128) , fixed_point64::sub( fixed_point64::create_from_u128(1) , global.exit_fee ) ) as u64 );
        transfer::public_transfer(withdraw_sui(global, paidout_amount, ctx), tx_context::sender(ctx));
        
        // burn PT tokens
        let vault_reserve = get_vault_reserve<P>(&mut global.vault_reserves);
        let burned_balance = balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(pt));

        exit_event(
            vault_name,
            burned_balance,
            paidout_amount,
            tx_context::sender(ctx),
            tx_context::epoch(ctx)
        );

    }

    // Retrieve the configuration for a specific vault 
    public fun get_vault_config<P>(table: &mut Table<String, VaultConfig>): &mut VaultConfig  {
        let vault_name = token_to_name<P>();
        let has_registered = table::contains(table, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        table::borrow_mut<String, VaultConfig>(table, vault_name)
    }

    // Retrieve the reserve data for a specific vault
    public fun get_vault_reserve<P>(vaults: &mut Bag): &mut VaultReserve<P> {
        let vault_name = token_to_name<P>();
        let has_registered = bag::contains_with_type<String, VaultReserve<P>>(vaults, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        bag::borrow_mut<String, VaultReserve<P>>(vaults, vault_name)
    }

    // Retrieve the amount of pending withdrawals
    public fun get_pending_withdrawal_amount(global: &Global) : u64 {
        balance::value(&global.pending_withdrawal)
    }

    public fun get_vault_info<P>(  global: & Global) : u64 {
        let vault_name = token_to_name<P>();
        let has_registered = table::contains(&global.vault_config, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        // TODO: vault principal and  rewards

        let config = table::borrow<String, VaultConfig>(&global.vault_config, vault_name);
        config.maturity_epoch
    }

    // return accumulated rewards for the given vault config
    // public fun vault_rewards(wrapper: &mut SuiSystemState, vault_config: &PoolConfig, epoch: u64): u64 {
    //     let count = vector::length(&vault_config.deposit_items);
    //     let i = 0;
    //     let total_sum = 0;
    //     while (i < count) {
    //         let staked_sui = vector::borrow(&vault_config.deposit_items, i);
    //         let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);
    //         if (epoch > activation_epoch) total_sum = total_sum+apy_reader::earnings_from_staked_sui(wrapper, staked_sui, epoch);
    //         i = i + 1;
    //     };
    //     total_sum
    // }

    public fun staking_pools(global: &Global) : vector<address> {
        global.staking_pools
    }

    public fun mint_non_entry<P>(
        wrapper: &mut SuiSystemState, 
        global: &mut Global, 
        staked_sui: StakedSui, 
        ctx: &mut TxContext
    ) : (Coin<PT_TOKEN<P>>, u64) {

        let vault_config = get_vault_config<P>(&mut global.vault_config);
        let vault_reserve = get_vault_reserve<P>(&mut global.vault_reserves);

        // Ensure minting is enabled for the vault
        assert!(vault_config.enable_mint == true, E_NOT_ENABLED);
        // Ensure the vault has not yet matured
        assert!(vault_config.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        // Ensure staked SUI amount is above the minimum threshold
        assert!(staking_pool::staked_sui_amount(&staked_sui) >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);

        // Check if the staked SUI is staked on a valid staking pool
        let pool_id = staking_pool::pool_id(&staked_sui);
        assert!(vector::contains(&global.staking_pool_ids, &pool_id), E_UNAUTHORIZED_POOL);

        // Extract principal amount of staked SUI
        let principal_amount = staking_pool::staked_sui_amount(&staked_sui);

        // Apply deposit cap if defined
        if (option::is_some(&global.deposit_cap)) {
            assert!( *option::borrow(&global.deposit_cap) >= principal_amount, E_DEPOSIT_CAP);
            *option::borrow_mut(&mut global.deposit_cap) = *option::borrow(&global.deposit_cap)-principal_amount;
        };

        // Calculate total earned amount until current epoch
        let total_earned = 
            if (tx_context::epoch(ctx) > staking_pool::stake_activation_epoch(&staked_sui))
                stake_data_provider::earnings_from_staked_sui(wrapper, &staked_sui, tx_context::epoch(ctx))
            else 0;

        // Receive staked SUI
        vector::push_back<StakedSui>(&mut vault_config.staked_sui, staked_sui); 
        if (vector::length(&vault_config.staked_sui) > 1) sort_items(&mut vault_config.staked_sui);

        // Calculate PT debt amount to send out 
        let minted_pt_amount = calculate_pt_debt_amount(vault_config.vault_apy, tx_context::epoch(ctx), vault_config.maturity_epoch, principal_amount+total_earned);
        let debt_amount = minted_pt_amount-principal_amount; 
        let yield_amount = minted_pt_amount-(principal_amount+total_earned);
        
        // Sanity check
        assert!(minted_pt_amount >= MIN_SUI_TO_STAKE, E_MINT_PT_ERROR);

        // Update vault's debt balance
        vault_config.debt_balance = vault_config.debt_balance+debt_amount;

        (mint_pt<P>(vault_reserve, minted_pt_amount, ctx), yield_amount)
    }

    public fun redeem_non_entry<P>(
        wrapper: &mut SuiSystemState,
        global: &mut Global,
        pt: Coin<PT_TOKEN<P>>,
        ctx: &mut TxContext
    ) : (Coin<SUI>, u64) {

        let vault_config = get_vault_config<P>(&mut global.vault_config);
        assert!(vault_config.enable_redeem == true, E_NOT_ENABLED);
        assert!(tx_context::epoch(ctx) > vault_config.maturity_epoch, E_VAULT_NOT_MATURED);
        assert!(coin::value<PT_TOKEN<P>>(&pt) >= MIN_PT_TO_REDEEM, E_MIN_THRESHOLD);

        let paidout_amount = coin::value<PT_TOKEN<P>>(&pt);

        // Initiates withdrawal by unstaking locked Staked SUI items that have the closest value 
        // to the input PT amount and puts them into the shared pool
        prepare_withdrawal(wrapper, global, paidout_amount, ctx);

        // give SUI to sender
        let sui_token = withdraw_sui(global, paidout_amount, ctx);
        
        // burn PT tokens
        let vault_reserve = get_vault_reserve<P>(&mut global.vault_reserves);
        let burned_balance = balance::decrease_supply(&mut vault_reserve.pt_supply, coin::into_balance(pt));

        ( sui_token , burned_balance )
    }

    // ======== Only Governance =========

    // Create a new vault for the given quarter. Note that the fixed-apy input is in fixed-point format
    // for example, 2% is represented as 2 on the numerator and 100 on the denominator (2/100 or 0.02)
    public entry fun new_vault<P>( global: &mut Global, _manager_cap: &mut ManagerCap, quarter: u64, apy_numerator: u128, apy_denominator: u128, ctx: &mut TxContext ) {
        assert!( quarter > 0 && quarter <= 4, E_INVALID_QUARTER); // only q1-q4
        
        // verify if the vault has been created
        let vault_name = token_to_name<P>();
        let has_registered = bag::contains_with_type<String, VaultReserve<P>>(&global.vault_reserves, vault_name);
        assert!(!has_registered, E_DUPLICATED_ENTRY);

        let vault_apy = fixed_point64::create_from_rational(apy_numerator, apy_denominator);
        let maturity_epoch = global.first_epoch_of_the_year+(EPOCH_PER_QUARTER*quarter);

        let config = VaultConfig {
            started_epoch: tx_context::epoch(ctx),
            maturity_epoch,
            vault_apy,
            debt_balance: 0,
            staked_sui: vector::empty<StakedSui>(),
            enable_exit : true,
            enable_mint: true,
            enable_redeem: true
        };

        let reserve = VaultReserve {
            pt_supply: balance::create_supply(PT_TOKEN<P> {})
        };

        bag::add(&mut global.vault_reserves, vault_name, reserve);
        table::add(&mut global.vault_config, vault_name, config);
        vector::push_back<String>(&mut global.vault_list, vault_name);

        new_vault_event(
            object::id(global),
            vault_name,
            tx_context::epoch(ctx),
            maturity_epoch,
            fixed_point64::get_raw_value(vault_apy)
        )

    }

    // To add a supported staking pool
    public entry fun attach_pool(global: &mut Global, _manager_cap: &mut ManagerCap, pool_address:address, pool_id: ID) {
        // Ensure that the pool address is not already in the list
        assert!(!vector::contains(&global.staking_pools, &pool_address), E_DUPLICATED_ENTRY);
        // Add the pool address and its ID to the respective lists
        vector::push_back<address>(&mut global.staking_pools, pool_address);
        vector::push_back<ID>(&mut global.staking_pool_ids, pool_id);
    }

    // To remove a staking pool from the list
    public entry fun detach_pool(global: &mut Global, _manager_cap: &mut ManagerCap, pool_address: address) {
        let (contained, index) = vector::index_of<address>(&global.staking_pools, &pool_address);
        assert!(contained, E_NOT_FOUND);
        vector::remove<address>(&mut global.staking_pools, index);
        vector::remove<ID>(&mut global.staking_pool_ids, index);
    }

    // set first epoch of the current year 
    public entry fun set_first_epoch(global: &mut Global, _manager_cap: &mut ManagerCap, new_value: u64) {
        global.first_epoch_of_the_year = new_value;
    }

    // Enable vault's param using the flags: (1) mint, (2) exit, (3) redeem 
    public entry fun enable<P>(global: &mut Global, _manager_cap: &mut ManagerCap, flag: u8) {
        assert!( flag > 0 && flag <= 3, E_INVALID_FLAG);
        let vault_config = get_vault_config<P>( &mut global.vault_config);
        if (flag == 1) {
            vault_config.enable_mint = true;
        } else if  ( flag ==2 ) {
            vault_config.enable_exit = true;
        } else {
            vault_config.enable_redeem = true;
        };
    }

    // Disable vault's param using the following flags: (1) mint, (2) exit, (3) redeem 
    public entry fun disable<P>(global: &mut Global, _manager_cap: &mut ManagerCap, flag: u8) {
        assert!( flag > 0 && flag <= 3, E_INVALID_FLAG);
        let vault_config = get_vault_config<P>( &mut global.vault_config);
        if (flag == 1) {
            vault_config.enable_mint = false;
        } else if  ( flag == 2 ) {
            vault_config.enable_exit = false;
        } else {
            vault_config.enable_redeem = false;
        };
    }

    // To setup vault's fixed rate
    public entry fun update_vault_apy<P>(global: &mut Global, _manager_cap: &mut ManagerCap,  value_numerator: u128, value_denominator: u128) {
        let vault_config = get_vault_config<P>( &mut global.vault_config);
        let new_vault_apy = fixed_point64::create_from_rational( value_numerator, value_denominator);
        vault_config.vault_apy = new_vault_apy;
    
        update_vault_apy_event(
            object::id(global),
            token_to_name<P>(),
            fixed_point64::get_raw_value(new_vault_apy)
        )
    }

    // To top-up the redemption pool
    public entry fun topup_redemption_pool(global: &mut Global, _manager_cap: &mut ManagerCap, coin: Coin<SUI>, _ctx: &mut TxContext) {
        let balance = coin::into_balance(coin);
        balance::join<SUI>(&mut global.pending_withdrawal, balance);
    }

    // To withdraw SUI from the redemption pool
    public entry fun withdraw_redemption_pool(global: &mut Global, _manager_cap: &mut ManagerCap, amount: u64, ctx: &mut TxContext) {
        let withdrawn_balance = balance::split<SUI>(&mut global.pending_withdrawal, amount);
        transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), tx_context::sender(ctx));
    }

    // Restake SUI from the redemption pool to a randomly chosen validator 
    // in the most recent vault
    #[allow(lint(public_random))]
    public entry fun restake(wrapper: &mut SuiSystemState, global: &mut Global, _manager_cap: &mut ManagerCap, r: &Random, restake_amount: u64, ctx: &mut TxContext ) {
        assert!(restake_amount >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);
        assert!(balance::value( &global.pending_withdrawal ) >= restake_amount , E_INSUFFICIENT);

        // Get the name of the most recent vault
        let pool_name = *vector::borrow( &global.vault_list , vector::length( &( global.vault_list ) )-1 );
        // Get the configuration of the most recent vault
        let vault_config = table::borrow_mut<String, VaultConfig>( &mut global.vault_config , pool_name);

        // Randomly select an active validator from the staking pools
        let validator_address = stake_data_provider::random_active_validator( wrapper, r, global.staking_pools , ctx );
        let restake_balance = balance::split<SUI>(&mut global.pending_withdrawal, restake_amount);

        // Request to add stake
        let staked_sui = sui_system::request_add_stake_non_entry(wrapper,  coin::from_balance(restake_balance, ctx)  , validator_address, ctx);
        vector::push_back<StakedSui>(&mut vault_config.staked_sui, staked_sui); 
    
        
    }

    // To set the deposit cap. Put amount as zero to ignore
    public entry fun set_deposit_cap(global: &mut Global, _manager_cap: &mut ManagerCap, amount: u64) {
        // Check if the amount is zero
        if (amount == 0)
            // Set deposit cap to none
            global.deposit_cap = option::none<u64>()
        // Set deposit cap to the specified amount
        else global.deposit_cap = option::some<u64>(amount);
    }

    // To update an exit fee
    public entry fun update_exit_fee(global: &mut Global, _manager_cap: &mut ManagerCap, value_numerator: u128, value_denominator: u128) {
        global.exit_fee = fixed_point64::create_from_rational( value_numerator, value_denominator);
    }

    // ======== Internal Functions =========

    // Converts a generic token to its name
    fun token_to_name<P>(): String {
        string::utf8(into_bytes(into_string(get<P>())))
    }

    // Mints PT 
    fun mint_pt<P>(vault_reserve: &mut VaultReserve<P>, amount: u64, ctx: &mut TxContext) : Coin<PT_TOKEN<P>> {
        let minted_balance = balance::increase_supply(&mut vault_reserve.pt_supply, amount);
        coin::from_balance(minted_balance, ctx)
    }

    fun withdraw_sui(global: &mut Global, amount: u64, ctx: &mut TxContext) : Coin<SUI>  {
        assert!( balance::value(&global.pending_withdrawal) >= amount, E_INVALID_AMOUNT);

        let payout_balance = balance::split(&mut global.pending_withdrawal, amount);
        coin::from_balance(payout_balance, ctx) 
    }
 
    fun prepare_withdrawal(wrapper: &mut SuiSystemState, global: &mut Global, paidout_amount: u64, ctx: &mut TxContext) {
        // ignore if there are sufficient SUI to pay out 
        if (paidout_amount > balance::value(&global.pending_withdrawal)) {
            // extract all asset IDs to be withdrawn
            let pending_withdrawal = balance::value(&global.pending_withdrawal);
            let remaining_amount = paidout_amount-pending_withdrawal;
            
            // Look for a single asset that cover first
            let (pool_id, asset_id ) = find_one_with_minimal_excess(wrapper,  &global.vault_list, &global.vault_config , remaining_amount, tx_context::epoch(ctx));
    
            if (option::is_none<u64>(&asset_id)) {
                // If no single asset fits, then we look for multiple assets. 
                let (pool_ids, asset_ids ) = find_combination(wrapper, &global.vault_list,  &global.vault_config , remaining_amount, tx_context::epoch(ctx));
                
                let sui_balance = unstake_staked_sui(wrapper, global, pool_ids, asset_ids, ctx); 
                balance::join<SUI>(&mut global.pending_withdrawal, sui_balance );
            } else { 
                let pool_ids = vector::empty<String>();
                let asset_ids = vector::empty<u64>();
                vector::push_back<String>( &mut pool_ids, *option::borrow(&pool_id)); 
                vector::push_back<u64>( &mut asset_ids, *option::borrow(&asset_id)); 
                let sui_balance = unstake_staked_sui(wrapper, global, pool_ids, asset_ids, ctx); 
                balance::join<SUI>(&mut global.pending_withdrawal, sui_balance );
            };

        };
    }

    //  Find one Staked SUI asset with sufficient value that cover the input amount and minimal excess
    fun find_one_with_minimal_excess(wrapper: &mut SuiSystemState, pool_list: &vector<String>, pools: &Table<String, VaultConfig> , input_amount: u64, epoch: u64 ) : (Option<String> , Option<u64>) {

        // Find the longest length across all pools
        let length = longest_length(pool_list, pools);

        // Initialize output variables
        let output_pool = option::none<String>();
        let output_id = option::none<u64>();

         // Loop through staked_sui in each pool
        let count = 0;

        while ( count < length ) {
            
            let pool_count = 0;
            while (pool_count < vector::length(pool_list)) {
                let pool_name = *vector::borrow(pool_list, pool_count);
                let pool = table::borrow(pools, pool_name);
                
                // Check if the pool has staked_sui at the current index 
                if ( vector::length(&pool.staked_sui)  > count )   {
                    let staked_sui = vector::borrow(&pool.staked_sui, count);
                    let amount_with_rewards = get_amount_with_rewards(wrapper,  staked_sui, epoch);

                    // If the amount with rewards is greater than the input amount, update output variables and break
                    if (amount_with_rewards > input_amount) { 
                        output_pool = option::some<String>( pool_name );
                        output_id = option::some<u64>( count );
                        count = length; // break main loop
                        break
                    };
                };

                pool_count = pool_count+1;
            };

            count = count + 1;
        };

        ( output_pool, output_id)
    }

    // Find a combination of staked SUI assets that have sufficient value to cover the input amount.
    fun find_combination(wrapper: &mut SuiSystemState, pool_list: &vector<String>, pools: &Table<String, VaultConfig> , input_amount: u64, epoch: u64 ) : (vector<String> , vector<u64>) {
                
        // Normalizing the value into the ratio
        let (ratio, ratio_to_id, ratio_to_pool) = normalize_into_ratio(wrapper, pool_list, pools, input_amount, epoch);

        // Initialize output variables
        let output_pool = vector::empty<String>();
        let output_id = vector::empty<u64>();

        let ratio_count = 0; // Tracks the total ratio

        // Looking for the asset that has 0.5 ratio first
        let target_ratio = fixed_point64::create_from_rational(1, 2);

        // Iterate until ratio > 10000
        while ( ratio_count <= 10000 ) {
                
            // Finds an asset with a ratio close to the target ratio
            let (value, id) = matching_asset_to_ratio(ratio, target_ratio );

            if (option::is_some( &id ) ) {

                let current_value = *option::borrow(&value);
                let current_id = *option::borrow(&id);

                if (fixed_point64::greater_or_equal(  fixed_point64::create_from_u128(1), current_value )) {
                    
                    // set new target
                    target_ratio = fixed_point64::sub( fixed_point64::create_from_u128(1), current_value );
 
                    vector::swap_remove( &mut ratio, current_id );
                    let pool_id = vector::swap_remove( &mut ratio_to_pool, current_id );
                    let asset_id = vector::swap_remove( &mut ratio_to_id, current_id );

                    vector::push_back(&mut output_pool, pool_id);
                    vector::push_back(&mut output_id, asset_id);

                    // increase ratio count 
                    ratio_count = ratio_count+fixed_point64::multiply_u128(10000, current_value);
                
                };
                
            } else {
                break
            }
        };

        ( output_pool, output_id)
    }

    fun normalize_into_ratio(wrapper: &mut SuiSystemState, pool_list: &vector<String>, pools: &Table<String, VaultConfig>, input_amount: u64, epoch: u64  ) : (vector<FixedPoint64>, vector<u64>, vector<String>) {
        let ratio = vector::empty<FixedPoint64>();
        let ratio_to_id = vector::empty<u64>();
        let ratio_to_pool = vector::empty<String>();

        let pool_count = 0;

        while (pool_count < vector::length(pool_list)) {
            let pool_name = *vector::borrow(pool_list, pool_count);
            let pool = table::borrow(pools, pool_name);

            
                let length = vector::length(&pool.staked_sui);
                let item_count = 0;
                while (item_count < length) {
                    let staked_sui = vector::borrow(&pool.staked_sui, item_count);
                    let amount_with_rewards = get_amount_with_rewards(wrapper,  staked_sui, epoch);
                    let this_ratio = fixed_point64::create_from_rational( (amount_with_rewards as u128) , (input_amount as u128));

                    vector::push_back(&mut ratio, this_ratio);
                    vector::push_back(&mut ratio_to_id, item_count);
                    vector::push_back(&mut ratio_to_pool, pool_name);

                    item_count = item_count+1;
                };
        

            pool_count = pool_count+1;
        };
        
        (ratio, ratio_to_id, ratio_to_pool)
    }

    fun longest_length(pool_list: &vector<String>, pools: &Table<String, VaultConfig>) : u64 {
        let pool_count = 0;
        let longest_length = 0;

        while (pool_count < vector::length(pool_list)) {
            let pool_name = *vector::borrow(pool_list, pool_count);
            let pool = table::borrow(pools, pool_name);
            let length = vector::length(&pool.staked_sui);

            if (length > longest_length) {
                longest_length = length;
            };

            pool_count = pool_count+1;
        };
 
        longest_length
    }

    // Unstake Staked SUI from the staking pool
    fun unstake_staked_sui(wrapper: &mut SuiSystemState, global: &mut Global, pool_ids: vector<String>, asset_ids: vector<u64>, ctx: &mut TxContext): Balance<SUI> {

        let balance_sui = balance::zero(); 

        let reduced_list = reduce_pool_list(pool_ids);
 
        let count = 0;
        
        while (count < vector::length(&(reduced_list))) {

            let pool_id = *vector::borrow(&reduced_list, count );
            let filtered_asset_ids = filter_asset_ids( pool_id, pool_ids, asset_ids );

            while (vector::length<u64>(&filtered_asset_ids) > 0) {
                let asset_id = vector::pop_back(&mut filtered_asset_ids);

                let pool = table::borrow_mut( &mut global.vault_config, pool_id);
                let staked_sui = vector::swap_remove(&mut pool.staked_sui, asset_id);
                let principal_amount = staking_pool::staked_sui_amount(&staked_sui);

                // Request to withdraw 
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

            count = count +1;
        };
 
        balance_sui
    }

     fun check_vault_order<X,Y>(global: &Global) {
        let from_pool_name = token_to_name<X>();
        let to_pool_name = token_to_name<Y>();
        let (from_contained, from_id) = vector::index_of<String>(&global.vault_list, &from_pool_name);
        assert!(from_contained,E_NOT_REGISTERED);
        let (to_contained, to_id) = vector::index_of<String>(&global.vault_list, &to_pool_name);
        assert!(to_contained,E_NOT_REGISTERED);
        assert!( to_id > from_id ,E_VAULT_NOT_ORDER);
    }

    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

}