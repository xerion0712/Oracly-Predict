// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// A timelock vault to convert APT into future value including yield tokenization for general purposes. 
// Each vault maintains its own tokens and adheres to a quarterly expiration schedule.

module legato_addr::vault {

    use std::signer;  
    use aptos_framework::timestamp;
    use std::string::{Self, String, utf8};
    use aptos_framework::event;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, ExtendRef};
    use aptos_framework::delegation_pool as dp;
    use aptos_framework::coin::{Self,   MintCapability, BurnCapability}; 
    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_std::type_info;   
    use aptos_std::fixed_point64::{Self, FixedPoint64};
    use aptos_std::math_fixed64::{Self};
    use aptos_std::table::{Self, Table};

    // ======== Constants ========

    const MIN_APT_TO_STAKE: u64 = 100000000; // 1 APT
    
    const DEFAULT_EXIT_FEE: u128 = 553402322211286548; // 3% in fixed-point
    const DEFAULT_BATCH_AMOUNT: u64 = 1500000000; // 15 APT

    // ======== Errors ========

    const ERR_UNAUTHORIZED: u64 = 101;
    const ERR_INVALID_MATURITY: u64 = 102;
    const ERR_VAULT_EXISTS: u64 = 103;
    const ERR_VAULT_MATURED: u64 = 104;
    const ERR_MIN_THRESHOLD: u64 = 105;
    const ERR_INVALID_VAULT: u64 = 106;  
    const ERR_VAULT_NOT_MATURED: u64 = 107;
    const ERR_INVALID_ADDRESS: u64 = 108;
    const ERR_INVALID_TYPE: u64 = 109;

    // ======== Structs =========

    // represent the future value at maturity date
    struct PT_TOKEN<phantom P> has drop {}

    struct VaultReserve<phantom P> has key { 
        pt_mint: MintCapability<PT_TOKEN<P>>,
        pt_burn: BurnCapability<PT_TOKEN<P>>,  
        pt_total_supply: u64,  // Total supply of PT tokens
    }

    struct VaultConfig has store { 
        maturity_time: u64,
        vault_apy: FixedPoint64, // Vault's APY based on the average rate
        enable_mint: bool, 
        enable_exit: bool,
        enable_redeem: bool
    }

    struct VaultManager has key {  
        delegator_pools: SmartVector<address>, // Supported delegator pools
        vault_list: SmartVector<String>,  // List of all vaults in the system
        vault_config: Table<String, VaultConfig>,
        extend_ref: ExtendRef, // self-sovereight identity
        pending_stake: u64, // Pending stake
        pending_unstake: Table<address, u64>, 
        unlocked_amount: u64,
        pending_withdrawal: Table<address, u64>,
        requesters: SmartVector<address>,
        batch_amount: u64,
        exit_fee: FixedPoint64 
    }


    #[event]
    struct NewVault has drop, store {
        vault_name: String,
        maturity_time: u64,
        vault_apy: u128 // fixed-point raw value
    }

    #[event]
    struct MintEvent has drop, store {
        vault_name: String,
        vault_apy: u128,
        maturity_time: u64,
        current_time: u64,
        apt_in: u64,
        pt_out: u64,
        sender: address
    }

    #[event]
    struct RequestRedeem has drop, store {
        vault_name: String,
        current_time: u64,
        pt_amount: u64,
        sender: address
    }

    #[event]
    struct RequestExit has drop, store {
        vault_name: String,
        current_time: u64,
        pt_amount: u64,
        exit_amount: u64,
        sender: address
    }

    #[event]
    struct Withdrawn has drop, store {
        withdraw_amount: u64,
        requester: address
    }

    // constructor
    fun init_module(sender: &signer) {

        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        move_to(sender, VaultManager { 
            delegator_pools: smart_vector::new<address>(), 
            vault_list: smart_vector::new<String>(),
            vault_config: table::new<String, VaultConfig>(),
            extend_ref, 
            pending_stake: 0,
            unlocked_amount: 0,
            pending_unstake: table::new<address, u64>(),
            pending_withdrawal: table::new<address, u64>(),
            requesters: smart_vector::new<address>(), 
            batch_amount: DEFAULT_BATCH_AMOUNT,
            exit_fee: fixed_point64::create_from_raw_value(DEFAULT_EXIT_FEE)
        });
    }

    // ======== Public Functions =========

    // Convert APT into future PT tokens equivalent to the value at the maturity date.
    public entry fun mint<P>(sender: &signer, input_amount: u64) acquires VaultReserve, VaultManager {
        assert!(exists<VaultReserve<P>>(@legato_addr), ERR_INVALID_VAULT);
        assert!(coin::balance<AptosCoin>(signer::address_of(sender)) >= MIN_APT_TO_STAKE, ERR_MIN_THRESHOLD);

        let type_name = type_info::type_name<P>();

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);

        let vault_config = table::borrow_mut( &mut config.vault_config, type_name );        
        let vault_reserve = borrow_global_mut<VaultReserve<P>>(@legato_addr); 
        
        // Ensure that the vault has not yet matured
        assert!(vault_config.maturity_time > timestamp::now_seconds() , ERR_VAULT_MATURED); 

        // attaches to object 
        let input_coin = coin::withdraw<AptosCoin>(sender, input_amount);
        if (!coin::is_account_registered<AptosCoin>(signer::address_of(&config_object_signer))) {
            coin::register<AptosCoin>(&config_object_signer);
        };

        coin::deposit(signer::address_of(&config_object_signer), input_coin);

        // Update the pending stake amount 
        config.pending_stake = config.pending_stake+input_amount;

        let vault_apy: FixedPoint64 = vault_config.vault_apy;
        let maturity_time: u64 = vault_config.maturity_time;

        // Calculate the amount of PT tokens to be sent out 
        let pt_amount = calculate_pt_debt_amount( vault_apy, timestamp::now_seconds(), maturity_time, input_amount );

        // Mint PT tokens and deposit them into the sender's account
        let pt_coin = coin::mint<PT_TOKEN<P>>(pt_amount, &vault_reserve.pt_mint); 
        if (!coin::is_account_registered<PT_TOKEN<P>>(signer::address_of(sender))) {
            coin::register<PT_TOKEN<P>>(sender);
        };
        coin::deposit(signer::address_of(sender), pt_coin);

        // Update 
        vault_reserve.pt_total_supply = vault_reserve.pt_total_supply+pt_amount;

        transfer_stake();

        // Emit an event 
        event::emit(
            MintEvent {
                vault_name: type_name,
                vault_apy:  fixed_point64::get_raw_value(vault_apy),
                maturity_time,
                current_time: timestamp::now_seconds(),
                apt_in: input_amount,
                pt_out: pt_amount,
                sender: signer::address_of(sender)
            }
        )
    }

    // Check if the APT in pending_stake meets the BATCH_AMOUNT, then use it to stake on a randomly supported validator.
    public entry fun transfer_stake() acquires VaultManager {
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        if (config.pending_stake >= config.batch_amount) { 
            
            let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);

            let validator_index = timestamp::now_seconds() % smart_vector::length( &config.delegator_pools );
            let validator_address = *smart_vector::borrow( &config.delegator_pools, validator_index );
            let pool_address = dp::get_owned_pool_address(validator_address);
            dp::add_stake(&config_object_signer, pool_address, config.pending_stake);

            config.pending_stake = 0;
 
        };
    }

    // request redeem when the vault reaches its maturity date
    public entry fun request_redeem<P>( sender: &signer, amount: u64 ) acquires VaultReserve, VaultManager {
        assert!(exists<VaultReserve<P>>(@legato_addr), ERR_INVALID_VAULT);

        let type_name = type_info::type_name<P>();

        let config = borrow_global_mut<VaultManager>(@legato_addr);

        let vault_config = table::borrow_mut( &mut config.vault_config, type_name );        
        let vault_reserve = borrow_global_mut<VaultReserve<P>>(@legato_addr); 

        // Check if the vault has matured
        assert!(timestamp::now_seconds() > vault_config.maturity_time, ERR_VAULT_NOT_MATURED);

        // Burn PT tokens on the sender's account
        let pt_coin = coin::withdraw<PT_TOKEN<P>>(sender, amount);
        coin::burn(pt_coin, &vault_reserve.pt_burn);

        // Add the request to the withdrawal list
        table::add(
            &mut config.pending_unstake,
            signer::address_of(sender),
            amount
        );

        if ( !smart_vector::contains(&config.requesters, &(signer::address_of(sender))) ) {
            smart_vector::push_back(&mut config.requesters, signer::address_of(sender));
        };

        // Update
        vault_reserve.pt_total_supply = vault_reserve.pt_total_supply-amount;
 
        // Emit an event 
        event::emit(
            RequestRedeem {
                vault_name: type_name, 
                current_time: timestamp::now_seconds(), 
                pt_amount: amount,
                sender: signer::address_of(sender)
            }
        )
    }

    // request exit when the vault is not matured, the amount returned 
    // - APT = PT / e^(rt) - exit fee%
    public entry fun request_exit<P>(sender: &signer, amount: u64 ) acquires VaultReserve, VaultManager {
        assert!(exists<VaultReserve<P>>(@legato_addr), ERR_INVALID_VAULT);

        let type_name = type_info::type_name<P>();

        let config = borrow_global_mut<VaultManager>(@legato_addr);

        let vault_config = table::borrow_mut( &mut config.vault_config, type_name );        
        let vault_reserve = borrow_global_mut<VaultReserve<P>>(@legato_addr); 

        assert!(vault_config.maturity_time > timestamp::now_seconds() , ERR_VAULT_MATURED);

        // Burn PT tokens on the sender's account
        let pt_coin = coin::withdraw<PT_TOKEN<P>>(sender, amount);
        coin::burn(pt_coin, &vault_reserve.pt_burn);

        let adjusted_amount = calculate_exit_amount(vault_config.vault_apy, timestamp::now_seconds(), vault_config.maturity_time, amount);

        // Add the request to the withdrawal list
        table::add(
            &mut config.pending_unstake,
            signer::address_of(sender),
            adjusted_amount
        );

        if ( !smart_vector::contains(&config.requesters, &(signer::address_of(sender))) ) {
            smart_vector::push_back(&mut config.requesters, signer::address_of(sender));
        };

        // Update
        vault_reserve.pt_total_supply = vault_reserve.pt_total_supply-amount;

        // Emit an event 
        event::emit(
            RequestExit {
                vault_name: type_name, 
                current_time: timestamp::now_seconds(), 
                pt_amount: amount,
                exit_amount: adjusted_amount,
                sender: signer::address_of(sender)
            }
        )
    }

    // Calculate the amount of PT debt to be sent out using the formula P = S * e^(rt)
    public fun calculate_pt_debt_amount(apy: FixedPoint64, from_timestamp: u64, to_timestamp: u64, input_amount: u64): u64 {
        
        // Calculate time duration in years
        let time = fixed_point64::create_from_rational( ((to_timestamp-from_timestamp) as u128), 31556926 );

        // Calculate rt (rate * time)
        let rt = math_fixed64::mul_div( apy, time, fixed_point64::create_from_u128(1));
        let multiplier = math_fixed64::exp(rt);

        // the final PT debt amount
        ( fixed_point64::multiply_u128( (input_amount as u128), multiplier  ) as u64 )
    }

    // Calculate the amount when exiting using the formula S = P / e^(rt
    public fun calculate_exit_amount(apy: FixedPoint64, from_timestamp: u64, to_timestamp: u64, output_amount: u64) : u64 {

        let time = fixed_point64::create_from_rational( ((to_timestamp-from_timestamp) as u128), 31556926 );

        let rt = math_fixed64::mul_div( apy, time, fixed_point64::create_from_u128(1));
        let denominator = math_fixed64::exp(rt);

        ( fixed_point64::divide_u128( (output_amount as u128), denominator  ) as u64 )
    }

    #[view]
    // get PT balance from the given account
    public fun get_pt_balance<P>(account: address): u64 {
        coin::balance<PT_TOKEN<P>>(account)
    }

    #[view]
    public fun get_config_object_address() : address  acquires VaultManager  {
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        signer::address_of(&config_object_signer)
    }

    // ======== Only Governance =========

    // Create a new vault
    public entry fun new_vault<P>(
        sender: &signer, 
        maturity_time: u64,
        apy_numerator: u128,
        apy_denominator: u128
    ) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        // Check if the vault already exists 
        assert!(!vault_exist<P>(@legato_addr), ERR_VAULT_EXISTS);
        // The maturity date should not have passed.
        assert!(maturity_time > timestamp::now_seconds()+86400, ERR_INVALID_MATURITY);
        // Ensure the current maturity date is greater than that of the previous vault.
        assert_maturity_time<P>(@legato_addr, maturity_time);

        let config = borrow_global_mut<VaultManager>(@legato_addr);

        // Construct the name and symbol of the PT token
        let type_name = type_info::type_name<P>();
        let index = string::index_of(&type_name, &utf8(b"vault_token_name::"));
        assert!(index != string::length(&type_name) , ERR_INVALID_TYPE );
        let token_name = string::utf8(b"PT-");
        let token_symbol =  string::sub_string( &type_name, index+18, string::length(&type_name));
        string::append( &mut token_name, token_symbol);

        // Initialize vault's PT token 
        let (pt_burn, freeze_cap, pt_mint) = coin::initialize<PT_TOKEN<P>>(
            sender,
            token_name,
            token_symbol,
            8, // Number of decimal places
            true, // token is fungible
        );

        coin::destroy_freeze_cap(freeze_cap);

        let vault_apy = fixed_point64::create_from_rational( apy_numerator, apy_denominator );

        let vault_config = VaultConfig { 
            maturity_time,
            vault_apy,
            enable_mint: true,
            enable_redeem: true,
            enable_exit: true
        };

        move_to(
            sender,
            VaultReserve<P> {
                pt_mint,
                pt_burn, 
                pt_total_supply: 0
            },
        );

        // Add the vault name to the list.
        smart_vector::push_back(&mut config.vault_list, type_name);

        // Add the configuration to the config table.
        table::add(
            &mut config.vault_config,
            type_name,
            vault_config
        );

        // Emit an event 
        event::emit(
            NewVault {
                vault_name: type_name,
                maturity_time,
                vault_apy: fixed_point64::get_raw_value(vault_apy)
            }
        )

    }

    // Update the batch amount for staking.
    public entry fun update_batch_amount(sender: &signer, new_amount: u64) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        config.batch_amount = new_amount;
    }

    // Add a validator to the whitelist.
    public entry fun add_whitelist(sender: &signer, whitelist_address: address) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        smart_vector::push_back(&mut config.delegator_pools, whitelist_address);
    }

    // Remove a validator from the whitelist.
    public entry fun remove_whitelist(sender: &signer, whitelist_address: address) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let (found, idx) = smart_vector::index_of<address>(&config.delegator_pools, &whitelist_address);
        assert!(  found , ERR_INVALID_ADDRESS);
        smart_vector::swap_remove<address>(&mut config.delegator_pools, idx );
    }

    // Admin proceeds to unlock APT for further withdrawal according to the request table.
    public entry fun admin_proceed_unstake(sender: &signer, validator_address: address) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let total_requester = smart_vector::length( &config.requesters );
        
        if (total_requester > 0) {

            let requester_count = 0;
            let total_unlock = 0;

            while ( requester_count < total_requester) {
                let requester_address = *smart_vector::borrow( &config.requesters, requester_count );
                let unlock_amount = table::remove( &mut config.pending_unstake, requester_address);

                if (unlock_amount > 0) {
                    table::add(
                        &mut config.pending_withdrawal,
                        requester_address,
                        unlock_amount
                    );

                    total_unlock = total_unlock+unlock_amount;
                };

                requester_count = requester_count+1;
            };

            let pool_address = dp::get_owned_pool_address(validator_address);
            dp::unlock(&config_object_signer, pool_address, total_unlock);

            config.unlocked_amount = config.unlocked_amount + total_unlock;
        };
        
    }

    // Admin proceeds with withdrawal of unlocked APT tokens.
    public entry fun admin_proceed_withdrawal(sender: &signer,  validator_address: address) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        
        // Proceed with withdrawal if there are unlocked tokens.
        if ( config.unlocked_amount > 0) {

            // Withdraw the unlocked APT tokens from the delegation pool.
            let pool_address = dp::get_owned_pool_address(validator_address);
            dp::withdraw(&config_object_signer, pool_address, config.unlocked_amount);

            // Retrieve the total withdrawn APT tokens.
            let total_apt_withdrawn = coin::balance<AptosCoin>(  signer::address_of(&config_object_signer)  );

            let total_requester = smart_vector::length( &config.requesters );
            let requester_count = 0;

            // Loop through each requester and process their withdrawal.
            while ( requester_count < total_requester) {
                let requester_address = *smart_vector::borrow( &config.requesters, requester_count );
                let withdraw_amount = table::remove( &mut config.pending_withdrawal, requester_address);

                if (withdraw_amount > 0) {
                    // Ensure withdrawal amount does not exceed the available balance.
                    if (withdraw_amount > total_apt_withdrawn) {
                        withdraw_amount = total_apt_withdrawn;
                    };
                   let apt_coin = coin::withdraw<AptosCoin>(&config_object_signer, withdraw_amount);
                   coin::deposit(requester_address, apt_coin);

                    // Emit an event 
                    event::emit(
                        Withdrawn {
                            withdraw_amount,
                            requester: requester_address
                        }
                    );

                };

                requester_count = requester_count+1;
            };

             // Reset the unlocked amount after processing withdrawals.
            config.unlocked_amount = 0;
        };

    }


    // ======== Internal Functions =========

    fun vault_exist<P>(addr: address): bool {
        exists<VaultReserve<P>>(addr)
    }

    fun assert_maturity_time<P>(addr: address, maturity_time: u64) acquires VaultManager {

        let global_config = borrow_global_mut<VaultManager>(addr);
        if ( smart_vector::length( &global_config.vault_list ) > 0) { 
            let recent_vault_name = *smart_vector::borrow( &global_config.vault_list, smart_vector::length( &global_config.vault_list )-1 );
            let recent_vault_config = table::borrow_mut( &mut global_config.vault_config, recent_vault_name );
            assert!(  maturity_time > recent_vault_config.maturity_time, ERR_INVALID_MATURITY  );
        };

    }
 
    #[test_only]
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}