
module legato::marketplace {

    use sui::dynamic_object_field as ofield;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::event;
    use sui::sui::SUI;
    use legato::vault::{VAULT};

    const EAmountIncorrect: u64 = 0;
    const ENotOwner : u64 = 1;

    struct Marketplace has key {
        id: UID
    }

    struct Listing has key, store {
        id: UID,
        ask: u64,
        owner: address
    }

    struct ListEvent has copy, drop {
        object_id: ID,
        ask: u64,
        owner: address
    }

    struct BuyEvent has copy, drop {
        object_id: ID
    }

    #[allow(unused_function)]
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Marketplace {
            id: object::new(ctx)
        })
    }

    public entry fun list(
        marketplace: &mut Marketplace,
        item: Coin<VAULT>,
        ask: u64,
        ctx: &mut TxContext 
    ) {
        let item_id = object::id(&item);
        let sender = tx_context::sender(ctx);
        let listing = Listing {
            ask,
            id: object::new(ctx),
            owner: sender,
        };

        event::emit(ListEvent {
            object_id: item_id,
            ask,
            owner: sender,
        });

        ofield::add(&mut listing.id, true, item);
        ofield::add(&mut marketplace.id, item_id, listing)
    }

    public fun buy(
        marketplace: &mut Marketplace,
        item_id: ID,
        paid: Coin<SUI>,
    ) : Coin<VAULT> {
        let Listing {
            id,
            ask,
            owner
        } = ofield::remove(&mut marketplace.id, item_id);

        assert!(ask == coin::value(&paid), EAmountIncorrect);

        if (ofield::exists_<address>(&marketplace.id, owner)) {
            coin::join(
                ofield::borrow_mut<address, Coin<SUI>>(&mut marketplace.id, owner),
                paid
            )
        } else {
            ofield::add(&mut marketplace.id, owner, paid)
        };

        event::emit(BuyEvent {
            object_id: item_id
        });

        let item = ofield::remove(&mut id, true);
        object::delete(id);
        item
    }

    public entry fun buy_and_take(
        marketplace: &mut Marketplace,
        item_id : ID,
        paid: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer(
            buy(marketplace, item_id, paid),
            tx_context::sender(ctx)
        )
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}