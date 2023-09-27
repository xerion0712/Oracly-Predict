module legato::amm {

    use sui::coin::{Self, Coin }; 
    use sui::balance::{Self, Supply, Balance};
    use sui::object::{Self, UID};
    use sui::sui::SUI;
    use sui::math;
    use sui::transfer;
    use sui::event;
    use sui::tx_context::{ Self, TxContext};

    const EZeroAmount: u64 = 0;
    const EReservesEmpty: u64 = 1;
    const EShareEmpty: u64 = 2;
    const EPoolFull: u64 = 3;

    struct LP_TOKEN<phantom T> has drop {}

    struct Pool<phantom T> has key, store {
        id: UID,
        sui: Balance<SUI>,
        token: Balance<T>,
        lp_supply: Supply<LP_TOKEN<T>>
    }

    const MAX_POOL_VALUE: u64 = {
        18446744073709551615 / 10000
    };

    const ONE: u64 = 1000000000;

    struct PriceUpdatedEvent has copy, drop {
        sui_price: u64,
        token_price: u64,
        timestamp: u64
    }

    public fun new_pool<T>(
        token: Coin<T>,
        sui: Coin<SUI>,
        ctx: &mut TxContext
    ): Pool<T> {
        let sui_amt = coin::value(&sui);
        let tok_amt = coin::value(&token);

        assert!(sui_amt > 0 && tok_amt > 0, EZeroAmount);
        assert!(sui_amt < MAX_POOL_VALUE && tok_amt < MAX_POOL_VALUE, EPoolFull);

        let share = math::sqrt(sui_amt) * math::sqrt(tok_amt);
        let lp_supply = balance::create_supply(LP_TOKEN<T> {});
        let lp = balance::increase_supply(&mut lp_supply, share);

        transfer::public_transfer(coin::from_balance(lp, ctx),tx_context::sender(ctx));

        // EMIT EVENT
        event::emit(PriceUpdatedEvent {
            sui_price : get_input_price(ONE, tok_amt, sui_amt),
            token_price : get_input_price(ONE, sui_amt, tok_amt),
            timestamp : tx_context::epoch_timestamp_ms(ctx)
        });

        Pool {
            id: object::new(ctx),
            token: coin::into_balance(token),
            sui: coin::into_balance(sui),
            lp_supply
        }
    }

    // sui -> token
    public fun swap_sui<T>(
        pool: &mut Pool<T>,
        amount: u64,
        sui: &mut Coin<SUI>, 
        ctx: &mut TxContext
    ) {
        assert!(coin::value(sui) > 0, EZeroAmount);

        let payment_amount = coin::split(sui, amount, ctx);
        let sui_balance = coin::into_balance(payment_amount);

        let (sui_reserve, token_reserve, _) = get_amounts(pool);

        assert!(sui_reserve > 0 && token_reserve > 0, EReservesEmpty);

        let output_amount = get_input_price(
            balance::value(&sui_balance),
            sui_reserve,
            token_reserve
        );

        balance::join(&mut pool.sui, sui_balance);
        transfer::public_transfer(
            coin::take(&mut pool.token, output_amount, ctx),
            tx_context::sender(ctx)
        );

        // EMIT EVENT
        event::emit(PriceUpdatedEvent {
            sui_price : sui_price<T>(pool, ONE ),
            token_price : token_price<T>(pool, ONE ),
            timestamp : tx_context::epoch_timestamp_ms(ctx)
        });
    }

    // swap token -> sui
    public fun swap_token<T>(
        pool: &mut Pool<T>,
        amount: u64,
        token: &mut Coin<T>,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(token) > 0, EZeroAmount);

        let payment_amount = coin::split(token, amount, ctx);
        let tok_balance = coin::into_balance(payment_amount);

        let (sui_reserve, token_reserve, _) = get_amounts(pool);

        assert!(sui_reserve > 0 && token_reserve > 0, EReservesEmpty);

        let output_amount = get_input_price(
            balance::value(&tok_balance),
            token_reserve,
            sui_reserve
        );

        balance::join(&mut pool.token, tok_balance);
        transfer::public_transfer(
            coin::take(&mut pool.sui, output_amount, ctx),
            tx_context::sender(ctx)
        );

        // EMIT EVENT
        event::emit(PriceUpdatedEvent {
            sui_price : sui_price<T>(pool, ONE ),
            token_price : token_price<T>(pool, ONE ),
            timestamp : tx_context::epoch_timestamp_ms(ctx)
        });
    }

    // TODO : VERIFY WEIGHT IS 50:50
    public fun add_liquidity<T>(
        pool: &mut Pool<T>, 
        sui_add_amount: u64,
        token_add_amount: u64,
        sui: &mut Coin<SUI>,
        token: &mut Coin<T>, 
        ctx: &mut TxContext
    ) {
        assert!(coin::value(sui) > 0, EZeroAmount);
        assert!(coin::value(token) > 0, EZeroAmount);

        let sui_added = coin::split(sui, sui_add_amount, ctx);
        let token_added = coin::split(token, token_add_amount, ctx);

        let sui_balance = coin::into_balance(sui_added);
        let tok_balance = coin::into_balance(token_added);

        let (sui_amount, tok_amount, lp_supply) = get_amounts(pool);

        let sui_added = balance::value(&sui_balance);
        let tok_added = balance::value(&tok_balance);
        let share_minted = math::min(
            (sui_added * lp_supply) / sui_amount,
            (tok_added * lp_supply) / tok_amount
        );

        let sui_amt = balance::join(&mut pool.sui, sui_balance);
        let tok_amt = balance::join(&mut pool.token, tok_balance);

        assert!(sui_amt < MAX_POOL_VALUE, EPoolFull);
        assert!(tok_amt < MAX_POOL_VALUE, EPoolFull);

        let balance = balance::increase_supply(&mut pool.lp_supply, share_minted);
        
        transfer::public_transfer(
            coin::from_balance(balance, ctx),
            tx_context::sender(ctx)
        );

        // EMIT EVENT
        event::emit(PriceUpdatedEvent {
            sui_price : sui_price<T>(pool, ONE ),
            token_price : token_price<T>(pool, ONE ),
            timestamp : tx_context::epoch_timestamp_ms(ctx)
        });
    }

    public entry fun remove_liquidity<T>(
        pool: &mut Pool<T>,
        lp: Coin<LP_TOKEN<T>>,
        ctx: &mut TxContext
    ) {
        
        let lp_amount = coin::value(&lp);

        // If there's a non-empty LSP, we can
        assert!(lp_amount > 0, EZeroAmount);

        let (sui_amt, tok_amt, lp_supply) = get_amounts(pool);
        let sui_removed = (sui_amt * lp_amount) / lp_supply;
        let tok_removed = (tok_amt * lp_amount) / lp_supply;

        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp));

        let sender = tx_context::sender(ctx);

        transfer::public_transfer(coin::take(&mut pool.sui, sui_removed, ctx), sender);
        transfer::public_transfer(coin::take(&mut pool.token, tok_removed, ctx), sender);

        // EMIT EVENT
        event::emit(PriceUpdatedEvent {
            sui_price : sui_price<T>(pool, ONE ),
            token_price : token_price<T>(pool, ONE ),
            timestamp : tx_context::epoch_timestamp_ms(ctx)
        });
    }

    public fun sui_price<T>(pool: &Pool<T>, to_sell: u64): u64 {
        let (sui_amt, tok_amt, _) = get_amounts(pool);
        get_input_price(to_sell, tok_amt, sui_amt)
    }

    public fun token_price<T>(pool: &Pool<T>, to_sell: u64): u64 {
        let (sui_amt, tok_amt, _) = get_amounts(pool);
        get_input_price(to_sell, sui_amt, tok_amt)
    }

    public fun get_amounts<T>(pool: &Pool<T>): (u64, u64, u64) {
        (
            balance::value(&pool.sui),
            balance::value(&pool.token),
            balance::supply_value(&pool.lp_supply)
        )
    }

    public fun get_input_price(
        input_amount: u64, input_reserve: u64, output_reserve: u64
    ): u64 {
        // up casts
        let (
            input_amount,
            input_reserve,
            output_reserve
        ) = (
            (input_amount as u128),
            (input_reserve as u128),
            (output_reserve as u128)
        );

        let numerator = input_amount * output_reserve;
        let denominator = input_reserve + input_amount;

        (numerator / denominator as u64)
    }

}