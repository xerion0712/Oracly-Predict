
// Mock Legato coins 

module legato_addr::mock_usdc {

    use std::signer;
    use std::string::{Self };  

    use aptos_framework::coin::{Self, MintCapability, BurnCapability}; 

    const TOKEN_NAME: vector<u8> = b"USDC Token";

    struct USDC_TOKEN has drop, store {}

    struct MockManager has key {
        mint_cap: MintCapability<USDC_TOKEN>,
        burn_cap: BurnCapability<USDC_TOKEN>
    }

    fun init_module(sender: &signer) {

        let token_name = string::utf8(b"USDC Token");
        let token_symbol = string::utf8(b"USDC");

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<USDC_TOKEN>(sender, token_name, token_symbol, 6, true);
        coin::destroy_freeze_cap(freeze_cap);

        move_to( sender, MockManager { 
            mint_cap,
            burn_cap
        });
    }

    public entry fun mint(sender: &signer , amount: u64) acquires MockManager {
        let mock_manager = borrow_global_mut<MockManager>(@legato_addr);
        let coins = coin::mint<USDC_TOKEN>(amount, &mock_manager.mint_cap );

        let sender_address = signer::address_of(sender);

        if (!coin::is_account_registered<USDC_TOKEN>(sender_address)) {
            coin::register<USDC_TOKEN>(sender);
        };
        coin::deposit(sender_address, coins);
    }

    public entry fun burn(sender: &signer, amount: u64)  acquires MockManager {
        let mock_manager = borrow_global_mut<MockManager>(@legato_addr);

        let burn_coin = coin::withdraw<USDC_TOKEN>(sender, amount);
        coin::burn(burn_coin, &mock_manager.burn_cap);
    }

    // ======== Test-related Functions =========

    #[test_only] 
    public fun init_module_for_testing(sender: &signer) {
        init_module(sender)
    }

}