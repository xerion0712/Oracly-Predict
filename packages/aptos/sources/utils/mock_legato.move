
// Mock Legato coins 

module legato_addr::mock_legato {

    use std::signer;
    use std::string::{Self, String };  

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability}; 

    const TOKEN_NAME: vector<u8> = b"Legato Token";

    struct LEGATO_TOKEN has drop, store {}

    struct MockManager has key {
        mint_cap: MintCapability<LEGATO_TOKEN>,
        burn_cap: BurnCapability<LEGATO_TOKEN>
    }

    fun init_module(sender: &signer) {

        let token_name = string::utf8(b"Legato Token");
        let token_symbol = string::utf8(b"LEGATO");

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LEGATO_TOKEN>(sender, token_name, token_symbol, 8, true);
        coin::destroy_freeze_cap(freeze_cap);

        move_to( sender, MockManager { 
            mint_cap,
            burn_cap
        });
    }

    public entry fun mint(sender: &signer , amount: u64) acquires MockManager {
        let mock_manager = borrow_global_mut<MockManager>(@legato_addr);
        let coins = coin::mint<LEGATO_TOKEN>(amount, &mock_manager.mint_cap );

        let sender_address = signer::address_of(sender);

        if (!coin::is_account_registered<LEGATO_TOKEN>(sender_address)) {
            coin::register<LEGATO_TOKEN>(sender);
        };
        coin::deposit(sender_address, coins);
    }

    public entry fun burn(sender: &signer, amount: u64)  acquires MockManager {
        let mock_manager = borrow_global_mut<MockManager>(@legato_addr);

        let burn_coin = coin::withdraw<LEGATO_TOKEN>(sender, amount);
        coin::burn(burn_coin, &mock_manager.burn_cap);
    }

    // ======== Test-related Functions =========

    #[test_only] 
    public fun init_module_for_testing(sender: &signer) {
        init_module(sender)
    }

    // #[test(deployer = @legato_addr, alice = @0x1234)]
    // public fun test_basic_flow(deployer: &signer, alice: &signer) {
    //     init_module(deployer);

    //     let alice_address = signer::address_of(alice); 

    //     account::create_account_for_test(alice_address);   

    //     mint(alice, 1000);
    //     assert!(coin::balance<LEGATO_TOKEN>(alice_address) == 1000 , 0);

    // }

}