

// Mock Ondo's USDY for testing

module legato_options::mock_usdy {

    use sui::object::{ Self, UID }; 
    use std::option;
    use sui::coin::{Self, Coin };
    use sui::balance::{ Self, Supply };
    use sui::transfer;
    use sui::tx_context::{ TxContext};

    public struct MOCK_USDY has drop {}

    public struct USDYGlobal has key {
        id: UID,
        supply: Supply<MOCK_USDY>
    }

    fun init(witness: MOCK_USDY, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<MOCK_USDY>(witness, 9, b"MOCK USDY TOKEN", b"MOCK-USDY", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        
        transfer::share_object(USDYGlobal {
            id: object::new(ctx),
            supply: coin::treasury_into_supply<MOCK_USDY>(treasury_cap)
        })
    }

    public entry fun mint(
        global: &mut USDYGlobal, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        let minted_balance = balance::increase_supply<MOCK_USDY>(&mut global.supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), recipient);
    }

    public entry fun burn(global: &mut USDYGlobal, coin: Coin<MOCK_USDY>) {
        balance::decrease_supply(&mut global.supply, coin::into_balance(coin));
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(MOCK_USDY {}, ctx)
    }

}
