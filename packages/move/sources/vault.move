module legato::vault {
    
    // use std::option;
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{ Self, Supply };
    use sui::object::{Self, UID, ID };
    use sui::transfer; 
    use sui::event;
    use sui::sui::SUI;
    // use sui::dynamic_object_field as ofield;
    use legato::epoch_time_lock::{ Self, EpochTimeLock};
    use legato::oracle::{Self, Feed};
    use legato::staked_sui::{ Self, StakedSui }; // clones of staking_pool.move
    use legato::marketplace::{Self, Marketplace };
    use legato::amm::{Self, Pool };

    const YT_TOTAL_SUPPLY: u64 = 1000000*1000000000; // 1 Mil.

    const FEED_DECIMAL_PLACE: u64 = 3;

    const EZeroAmount: u64 = 0;
    const EVaultExpired: u64 = 1;
    const EInvalidStakeActivationEpoch: u64 = 2;
    const EInsufficientAmount: u64 = 3;
    const EInvalidDepositID: u64 = 4;

    struct ManagerCap has key {
        id: UID,
    }

    struct PT has drop {}
    struct YT has drop {}

    struct TOKEN<phantom T> has drop {}
 
    struct Reserve has key {
        id: UID,
        deposits: Table<u64, StakedSui>,
        deposit_count: u64,
        balance: u64,
        pt: Supply<TOKEN<PT>>,
        yt: Supply<TOKEN<YT>>,
        feed : Feed,
        marketplace: Marketplace<TOKEN<PT>>,
        amm: Pool<TOKEN<YT>>,
        locked_until_epoch: EpochTimeLock
    }

    struct LockEvent has copy, drop {
        reserve_id: ID,
        deposit_amount: u128,
        deposit_id: u64,
        pt_amount: u64,
        owner: address
    }

    struct UnlockEvent has copy, drop {
        reserve_id: ID,
        burned_amount: u64,
        deposit_id: u64,
        owner: address
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init( ctx);
    }

    // create new vault
    public entry fun new_vault(
        _manager_cap: &mut ManagerCap,
        lockForEpoch : u64,
        initialL : Coin<SUI>, // initial liquidity for YT's AMM
        ctx: &mut TxContext
    ) {

        let deposits = table::new(ctx);

        // setup PT
        let pt = balance::create_supply(TOKEN<PT> {});
        // setup YT
        let yt = balance::create_supply(TOKEN<YT> {});

        //  give 1 mil. of YT tokens to the AMM
        let minted_yt = balance::increase_supply(&mut yt,YT_TOTAL_SUPPLY);
        let amm_for_yt = amm::new_pool<TOKEN<YT>>(coin::from_balance(minted_yt, ctx), initialL, ctx);

        let reserve = Reserve {
            id: object::new(ctx),
            deposits,
            deposit_count: 0,
            pt,
            yt,
            balance: 0,
            marketplace: marketplace::new_marketplace<TOKEN<PT>>(ctx),
            feed : oracle::new_feed(FEED_DECIMAL_PLACE,ctx), // ex. 4.123%
            amm : amm_for_yt,
            locked_until_epoch : epoch_time_lock::new(tx_context::epoch(ctx) + lockForEpoch, ctx)
        };

        transfer::share_object(reserve);
    }

    // lock tokens to receive PT
    public entry fun lock(
        reserve: &mut Reserve,
        input: StakedSui,
        ctx: &mut TxContext
    ) {

        let amount = staked_sui::staked_sui_amount(&input);
        let until_epoch = epoch_time_lock::epoch(&reserve.locked_until_epoch);

        assert!(amount > 0, EZeroAmount);
        assert!(until_epoch > tx_context::epoch(ctx), EVaultExpired );
        assert!(until_epoch > staked_sui::stake_activation_epoch(&input), EInvalidStakeActivationEpoch );

        let user = tx_context::sender(ctx);

        // deposit Stake Sui objects into the table

        table::add(
            &mut reserve.deposits,
            reserve.deposit_count,
            input
        );

        reserve.balance = reserve.balance + amount;
        reserve.deposit_count = reserve.deposit_count + 1;

        // calculate epoch remaining until the vault matures
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

        event::emit(LockEvent {
            reserve_id: object::id(reserve),
            deposit_amount: amount,
            deposit_id : reserve.deposit_count - 1,
            pt_amount: add_pt_amount,
            owner : tx_context::sender(ctx)
        });
    }

    // unlock Staked SUI object, must providing deposit ID
    public entry fun unlock_after_mature(
        reserve: &mut Reserve,
        deposit_id: u64,
        pt: &mut Coin<TOKEN<PT>>,
        ctx: &mut TxContext
    ) {

        assert!(table::contains(&mut reserve.deposits, deposit_id), EInvalidDepositID);
 
        let deposit_item = table::remove(&mut reserve.deposits, deposit_id);
        let amount = staked_sui::staked_sui_amount(&deposit_item);

        assert!(coin::value(pt) >= amount, EInsufficientAmount);

        let deducted = coin::split(pt, amount, ctx);

        epoch_time_lock::destroy(reserve.locked_until_epoch, ctx);
        let burned_balance = balance::decrease_supply(&mut reserve.pt, coin::into_balance(deducted));

        let user = tx_context::sender(ctx);

        transfer::public_transfer(deposit_item, user);

        reserve.balance = reserve.balance - amount;
        
        event::emit(UnlockEvent {
            reserve_id: object::id(reserve),
            burned_amount : burned_balance,
            deposit_id,
            owner : tx_context::sender(ctx)
        });
    }

    // TODO: unlock before mature using YT

    public entry fun total_yt_supply(reserve: &Reserve): u64 {
        balance::supply_value(&reserve.yt)
    }

    public entry fun total_pt_supply(reserve: &Reserve): u64 {
        balance::supply_value(&reserve.pt)
    }

    public entry fun balance(reserve: &Reserve): u64 {
        reserve.balance
    }

    public entry fun feed_value(reserve: &Reserve) : (u64) {
        let (val, _ ) = oracle::get_value(&reserve.feed);
        val
    }

    public entry fun feed_decimal(reserve: &Reserve) : (u64) {
        let (_, dec ) = oracle::get_value(&reserve.feed);
        dec
    }

    // MARKETPLACE

    public entry fun list(
        reserve: &mut Reserve,
        item: &mut Coin<TOKEN<PT>>,
        amount: u64,
        price: u64,
        ctx: &mut TxContext
    ) {
        marketplace::list<TOKEN<PT>>(&mut reserve.marketplace, item, amount, price, ctx);
    }

    public entry fun delist(
        reserve: &mut Reserve,
        order_id: u64,
        ctx: &mut TxContext
    ) {
        marketplace::delist<TOKEN<PT>>(&mut reserve.marketplace, order_id, ctx);
    }

    public entry fun buy(
        reserve: &mut Reserve,
        order_id: u64,
        base_amount: u64,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        marketplace::buy<TOKEN<PT>>(&mut reserve.marketplace, order_id, base_amount, payment, ctx);
    }

    public entry fun order_price(reserve: &Reserve, order_id: u64): u64 {
        marketplace::order_price<TOKEN<PT>>(&reserve.marketplace, order_id)
    }

    public entry fun order_amount(reserve: &Reserve, order_id: u64): u64 {
        marketplace::order_amount<TOKEN<PT>>(&reserve.marketplace, order_id)
    }

    // AMM
    public entry fun swap_sui(reserve: &mut Reserve, amount: u64, sui: &mut Coin<SUI>,  ctx: &mut TxContext) {
        amm::swap_sui<TOKEN<YT>>(&mut reserve.amm, amount, sui, ctx)
    }

    public entry fun swap_token(reserve: &mut Reserve, amount: u64, token: &mut Coin<TOKEN<YT>>,  ctx: &mut TxContext) {
        amm::swap_token<TOKEN<YT>>(&mut reserve.amm, amount, token, ctx)
    }

    public entry fun add_liquidity(reserve: &mut Reserve, sui_add_amount: u64, token_add_amount:u64, sui: &mut Coin<SUI>, token: &mut Coin<TOKEN<YT>> , ctx: &mut TxContext) {
        amm::add_liquidity<TOKEN<YT>>(&mut reserve.amm, sui_add_amount, token_add_amount, sui, token, ctx)
    }

    // public entry fun remove_liquidity<P>(reserve: &mut Reserve, lp: Coin<P>, ctx: &mut TxContext ) {
    //     amm::remove_liquidity<TOKEN<YT>>(&mut reserve.amm, lp, ctx)
    // }

    public entry fun sui_price(reserve: &Reserve, to_sell: u64):u64 {
        amm::sui_price<TOKEN<YT>>(&reserve.amm, to_sell)
    }

    public entry fun token_price(reserve: &Reserve, to_sell: u64):u64 {
        amm::token_price<TOKEN<YT>>(&reserve.amm, to_sell)
    }

    // ADMIN STUFFS

    // transfer manager cap to someone else
    public entry fun transfer_manager_cap(
        _manager_cap: &ManagerCap,
        recipient: address,
        ctx: &mut TxContext
    ) {
        transfer::transfer(ManagerCap {id: object::new(ctx)}, recipient);
    }

    // update APR value
    public entry fun update_feed_value(
        _manager_cap: &ManagerCap,
        reserve: &mut Reserve,
        value: u64,
        ctx: &mut TxContext
    ) {
        oracle::update(&mut reserve.feed, value, ctx)
    }

}