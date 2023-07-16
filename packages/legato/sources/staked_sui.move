
module legato::staked_sui {

    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, TreasuryCap};

    struct STAKED_SUI has drop {}

    fun init(witness: STAKED_SUI, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<STAKED_SUI>(witness, 8, b"STAKED_SUI", b"sSUI", b"", option::none(), ctx);
    
        transfer::public_share_object(metadata);
        transfer::public_share_object(treasury_cap)
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<STAKED_SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, tx_context::sender(ctx), ctx)
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(STAKED_SUI {}, ctx)
    }

}