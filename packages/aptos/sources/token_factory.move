// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// The token factory allows anyone to create their own FA token
// Only the owner of the token can perform mint and burn operaions
// For future use in AMM and LBP systems

module legato_addr::token_factory {

    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleStore};
    use aptos_framework::object::{Self, Object, ExtendRef};

    use std::vector;

    use legato_addr::base_fungible_asset;

    use std::signer;
    use std::string::{String, utf8};

    // ======== Constants ========

    // ======== Errors ========

    const ERR_INVALID_DECIMALS: u64 = 1;
    const ERR_INVALID_ID: u64 = 2;
    const ERR_UNAUTHORIZED: u64 = 3;

    // ======== Structs =========

    struct Token has store {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        metadata: Object<Metadata>,
        owner: address
    }

    struct TokenFactory has key {
        tokens: vector<Token>,
        token_count: u64
    }

    // Constructor
    fun init_module(sender: &signer) {
        
        let constructor_ref = object::create_object(signer::address_of(sender));
        // let extend_ref = object::generate_extend_ref(&constructor_ref);

        move_to(sender, TokenFactory {
            token_count: 0,
            tokens: vector::empty<Token>()
        });
    
    }

    public entry fun deploy_new_token(
        sender: &signer,
        token_name: String,
        token_symbol: String,
        maximum_supply: u128, // 0 means no maximum
        decimals: u8,
        icon_uri: String,
        project_uri: String
    ) acquires TokenFactory {
        assert!( decimals > 1 && decimals <= 8, ERR_INVALID_DECIMALS );

        let token_factory = borrow_global_mut<TokenFactory>(@legato_addr);
        let constructor_ref = &object::create_sticky_object(signer::address_of(sender));

        base_fungible_asset::initialize(
            constructor_ref,
            maximum_supply, /* maximum_supply. 0 means no maximum */
            token_name, /* name */
            token_symbol, /* symbol */
            decimals, /* decimals */
            icon_uri, /* icon */
            project_uri, /* project */
        );

        let token = Token {
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref), 
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            metadata : object::object_from_constructor_ref<Metadata>(constructor_ref),
            owner: signer::address_of(sender)
        };

        vector::push_back(&mut token_factory.tokens, token);

        token_factory.token_count = token_factory.token_count+1;
    }

    // Mint FA tokens if you are the owner
    public entry fun mint( sender: &signer, id: u64,  to: address, amount: u64) acquires TokenFactory {
        assert!( is_owner(sender, id), ERR_UNAUTHORIZED );
        base_fungible_asset::mint_to_primary_stores( token_metadata_from_id(id), vector[to], vector[amount]);
    }


    // Burn FA tokens
    public entry fun burn( sender: &signer, id: u64, from: address, amount: u64) acquires TokenFactory {
        assert!( is_owner(sender, id), ERR_UNAUTHORIZED );
        base_fungible_asset::burn_from_primary_stores(  token_metadata_from_id(id), vector[from], vector[amount]);
    }

    #[view]
    public fun token_count(): u64 acquires TokenFactory {
        let token_factory = borrow_global_mut<TokenFactory>(@legato_addr);
        token_factory.token_count
    }

    #[view]
    public fun token_metadata_from_id(id: u64): Object<Metadata> acquires TokenFactory  { 
        let token_factory = borrow_global_mut<TokenFactory>(@legato_addr);
        assert!( token_factory.token_count > id , ERR_INVALID_ID);
        let token = vector::borrow( &token_factory.tokens, id );
        token.metadata
    }

    #[view]
    public fun all_token_metadata(): vector<Object<Metadata>> acquires TokenFactory {
        let token_factory = borrow_global_mut<TokenFactory>(@legato_addr);
        let count = 0;
        let output = vector::empty();
        while (count < vector::length(&token_factory.tokens)) {
            let token = vector::borrow( &token_factory.tokens, count );
            vector::push_back( &mut output, token.metadata );
            count = count+1;
        };
        output
    }   

    #[view]
    public fun token_metadata_from_address(owner: address): vector<Object<Metadata>> acquires TokenFactory {
        let token_factory = borrow_global_mut<TokenFactory>(@legato_addr);
        let count = 0;
        let output = vector::empty();
        while (count < vector::length(&token_factory.tokens)) {
            let token = vector::borrow( &token_factory.tokens, count );
            if ( token.owner == owner ) {
                vector::push_back( &mut output, token.metadata );
            };
            count = count+1;
        };
        output
    }

    fun is_owner(sender: &signer, id: u64): bool acquires TokenFactory {
        let token_factory = borrow_global_mut<TokenFactory>(@legato_addr);
        let token = vector::borrow( &token_factory.tokens, id );
        if (token.owner == signer::address_of(sender)) {
            true
        } else {
            false
        }
    }

    #[test_only]
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}