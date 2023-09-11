module legato::oracle {

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::transfer; 
    use sui::event::emit;
    use std::ascii::String;

    struct ManagerCap has key {
        id: UID,
    }

    struct Feed has key {
        id: UID,
        feed_name: String,
        decimal: u64,
        value: u64,
        epoch: u64
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    public entry fun new_feed(
        _manager_cap: &ManagerCap,
        feed_name: String,
        decimal: u64,
        ctx: &mut TxContext
    ) {

        let id = object::new(ctx);

        let feed = Feed {
            id,
            feed_name,
            decimal,
            value: 0,
            epoch: tx_context::epoch(ctx)
        };

        transfer::share_object(feed);
    }

    public entry fun update(
        feed: &mut Feed,
        _manager_cap: &ManagerCap,
        value: u64, 
        ctx: &mut TxContext
    ) {
        assert!(value > 0, E_INVALID_VALUE);

        feed.value = value; 
        feed.epoch = tx_context::epoch(ctx);

        emit(PriceEvent {id: object::id(feed), value});
    }

    public entry fun grant_manager_cap(
        _manager_cap: &ManagerCap,
        recipient: address,
        ctx: &mut TxContext
    ) {
        transfer::transfer(ManagerCap {id: object::new(ctx)}, recipient);
    }

    public fun get_oracle(
        oracle: &Feed
    ): (u64, u64, u64) {
        (oracle.value, oracle.decimal, oracle.epoch)
    }

    public fun get_feed_name(
        oracle: &Feed
    ): (String) {
        (oracle.feed_name)
    }

    public fun get_value(
        oracle: &Feed
    ): (u64, u64) { 
        (oracle.value, oracle.decimal)
    }
 
    public entry fun update_feed_name(
        oracle: &mut Feed,
        _manager_cap: &ManagerCap,
        feed_name: String
    ) {
        oracle.feed_name = feed_name;
    }

    const E_INVALID_VALUE: u64 = 1;

    struct PriceEvent has copy, drop { id: ID, value: u64 }
}