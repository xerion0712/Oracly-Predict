// A base fungible asset module that allows anyone to mint and burn coins

module legato_addr::base_fungible_asset {

    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleStore};
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::{String, utf8};
    use std::option;
    use std::vector;

    /// Only fungible asset metadata owner can make changes.
    const ERR_NOT_OWNER: u64 = 1;
    /// The length of ref_flags is not 3.
    const ERR_INVALID_REF_FLAGS_LENGTH: u64 = 2;
    /// The lengths of two vector do not equal.
    const ERR_VECTORS_LENGTH_MISMATCH: u64 = 3;
    /// MintRef error.
    const ERR_MINT_REF: u64 = 4;
    /// TransferRef error.
    const ERR_TRANSFER_REF: u64 = 5;
    /// BurnRef error.
    const ERR_BURN_REF: u64 = 6;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagingRefs has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    /// Initialize metadata object
    public fun initialize(
        constructor_ref: &ConstructorRef,
        maximum_supply: u128,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String
    ) {
        let supply = if (maximum_supply != 0) {
            option::some(maximum_supply)
        } else {
            option::none()
        };
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            supply,
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri,
        );
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagingRefs { 
                mint_ref: fungible_asset::generate_mint_ref(constructor_ref), 
                transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref), 
                burn_ref: fungible_asset::generate_burn_ref(constructor_ref)
            }
        )

    }

    /// Mint to the primary fungible stores of the accounts with amounts of FAs.
    public entry fun mint_to_primary_stores( 
        asset: Object<Metadata>,
        to: vector<address>,
        amounts: vector<u64>
    ) acquires ManagingRefs {
        let receiver_primary_stores = vector::map(
            to,
            |addr| primary_fungible_store::ensure_primary_store_exists(addr, asset)
        );
        mint(  asset, receiver_primary_stores, amounts);
    }

    /// Mint to multiple fungible stores with amounts of FAs.
    public entry fun mint( 
        asset: Object<Metadata>,
        stores: vector<Object<FungibleStore>>,
        amounts: vector<u64>,
    ) acquires ManagingRefs {
        let length = vector::length(&stores);
        assert!(length == vector::length(&amounts), error::invalid_argument(ERR_VECTORS_LENGTH_MISMATCH));
        let mint_ref = borrow_mint_ref(asset);
        let i = 0;
        while (i < length) {
            fungible_asset::mint_to(mint_ref, *vector::borrow(&stores, i), *vector::borrow(&amounts, i));
            i = i + 1;
        }
    }

    /// Burn fungible assets from the primary stores of accounts.
    public entry fun burn_from_primary_stores( 
        asset: Object<Metadata>,
        from: vector<address>,
        amounts: vector<u64>
    ) acquires ManagingRefs {
        let primary_stores = vector::map(
            from,
            |addr| primary_fungible_store::primary_store(addr, asset)
        );
        burn( asset, primary_stores, amounts);
    }
 

    /// Burn fungible assets from fungible stores.
    public entry fun burn( 
        asset: Object<Metadata>,
        stores: vector<Object<FungibleStore>>,
        amounts: vector<u64>
    ) acquires ManagingRefs {
        let length = vector::length(&stores);
        assert!(length == vector::length(&amounts), error::invalid_argument(ERR_VECTORS_LENGTH_MISMATCH));
        let burn_ref = borrow_burn_ref(  asset);
        let i = 0;
        while (i < length) {
            fungible_asset::burn_from(burn_ref, *vector::borrow(&stores, i), *vector::borrow(&amounts, i));
            i = i + 1;
        };
    }

    inline fun borrow_mint_ref(
        asset: Object<Metadata>,
    ): &MintRef acquires ManagingRefs {
        let refs = borrow_global<ManagingRefs>(object::object_address(&asset));
        &refs.mint_ref
    }

    inline fun borrow_burn_ref(
        asset: Object<Metadata>,
    ): &BurnRef acquires ManagingRefs {
        let refs = borrow_global<ManagingRefs>(object::object_address(&asset));
        &refs.burn_ref
    }

    #[test_only]
    use aptos_framework::object::object_from_constructor_ref;
    
    #[test_only]
    fun create_test_mfa(creator: &signer): Object<Metadata> {
        let constructor_ref = &object::create_named_object(creator, b"APT");
        initialize(
            constructor_ref,
            0,
            utf8(b"Aptos Token"), /* name */
            utf8(b"APT"), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );
        object_from_constructor_ref<Metadata>(constructor_ref)
    }

    #[test(creator = @legato_addr, alice = @0xface)]
    fun test_basic_flow(
        creator: &signer,
        alice: &signer
    ) acquires ManagingRefs {
        let metadata = create_test_mfa(creator);
        let creator_address = signer::address_of(creator);
        let alice_address = signer::address_of(alice);

        mint_to_primary_stores(  metadata, vector[creator_address, alice_address], vector[100, 50]);
        assert!(primary_fungible_store::balance(creator_address, metadata) == 100, 1);
        assert!(primary_fungible_store::balance(alice_address, metadata) == 50, 2);

        primary_fungible_store::transfer(creator, metadata, alice_address, 5);

        assert!(primary_fungible_store::balance(creator_address, metadata) == 95, 3);
        assert!(primary_fungible_store::balance(alice_address, metadata) == 55, 4);

        burn_from_primary_stores(  metadata, vector[creator_address, alice_address], vector[95, 55]);
        assert!(primary_fungible_store::balance(creator_address, metadata) == 0, 5);
        assert!(primary_fungible_store::balance(alice_address, metadata) == 0, 6);
    }

}