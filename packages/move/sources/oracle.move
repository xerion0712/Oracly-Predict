module legato::oracle {

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::event::emit;

    struct Feed has key, store {
        id: UID,
        decimal: u64,
        value: u64,
        epoch: u64
    }

    public fun new_feed(
        decimal: u64,
        ctx: &mut TxContext
    ) : Feed {

        let id = object::new(ctx);

        Feed {
            id,
            decimal,
            value: 0,
            epoch: tx_context::epoch(ctx)
        }
    }

    public fun update(
        feed: &mut Feed,
        value: u64, 
        ctx: &mut TxContext
    ) {
        assert!(value > 0, E_INVALID_VALUE);

        feed.value = value; 
        feed.epoch = tx_context::epoch(ctx);

        emit(PriceEvent {id: object::id(feed), value});
    }

    public fun get_feed(
        feed: &Feed
    ): (u64, u64, u64) {
        (feed.value, feed.decimal, feed.epoch)
    }

    public fun get_value(
        feed: &Feed
    ): (u64, u64) { 
        (feed.value, feed.decimal)
    }

    const E_INVALID_VALUE: u64 = 1;

    struct PriceEvent has copy, drop { id: ID, value: u64 }
}