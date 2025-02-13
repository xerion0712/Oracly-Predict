

// Mock USDC coins in fungible asset for local test

module legato_market::mock_usdc_fa {

    use aptos_framework::object;
    use aptos_framework::fungible_asset::{ Metadata};
    use aptos_framework::object::Object;

    use legato_market::base_fungible_asset;

    use std::string::utf8;

    const ASSET_SYMBOL: vector<u8> = b"USDC";

    /// Initialize metadata object and store the refs.
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        base_fungible_asset::initialize(
            constructor_ref,
            0, /* maximum_supply. 0 means no maximum */
            utf8(b"Mock USDC Tokens"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            6, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
            vector[true, true, true]
        );
    }

    #[view]
    /// Return the address of the metadata that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let metadata_address = object::create_object_address(&@legato_market, ASSET_SYMBOL);
        object::address_to_object<Metadata>(metadata_address)
    }

     /// Mint as the owner of metadata object.
    public entry fun mint(admin: &signer, to: address, amount: u64) {
        base_fungible_asset::mint_to_primary_stores(admin, get_metadata(), vector[to], vector[amount]);
    }

    /// Burn fungible assets as the owner of metadata object.
    public entry fun burn(admin: &signer, from: address, amount: u64) {
        base_fungible_asset::burn_from_primary_stores(admin,  get_metadata(), vector[from], vector[amount]);
    }

    // ======== Test-related Functions =========

    #[test_only] 
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

}