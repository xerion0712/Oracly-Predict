
module legato::staked_sui {

    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::object::{ Self, UID, ID};
    use sui::balance::{ Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;

    const FAKE_POOL: address = @0x123;

    struct StakedSui has key, store {
        id: UID,
        pool_id: ID,
        stake_activation_epoch: u64,
        principal: Balance<SUI>
    }

    public entry fun wrap(
        stake: Coin<SUI>,
        ctx: &mut TxContext
    ) {

        let staker = tx_context::sender(ctx);

        let staked_sui = StakedSui {
            id: object::new(ctx),
            pool_id: object::id_from_address(FAKE_POOL),
            stake_activation_epoch : tx_context::epoch(ctx),
            principal: coin::into_balance(stake),
        };
        transfer::transfer(staked_sui, staker);
    }

    public entry fun unwrap(
        staked_sui: StakedSui,
        ctx: &mut TxContext
    ) {
        let StakedSui { id , pool_id : _, stake_activation_epoch : _, principal } = staked_sui;
        object::delete(id);
        transfer::public_transfer(coin::from_balance(principal, ctx), tx_context::sender(ctx));
    }

    public fun staked_sui_amount(staked_sui: &StakedSui): u64 { balance::value(&staked_sui.principal) }

    public fun stake_activation_epoch(staked_sui: &StakedSui): u64 {
        staked_sui.stake_activation_epoch
    }
    
}