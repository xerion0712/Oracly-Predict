

// Mock USDC coins in fungible asset

module legato_addr::mock_usdc {

    use aptos_framework::object;
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleAsset};
    use aptos_framework::object::Object;
    use legato_addr::base_fungible_asset;
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
        );
    }

    #[view]
    /// Return the address of the metadata that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let metadata_address = object::create_object_address(&@legato_addr, ASSET_SYMBOL);
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

}