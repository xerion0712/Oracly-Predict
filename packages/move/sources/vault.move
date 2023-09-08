

module legato::vault {

    use sui::object::{Self, UID};
    use sui::balance::{ Self, Supply, Balance};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use legato::staked_sui::STAKED_SUI;
    use legato::epoch_time_lock::{Self, EpochTimeLock};
    
    const EZeroAmount: u64 = 0;

    // manually change here
    const LOCK_FOR_EPOCH: u64 = 3;

    struct VAULT has drop { }

    struct Reserve has key {
        id: UID,
        collateral: Balance<STAKED_SUI>,
        outstanding: Supply<VAULT>,
        locked_until_epoch: EpochTimeLock
    }

    #[allow(unused_function)]
    fun init(witness: VAULT, ctx: &mut TxContext) {
        let total_supply = balance::create_supply<VAULT>(witness);

        transfer::share_object(Reserve {
            id: object::new(ctx),
            outstanding : total_supply,
            collateral: balance::zero<STAKED_SUI>(),
            locked_until_epoch : epoch_time_lock::new(tx_context::epoch(ctx) + LOCK_FOR_EPOCH, ctx)
        })
    }

    // staked_sui_decimal = 3
    public entry fun mint(
        reserve: &mut Reserve,
        collateral: Coin<STAKED_SUI>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&collateral);

        assert!(amount >= 0, EZeroAmount);

        let user = tx_context::sender(ctx);

        coin::put(&mut reserve.collateral, collateral);

        let minted_balance = balance::increase_supply(&mut reserve.outstanding, amount / 1000);

        transfer::public_transfer(coin::from_balance(minted_balance, ctx), user);
    }

    public entry fun redeem(
        reserve: &mut Reserve,
        vault: Coin<VAULT>,
        ctx: &mut TxContext
    ) {
        epoch_time_lock::destroy(reserve.locked_until_epoch, ctx);

        let burned_balance = balance::decrease_supply(&mut reserve.outstanding, coin::into_balance(vault));

        let user = tx_context::sender(ctx);

        transfer::public_transfer(coin::take(&mut reserve.collateral, burned_balance * 1000, ctx), user);
    }

    public entry fun total_supply(reserve: &Reserve): u64 {
        balance::supply_value(&reserve.outstanding)
    }

    public entry fun total_collateral(reserve: &Reserve): u64 {
        balance::value(&reserve.collateral)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(VAULT {}, ctx)
    }

}