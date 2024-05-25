
// Mock Legato tokens for Testnet

module legato::mock_legato {

    use sui::object::{ Self, UID }; 
    use std::option;
    use sui::coin::{Self, Coin };
    use sui::balance::{ Self, Supply };
    use sui::transfer;
    use sui::tx_context::{ TxContext};

    struct MOCK_LEGATO has drop {}

    struct LegatoGlobal has key {
        id: UID,
        supply: Supply<MOCK_LEGATO>
    }

    fun init(witness: MOCK_LEGATO, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<MOCK_LEGATO>(witness, 8, b"MOCK LEGATO TOKEN", b"MOCK-LEGATO", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        
        transfer::share_object(LegatoGlobal {
            id: object::new(ctx),
            supply: coin::treasury_into_supply<MOCK_LEGATO>(treasury_cap)
        })
    }

    public entry fun mint(
        global: &mut LegatoGlobal, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        let minted_balance = balance::increase_supply<MOCK_LEGATO>(&mut global.supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), recipient);
    }

    public entry fun burn(global: &mut LegatoGlobal, coin: Coin<MOCK_LEGATO>) {
        balance::decrease_supply(&mut global.supply, coin::into_balance(coin));
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(MOCK_LEGATO {}, ctx)
    }

}