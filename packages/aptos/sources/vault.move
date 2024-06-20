// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// A timelock vault to convert APT into future value including yield tokenization for general purposes. 
// Each vault maintains its own tokens and adheres to a quarterly expiration schedule.

module legato_addr::vault {

    use std::signer;  
    use std::string::{Self, String, utf8, bytes};

    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::fungible_asset::{ Self, Metadata, MintRef, BurnRef };
    use aptos_framework::primary_fungible_store::{Self};
    use aptos_framework::delegation_pool as dp;
    use aptos_framework::coin::{Self}; 

    use aptos_std::smart_vector::{Self, SmartVector};
    use aptos_std::type_info::{Self};   
    use aptos_std::fixed_point64::{Self, FixedPoint64};
    use aptos_std::math_fixed64::{Self};
    use aptos_std::table::{Self, Table};

    use legato_addr::base_fungible_asset;
    use legato_addr::legato_lib::{generate_vault_name_and_symbol, calculate_pt_debt_amount, calculate_exit_amount};

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
    const ERR_INSUFFICIENT_AMOUNT: u64 = 110;
    const ERR_DISABLED: u64 = 111;
    const ERR_TOO_LARGE: u64 = 112;
    const ERR_INVALID_MULTIPLIER: u64 = 113;

    // ======== Structs =========

    struct VaultConfig has store {
        maturity_time: u64,
        vault_apy: FixedPoint64, // Vault's APY based on the average rate 
        pt_total_supply: u64,  // Total supply of PT tokens
        mint_ref: MintRef,
        metadata: Object<Metadata>,
        burn_ref: BurnRef,
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
        unlocked_amount: u64,
        pending_unstake: Table<address, u64>,
        requesters: SmartVector<address>, 
        batch_amount: u64,
        exit_fee: FixedPoint64,
        enable_auto_stake: bool // Stake APT from the pool when batch amount is reached
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
            requesters: smart_vector::new<address>(),
            batch_amount: DEFAULT_BATCH_AMOUNT,  
            exit_fee: fixed_point64::create_from_raw_value(DEFAULT_EXIT_FEE),
            enable_auto_stake: true
        });
    
    }

    // ======== Public Functions =========

    // Convert APT into future PT tokens equivalent to the value at the maturity date.
    public entry fun mint<P>(sender: &signer, input_amount: u64) acquires VaultManager {
        assert!(coin::balance<AptosCoin>(signer::address_of(sender)) >= MIN_APT_TO_STAKE, ERR_MIN_THRESHOLD);

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        assert!(vault_exist<P>(config), ERR_INVALID_VAULT);

        let type_name = type_info::type_name<P>();
        let vault_config = table::borrow_mut( &mut config.vault_config, type_name );

        assert!( vault_config.enable_mint == true, ERR_DISABLED);

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
        base_fungible_asset::mint_to_primary_stores( vault_config.metadata, vector[signer::address_of(sender)], vector[pt_amount]);

        // Update
        vault_config.pt_total_supply = vault_config.pt_total_supply+pt_amount;

        if (config.enable_auto_stake == true) {
            transfer_stake();
        };

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
    public entry fun request_redeem<P>( sender: &signer, amount: u64 ) acquires VaultManager {
        
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        assert!(vault_exist<P>(config), ERR_INVALID_VAULT);

        let type_name = type_info::type_name<P>();
        let vault_config = table::borrow_mut( &mut config.vault_config, type_name );

        assert!( vault_config.enable_redeem == true, ERR_DISABLED);

        assert!( primary_fungible_store::balance( signer::address_of(sender) , vault_config.metadata ) >= amount , ERR_INSUFFICIENT_AMOUNT );

        // Check if the vault has matured
        assert!(timestamp::now_seconds() > vault_config.maturity_time, ERR_VAULT_NOT_MATURED);

        // Burn PT tokens on the sender's account
        base_fungible_asset::burn_from_primary_stores(vault_config.metadata, vector[signer::address_of(sender)], vector[amount]);

        // Add the request to the withdrawal list
        if (!table::contains(&config.pending_unstake, signer::address_of(sender))) { 
            table::add(
                &mut config.pending_unstake,
                signer::address_of(sender),
                amount
            );
        } else {
            *table::borrow_mut( &mut config.pending_unstake, signer::address_of(sender) ) = *table::borrow( &config.pending_unstake, signer::address_of(sender) )+amount;
        };

        if ( !smart_vector::contains(&config.requesters, &(signer::address_of(sender))) ) {
            smart_vector::push_back(&mut config.requesters, signer::address_of(sender));
        };

        // Update
        vault_config.pt_total_supply = vault_config.pt_total_supply-amount;
 
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
    public entry fun request_exit<P>(sender: &signer, amount: u64 ) acquires VaultManager {
        
        let config = borrow_global_mut<VaultManager>(@legato_addr); 
        assert!(vault_exist<P>(config), ERR_INVALID_VAULT);

        let type_name = type_info::type_name<P>();
        let vault_config = table::borrow_mut( &mut config.vault_config, type_name );

        assert!( primary_fungible_store::balance( signer::address_of(sender) , vault_config.metadata ) >= amount , ERR_INSUFFICIENT_AMOUNT );

        assert!( vault_config.enable_exit == true, ERR_DISABLED);
        assert!(vault_config.maturity_time > timestamp::now_seconds() , ERR_VAULT_MATURED);

        // Burn PT tokens on the sender's account
        base_fungible_asset::burn_from_primary_stores(vault_config.metadata, vector[signer::address_of(sender)], vector[amount]);

        let adjusted_amount = calculate_exit_amount(vault_config.vault_apy, timestamp::now_seconds(), vault_config.maturity_time, amount);

        // Add the request to the withdrawal list 
        if (!table::contains(&config.pending_unstake, signer::address_of(sender))) { 
            table::add(
                &mut config.pending_unstake,
                signer::address_of(sender),
                adjusted_amount
            );
        } else {
            *table::borrow_mut( &mut config.pending_unstake, signer::address_of(sender) ) = *table::borrow( &config.pending_unstake, signer::address_of(sender) )+adjusted_amount; 
        };

        if (!smart_vector::contains(&config.requesters, &(signer::address_of(sender))) ) {
            smart_vector::push_back(&mut config.requesters, signer::address_of(sender));
        };

        // Update
        vault_config.pt_total_supply = vault_config.pt_total_supply-amount;

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

    #[view]
    public fun get_config_object_address(): address acquires VaultManager {
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        signer::address_of(&config_object_signer)
    }

    // Return the address of vault's token metadata
    #[view]
    public fun get_vault_metadata<P>(): Object<Metadata> acquires VaultManager {
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let vault_config = table::borrow_mut( &mut config.vault_config, type_info::type_name<P>() );
        vault_config.metadata
    }

    // Return the total unstake request amount
    #[view]
    public fun get_total_unstake_request(): u64 acquires VaultManager {

        let output = 0;

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let total_requester = smart_vector::length( &config.requesters );

        if (total_requester > 0) {

            let requester_count = 0;
            let total_unlock = 0;

            while ( requester_count < total_requester) {
                let requester_address = *smart_vector::borrow( &config.requesters, requester_count );
                output = output+*table::borrow( &config.pending_unstake, requester_address  );
                requester_count = requester_count+1;
            };

        };

        output
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

        let config = borrow_global_mut<VaultManager>(@legato_addr);

        // Check if the vault already exists 
        assert!(!vault_exist<P>(config), ERR_VAULT_EXISTS);
        // The maturity date should not have passed.
        assert!(maturity_time > timestamp::now_seconds()+86400, ERR_INVALID_MATURITY);
        // Ensure the current maturity date is greater than that of the previous vault.
        assert_maturity_time<P>(config, maturity_time);

        let (token_name, token_symbol) = generate_vault_name_and_symbol<P>();
    
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);

        // Initialize vault's PT token 
        let constructor_ref = &object::create_named_object(&config_object_signer, type_info::struct_name(&type_info::type_of<P>()) );
        
        base_fungible_asset::initialize(
            constructor_ref,
            0, /* maximum_supply. 0 means no maximum */
            token_name, /* name */
            token_symbol, /* symbol */
            8, /* decimals */
            utf8(b"https://www.legato.finance/assets/images/favicon.ico"), /* icon */
            utf8(b"https://legato.finance"), /* project */
        );

        let vault_apy = fixed_point64::create_from_rational( apy_numerator, apy_denominator );

        let vault_config = VaultConfig { 
            maturity_time,
            vault_apy,
            pt_total_supply: 0,
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref), 
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            metadata : object::object_from_constructor_ref<Metadata>(constructor_ref),
            enable_mint: true,
            enable_redeem: true,
            enable_exit: true
        };

        // Add the vault name to the list.
        let type_name = type_info::type_name<P>();
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

    // Enable/Disable auto stake
    public entry fun enable_auto_stake(sender: &signer, is_enable: bool) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        config.enable_auto_stake = is_enable;
    }

    // Enable/Disable minting vault tokens
    public entry fun enable_mint<P>(sender: &signer, is_enable: bool) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        assert!(vault_exist<P>(config), ERR_INVALID_VAULT);

        let vault_config = table::borrow_mut( &mut config.vault_config, type_info::type_name<P>() );
        vault_config.enable_mint = is_enable;
    }

    // Enable/Disable redeeming vault tokens
    public entry fun enable_redeem<P>(sender: &signer, is_enable: bool) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        assert!(vault_exist<P>(config), ERR_INVALID_VAULT);

        let vault_config = table::borrow_mut( &mut config.vault_config, type_info::type_name<P>() );
        vault_config.enable_redeem = is_enable;
    } 

    // Enable/Disable exiting the position  
    public entry fun enable_exit<P>(sender: &signer, is_enable: bool) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        let config = borrow_global_mut<VaultManager>(@legato_addr);
        assert!(vault_exist<P>(config), ERR_INVALID_VAULT);

        let vault_config = table::borrow_mut( &mut config.vault_config, type_info::type_name<P>() );
        vault_config.enable_exit = is_enable;
    } 

    // Withdraw APT from the pool and perform staking manually by admin.
    public entry fun admin_withdraw_pending_stake(sender: &signer, withdraw_amount: u64) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let global_config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&global_config.extend_ref);

        assert!( global_config.pending_stake >=  withdraw_amount, ERR_INSUFFICIENT_AMOUNT);

        let apt_coin = coin::withdraw<AptosCoin>(&config_object_signer, withdraw_amount);
        coin::deposit(signer::address_of(sender), apt_coin);
        
        global_config.pending_stake = global_config.pending_stake - withdraw_amount;
    }

    // Admin proceeds to unlock APT for further withdrawal.
    public entry fun admin_proceed_unlock(sender: &signer, unlock_amount: u64) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let total_delegators = smart_vector::length(&config.delegator_pools);
    
        let delegator_count = 0;
        let remaining_unlock = unlock_amount;

        while ( delegator_count < total_delegators) {

            let delegator_address = *smart_vector::borrow( &config.delegator_pools, delegator_count );
            let pool_address = dp::get_owned_pool_address(delegator_address); 

            let (staked_amount,_,_) = dp::get_stake( pool_address, signer::address_of( &config_object_signer ) );
            
            if (remaining_unlock != 0 && staked_amount > 0) {
                let amount_to_unlock = if (staked_amount >= remaining_unlock) {
                    remaining_unlock
                } else {
                    staked_amount
                };
                remaining_unlock = remaining_unlock-amount_to_unlock;
                dp::unlock(&config_object_signer, pool_address, amount_to_unlock);
            };

            delegator_count = delegator_count+1;
        };

        assert!( remaining_unlock == 0, ERR_TOO_LARGE );
    }

    // Admin proceeds to unstake APT from the respective validator pool
    public entry fun admin_proceed_unstake(sender: &signer, unstake_amount: u64) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        let total_delegators = smart_vector::length(&config.delegator_pools);

        let delegator_count = 0;
        let remaining_withdraw = unstake_amount;

        while ( delegator_count < total_delegators) {
        
            let delegator_address = *smart_vector::borrow( &config.delegator_pools, delegator_count );
            let pool_address = dp::get_owned_pool_address(delegator_address); 

            let (_,inactive_amount,_) = dp::get_stake( pool_address, signer::address_of( &config_object_signer ) );

            if (remaining_withdraw != 0 && inactive_amount > 0) {
                let amount_to_withdraw = if (inactive_amount >= remaining_withdraw) {
                    remaining_withdraw
                } else {
                    inactive_amount
                };
                remaining_withdraw = remaining_withdraw-amount_to_withdraw;
                dp::withdraw(&config_object_signer, pool_address, amount_to_withdraw);
            };
        
            delegator_count = delegator_count+1;
        };
    
        assert!( remaining_withdraw == 0, ERR_TOO_LARGE );
    }

    // Admin transfers APT to requesters per the withdrawal amounts they want sent out
    public entry fun admin_proceed_withdrawal(sender: &signer, withdraw_amount: u64, multiplier: u128) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);
        assert!( 10000 >= multiplier, ERR_INVALID_MULTIPLIER );

        let config = borrow_global_mut<VaultManager>(@legato_addr);
        let config_object_signer = object::generate_signer_for_extending(&config.extend_ref);
        
        let total_requester = smart_vector::length( &config.requesters ); 
        let requester_count = 0;
        let remaining_withdraw = withdraw_amount;

        // Loop through each requester and process their withdrawal.
        while ( requester_count < total_requester) {
            let requester_address = *smart_vector::borrow( &config.requesters, requester_count );
            let withdraw_amount = *table::borrow( &config.pending_unstake, requester_address );

            if (withdraw_amount > 0) {
                let sendout_amount = ( fixed_point64::multiply_u128( (withdraw_amount as u128), fixed_point64::create_from_rational( multiplier, 10000 ) ) as u64 );
                let current_apt_balance = coin::balance<AptosCoin>(  signer::address_of(&config_object_signer)  );

                if ( current_apt_balance >= sendout_amount && remaining_withdraw >= sendout_amount) {
                    let apt_coin = coin::withdraw<AptosCoin>(&config_object_signer, sendout_amount);
                    coin::deposit(requester_address, apt_coin);

                    // Emit an event 
                    event::emit(
                        Withdrawn {
                            withdraw_amount: sendout_amount,
                            requester: requester_address
                        }
                    );

                    *table::borrow_mut(&mut config.pending_unstake, requester_address) = 0;

                    remaining_withdraw = remaining_withdraw - sendout_amount;
                };

            };

            requester_count = requester_count+1;
        };

    } 

    // Admin updates the request table on a emergency case
    public entry fun admin_update_request_table(sender: &signer, requester: address, new_amount: u64) acquires VaultManager {
        assert!( signer::address_of(sender) == @legato_addr , ERR_UNAUTHORIZED);

        let config = borrow_global_mut<VaultManager>(@legato_addr); 
        *table::borrow_mut(&mut config.pending_unstake, requester) = new_amount;
    }

    // ======== Internal Functions =========

    fun vault_exist<P>(global_config: &VaultManager): bool { 
        let type_name = type_info::type_name<P>(); 
        table::contains( &global_config.vault_config, type_name)
    }

    fun assert_maturity_time<P>(global_config: &mut VaultManager, maturity_time: u64) {
 
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