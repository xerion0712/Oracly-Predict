module legato::marketplace {

    use sui::balance::{ Self, Balance};
    use sui::table::{Self, Table};
    use sui::object::{Self, UID };
    use sui::tx_context::{ Self, TxContext};
    use sui::coin::{Self, Coin }; 
    use sui::event;
    use sui::transfer; 
    use sui::sui::SUI;

    const EZeroAmount: u64 = 0;
    const EInsufficientAmount: u64 = 1;
    const EInvalidOrderID: u64 = 2;
    const EInvalidOwner: u64 = 3;

    struct Order<phantom T> has store {
        base: Balance<T>,
        price: u64, // per 1 PT
        owner: address
    }

    struct Marketplace<phantom T> has key, store {
        id: UID,
        orders: Table<u64, Order<T>>,
        order_count: u64
    }

    struct ListEvent has copy, drop {
        order_id: u64,
        price: u64,
        owner: address,
        timestamp: u64
    }

    struct DelistEvent has copy, drop {
        order_id: u64,
        owner: address,
        timestamp: u64
    }

    struct BuyEvent has copy, drop {
        order_id: u64,
        total_price: u64,
        amount: u64,
        timestamp: u64
    }

    struct OrderClosedEvent has copy, drop {
        order_id: u64,
        timestamp: u64
    }

    public fun new_marketplace<T>(
        ctx: &mut TxContext
    ) : Marketplace<T> {
        let id = object::new(ctx);
        let orders = table::new(ctx);

        Marketplace {
            id,
            orders,
            order_count : 0
        }
    }

    // list PT token at the desired amount
    public fun list<T>(
        marketplace: &mut Marketplace<T>,
        item: &mut Coin<T>,
        amount: u64,
        price: u64,
        ctx: &mut TxContext
    ) {

        assert!(amount > 0, EZeroAmount);
        assert!(price > 0, EZeroAmount);
        assert!(coin::value(item) >= amount, EInsufficientAmount);

        let base_item = coin::split(item, amount, ctx);
        let order_id = marketplace.order_count;
        let sender = tx_context::sender(ctx);

        let order = Order {
            base : coin::into_balance(base_item),
            price,
            owner: sender
        };

        table::add(
            &mut marketplace.orders,
            order_id,
            order
        );

        marketplace.order_count = marketplace.order_count+1;

        event::emit(ListEvent {
            order_id,
            price,
            owner: sender,
            timestamp : tx_context::epoch_timestamp_ms(ctx)
        });
    }

    // delist an order and return the remaining tokens
    public fun delist<T>(
        marketplace: &mut Marketplace<T>,
        order_id: u64,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&mut marketplace.orders, order_id), EInvalidOrderID);

        let Order {
            base,
            price : _,
            owner
        } = table::remove(&mut marketplace.orders, order_id);
        let sender = tx_context::sender(ctx);

        assert!(owner == sender, EInvalidOwner);

        transfer::public_transfer(coin::from_balance(base, ctx),sender);

        event::emit(DelistEvent {
            order_id,
            owner: sender,
            timestamp : tx_context::epoch_timestamp_ms(ctx)
        });
    }
    
    // buy
    public fun buy<T>(
        marketplace: &mut Marketplace<T>,
        order_id: u64,
        base_amount: u64,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&mut marketplace.orders, order_id), EInvalidOrderID);

        let order = table::borrow_mut(&mut marketplace.orders, order_id);

        assert!( balance::value(&order.base) >= base_amount, EInsufficientAmount);

        let (
            price,
            base_amount
        ) = (
            (order.price as u128),
            (base_amount as u128)
        );

        // PAYS ITS OWNER
        let total = (price * base_amount) / 1000000000;
        let (
            total,
            base_amount
        ) = (
            (total as u64),
            (base_amount as u64)
        );

        assert!(coin::value(payment) >= total, EInsufficientAmount);

        let paid = coin::split(payment, total, ctx);
        transfer::public_transfer(paid, order.owner);

        // TRANSFERS PT TO SENDER
        let to_sender = balance::split(&mut order.base, base_amount);
        transfer::public_transfer( coin::from_balance(to_sender, ctx) , tx_context::sender(ctx));

        // EMIT EVENT
        event::emit(BuyEvent {
                order_id,
                total_price : total,
                amount: base_amount,
                timestamp : tx_context::epoch_timestamp_ms(ctx)
        });

        // remove the order if there's no value
        if (balance::value(&order.base) == 0) {
            let Order {
                base,
                price : _,
                owner : _
            } = table::remove(&mut marketplace.orders, order_id);
            balance::destroy_zero(base);

            // EMIT EVENT
            event::emit(OrderClosedEvent {
                order_id,
                timestamp : tx_context::epoch_timestamp_ms(ctx)
            });
        }
    }

    // get order price
    public fun order_price<T>(marketplace: &Marketplace<T>, order_id: u64): u64 {
        assert!(table::contains(&marketplace.orders, order_id), EInvalidOrderID);
        let order = table::borrow(&marketplace.orders, order_id);
        order.price
    }

    // get order base amount
    public fun order_amount<T>(marketplace: &Marketplace<T>, order_id: u64): u64 {
        assert!(table::contains(&marketplace.orders, order_id), EInvalidOrderID);
        let order = table::borrow(&marketplace.orders, order_id);
        balance::value(&order.base)
    }
}