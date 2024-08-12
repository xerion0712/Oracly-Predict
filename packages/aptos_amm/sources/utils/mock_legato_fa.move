
// Mock Legato coins in fungible asset

module legato_amm_addr::mock_legato_fa {
    
    use aptos_framework::object;
    use aptos_framework::fungible_asset::{  Metadata};
    use aptos_framework::object::Object;
    
    use legato_amm_addr::base_fungible_asset;

    use std::string::utf8;

    const ASSET_SYMBOL: vector<u8> = b"LEGATO";

    /// Initialize metadata object and store the refs.
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        base_fungible_asset::initialize(
            constructor_ref,
            0, /* maximum_supply. 0 means no maximum */
            utf8(b"Mock Legato Tokens"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );
    }

    #[view]
    /// Return the address of the metadata that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let metadata_address = object::create_object_address(&@legato_amm_addr, ASSET_SYMBOL);
        object::address_to_object<Metadata>(metadata_address)
    }

    /// Mint as the owner of metadata object.
    public entry fun mint(   to: address, amount: u64) {
        base_fungible_asset::mint_to_primary_stores( get_metadata(), vector[to], vector[amount]);
    }


    /// Burn fungible assets as the owner of metadata object.
    public entry fun burn( from: address, amount: u64) {
        base_fungible_asset::burn_from_primary_stores(  get_metadata(), vector[from], vector[amount]);
    }

    #[test_only]
    use aptos_framework::primary_fungible_store;
    #[test_only]
    use std::signer;

    #[test(creator = @legato_amm_addr, alice = @0xface)]
    fun test_basic_flow(creator: &signer, alice: &signer) {
        init_module(creator);
        let creator_address = signer::address_of(creator);
        let alice_address = signer::address_of(alice); 

        mint( creator_address, 100);
        let metadata = get_metadata();
        assert!(primary_fungible_store::balance(creator_address, metadata) == 100, 1); 

        primary_fungible_store::transfer(creator, metadata, alice_address, 5);
        assert!(primary_fungible_store::balance(alice_address, metadata) == 5, 2); 

        burn( creator_address, 95);
        burn( alice_address, 5);
        assert!(primary_fungible_store::balance(creator_address, metadata) == 0, 3); 
        assert!(primary_fungible_store::balance(alice_address, metadata) == 0, 4); 
    }

    // ======== Test-related Functions =========

    #[test_only] 
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}