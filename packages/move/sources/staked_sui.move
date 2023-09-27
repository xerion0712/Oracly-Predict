
module legato::staked_sui {

    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::object::{ Self, UID, ID};
    use sui::balance::{ Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;

    const FAKE_POOL: address = @0x123;

    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI

    const EInvalidPoolID: u64 = 0;
    const EIncompatibleStakedSui: u64 = 1;
    const EInsufficientSuiTokenBalance: u64 = 2;
    const EStakedSuiBelowThreshold: u64 = 3;

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

    public fun wrap_for_new_vault(stake: Coin<SUI>, ctx: &mut TxContext) : StakedSui {
        StakedSui {
            id: object::new(ctx),
            pool_id: object::id_from_address(FAKE_POOL),
            stake_activation_epoch : tx_context::epoch(ctx),
            principal: coin::into_balance(stake),
        }
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

    public entry fun split_staked_sui(stake: &mut StakedSui, split_amount: u64, ctx: &mut TxContext) {
        transfer::transfer(split(stake, split_amount, ctx), tx_context::sender(ctx));
    }

    public entry fun join_staked_sui(self: &mut StakedSui, other: StakedSui) {
        assert!(is_equal_staking_metadata(self, &other), EIncompatibleStakedSui);
        let StakedSui {
            id,
            pool_id: _,
            stake_activation_epoch: _,
            principal,
        } = other;

        object::delete(id);
        balance::join(&mut self.principal, principal);
    }

    public fun is_equal_staking_metadata(self: &StakedSui, other: &StakedSui): bool {
        (self.pool_id == other.pool_id) &&
        (self.stake_activation_epoch == other.stake_activation_epoch)
    }

    public fun split(self: &mut StakedSui, split_amount: u64, ctx: &mut TxContext): StakedSui {
        let original_amount = balance::value(&self.principal);
        assert!(split_amount <= original_amount, EInsufficientSuiTokenBalance);
        let remaining_amount = original_amount - split_amount;
        // Both resulting parts should have at least MIN_STAKING_THRESHOLD.
        assert!(remaining_amount >= MIN_STAKING_THRESHOLD, EStakedSuiBelowThreshold);
        assert!(split_amount >= MIN_STAKING_THRESHOLD, EStakedSuiBelowThreshold);
        StakedSui {
            id: object::new(ctx),
            pool_id: self.pool_id,
            stake_activation_epoch: self.stake_activation_epoch,
            principal: balance::split(&mut self.principal, split_amount),
        }
    }

}