module legato::vault {

    use sui::tx_context::{Self, TxContext};
    use sui::balance::{ Self, Supply, Balance};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use legato::epoch_time_lock::{Self, EpochTimeLock};
    use legato::oracle::{Self, Feed};

    const YT_TOTAL_SUPPLY: u64 = 1000000000;

    const EZeroAmount: u64 = 0;
    const EVaultExpired: u64 = 1;

    struct ManagerCap has key {
        id: UID,
    }

    struct PT<phantom TOKEN> has drop {}
    struct YT<phantom TOKEN> has drop {}

    struct Reserve<phantom TOKEN> has key {
        id: UID,
        collateral: Balance<TOKEN>,
        pt: Supply<PT<TOKEN>>,
        yt: Supply<YT<TOKEN>>,
        feed : Feed,
        locked_until_epoch: EpochTimeLock
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

    public entry fun new_vault<TOKEN>(
        _manager_cap: &ManagerCap, 
        lockForEpoch : u64,
        ctx: &mut TxContext
    ) {
        let pt = balance::create_supply(PT<TOKEN> {});
        let yt = balance::create_supply(YT<TOKEN> {});

         // give 1 mil. of YT tokens to the sender
        let minted_balance = balance::increase_supply(&mut yt, YT_TOTAL_SUPPLY);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), tx_context::sender(ctx));

        transfer::share_object(Reserve {
            id: object::new(ctx),
            pt : pt,
            yt: yt, 
            collateral: balance::zero<TOKEN>(),
            feed : oracle::new_feed(3,ctx), // ex. 4.123%
            locked_until_epoch : epoch_time_lock::new(tx_context::epoch(ctx) + lockForEpoch, ctx)
        });

    }

    public entry fun update_feed_value<TOKEN>(
        _manager_cap: &ManagerCap,
        reserve: &mut Reserve<TOKEN>,
        value: u64,
        ctx: &mut TxContext
    ) {
        oracle::update(&mut reserve.feed, value, ctx)
    }

    public entry fun lock<TOKEN>(
        reserve: &mut Reserve<TOKEN>,
        collateral: Coin<TOKEN>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&collateral);
        let until_epoch = epoch_time_lock::epoch(&reserve.locked_until_epoch);

        assert!(amount >= 0, EZeroAmount);
        assert!(until_epoch > tx_context::epoch(ctx), EVaultExpired );

        let user = tx_context::sender(ctx);

        coin::put(&mut reserve.collateral, collateral);

        let diff = until_epoch-tx_context::epoch(ctx);

        let (val, _ ) = oracle::get_value(&reserve.feed);

        let (
            diff,
            val,
            amount
        ) = (
            (diff as u128),
            (val as u128),
            (amount as u128)
        );

        let add_pt_amount = diff*val*amount / 36500000;
        add_pt_amount = add_pt_amount+amount;
        let add_pt_amount = (add_pt_amount as u64);

        let minted_balance = balance::increase_supply(&mut reserve.pt,add_pt_amount);

        transfer::public_transfer(coin::from_balance(minted_balance, ctx), user);
    
        // emit event
    }

    // deposit collateral
    public entry fun deposit<TOKEN>(
        reserve: &mut Reserve<TOKEN>,
        collateral: Coin<TOKEN>
    ) {
        let amount = coin::value(&collateral);

        assert!(amount >= 0, EZeroAmount);

        coin::put(&mut reserve.collateral, collateral);

        // emit event
    }

    public entry fun unlock<TOKEN>(
        reserve: &mut Reserve<TOKEN>,
        pt: Coin<PT<TOKEN>>,
        ctx: &mut TxContext
    ) {
        epoch_time_lock::destroy(reserve.locked_until_epoch, ctx);
        let burned_balance = balance::decrease_supply(&mut reserve.pt, coin::into_balance(pt));

        let user = tx_context::sender(ctx);

        transfer::public_transfer(coin::take(&mut reserve.collateral, burned_balance, ctx), user);

        // emit event
    }

    public entry fun total_yt_supply<TOKEN>(reserve: &Reserve<TOKEN>): u64 {
        balance::supply_value(&reserve.yt)
    }

    public entry fun total_pt_supply<TOKEN>(reserve: &Reserve<TOKEN>): u64 {
        balance::supply_value(&reserve.pt)
    }

    public entry fun total_collateral<TOKEN>(reserve: &Reserve<TOKEN>): u64 {
        balance::value(&reserve.collateral)
    }

    public entry fun feed_value<TOKEN>(reserve: &Reserve<TOKEN>) : (u64) {
        let (val, _ ) = oracle::get_value(&reserve.feed);
        val
    }

    public entry fun feed_decimal<TOKEN>(reserve: &Reserve<TOKEN>) : (u64) {
        let (_, dec ) = oracle::get_value(&reserve.feed);
        dec
    }

}