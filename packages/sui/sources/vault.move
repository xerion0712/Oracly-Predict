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
    use legato::vault_lib::{calculate_pt_debt_amount};

    // ======== Constants ========
    
    const FIRST_EPOCH_ON_THIS_YEAR : u64 = 264; // 1st epoch of 2024
    const EPOCH_PER_QUARTER: u64 = 90; 
    const COOLDOWN_EPOCH: u64 = 3; 
    const MIN_SUI_TO_STAKE : u64 = 1_000_000_000; // 1 Sui

    // ======== Errors ========

    const E_DUPLICATED_ENTRY: u64 =  1;
    const E_NOT_FOUND: u64  = 2;
    const E_INVALID_FLAG: u64 = 3;
    const E_NOT_REGISTERED: u64 = 4;
    const E_INVALID_QUARTER: u64 = 5;
    const E_NOT_ENABLED: u64 = 6;
    const E_MIN_THRESHOLD: u64 = 7;
    const E_VAULT_MATURED: u64 = 8;
    const E_UNAUTHORIZED_POOL: u64 = 9;
    const E_DEPOSIT_CAP: u64 = 10;
    const E_MINT_PT_ERROR: u64 = 11;


    // ======== Structs =========

    // Represents the future value at maturity date
    struct PT_TOKEN<phantom P> has drop {}

    // Vault's configuration
    struct VaultConfig has store {
        started_epoch: u64,
        maturity_epoch: u64,
        vault_apy: FixedPoint64, // Calculated by the recent quarter's average APY from all supported pools
        staked_sui_ids: vector<ID>,
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
        staked_sui: vector<StakedSui>,
        vault_list: vector<String>,
        vault_config: Table<String, VaultConfig>,
        vault_reserves: Bag,
        pending_withdrawal: Balance<SUI>, // where the redemption process takes place
        deposit_cap: Option<u64>, // deposit no more than a certain amount
        first_epoch_of_the_year: u64 // the epoch that is equivalent to the first day of the year
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
            staked_sui: vector::empty<StakedSui>(),
            vault_list: vector::empty<String>(),
            vault_config: table::new(ctx),
            vault_reserves: bag::new(ctx),
            pending_withdrawal: balance::zero(),
            deposit_cap: option::none<u64>(),
            first_epoch_of_the_year: FIRST_EPOCH_ON_THIS_YEAR
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
    
    // Convert Staked SUI to PT on the given vault 
    public entry fun mint<P>(
        wrapper: &mut SuiSystemState, 
        global: &mut Global, 
        staked_sui: StakedSui, 
        ctx: &mut TxContext
    ) {
        
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

        let asset_object_id = object::id(&staked_sui);

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
        vector::push_back<StakedSui>(&mut global.staked_sui, staked_sui);
        vector::push_back<ID>(&mut vault_config.staked_sui_ids, asset_object_id); 

        // Calculate PT debt amount to send out 
        let minted_pt_amount = calculate_pt_debt_amount(vault_config.vault_apy, tx_context::epoch(ctx), vault_config.maturity_epoch, principal_amount+total_earned);
        let debt_amount = minted_pt_amount-principal_amount; 
        
        // Sanity check
        assert!(minted_pt_amount >= MIN_SUI_TO_STAKE, E_MINT_PT_ERROR);

        // Mint PT to the user
        transfer::public_transfer( mint_pt<P>(vault_reserve, minted_pt_amount, ctx), tx_context::sender(ctx));
        
        // Update vault's debt balance
        vault_config.debt_balance = vault_config.debt_balance+debt_amount;

        // TODO: emit event
    }

    public fun get_vault_config<P>(table: &mut Table<String, VaultConfig>): &mut VaultConfig  {
        let vault_name = token_to_name<P>();
        let has_registered = table::contains(table, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        table::borrow_mut<String, VaultConfig>(table, vault_name)
    }

    public fun get_vault_reserve<P>(vaults: &mut Bag): &mut VaultReserve<P> {
        let vault_name = token_to_name<P>();
        let has_registered = bag::contains_with_type<String, VaultReserve<P>>(vaults, vault_name);
        assert!(has_registered, E_NOT_REGISTERED);

        bag::borrow_mut<String, VaultReserve<P>>(vaults, vault_name)
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

        let config = VaultConfig {
            started_epoch: tx_context::epoch(ctx),
            maturity_epoch: global.first_epoch_of_the_year+(EPOCH_PER_QUARTER*quarter),
            vault_apy: fixed_point64::create_from_rational(apy_numerator, apy_denominator),
            debt_balance: 0,
            staked_sui_ids: vector::empty<ID>(),
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

        // emit event
        // new_vault_event(
        //     object::id(global),
        //     vault_name,
        //     tx_context::epoch(ctx),
        //     started_epoch,
        //     maturity_epoch,
        //     initial_apy
        // )

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
        vault_config.vault_apy = fixed_point64::create_from_rational( value_numerator, value_denominator);
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

    // To set the deposit cap. Put amount as zero to ignore
    public entry fun set_deposit_cap(global: &mut Global, _manager_cap: &mut ManagerCap, amount: u64) {
        // Check if the amount is zero
        if (amount == 0)
            // Set deposit cap to none
            global.deposit_cap = option::none<u64>()
        // Set deposit cap to the specified amount
        else global.deposit_cap = option::some<u64>(amount);
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

    // ======== Test-related Functions =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

}