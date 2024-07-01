// Test Token Factory Module

#[test_only]
module legato_addr::token_factory_tests {

    use legato_addr::token_factory;

    use aptos_framework::primary_fungible_store;
    use std::signer;
    use std::string::utf8;

    #[test(deployer = @legato_addr, creator = @0xface, alice = @1234)]
    fun test_basic_flow(deployer: &signer, creator: &signer, alice: &signer) {

        token_factory::init_module_for_testing(deployer);

        let creator_address = signer::address_of(creator);
        let alice_address = signer::address_of(alice); 

        token_factory::deploy_new_token(
            creator,
            utf8(b"Mock USDC Tokens"),
            utf8(b"USDC"),
            0,
            6,
            utf8(b"http://example.com/favicon.ico"),
            utf8(b"http://example.com")
        );

        token_factory::mint( creator, 0, signer::address_of(creator), 1000 );
        let metadata = token_factory::token_metadata_from_id(0);
        assert!(primary_fungible_store::balance(creator_address, metadata) == 1000, 1); 

        primary_fungible_store::transfer(creator, metadata, alice_address, 10);
         
        assert!(primary_fungible_store::balance(alice_address, metadata) == 10, 2); 

        token_factory::burn( creator, 0, creator_address, 990);
        token_factory::burn( creator, 0, alice_address, 10);

        assert!(primary_fungible_store::balance(creator_address, metadata) == 0, 3); 
        assert!(primary_fungible_store::balance(alice_address, metadata) == 0, 4); 
    }

}