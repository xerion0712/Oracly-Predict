 
module legato::event {
    use std::string::String;

    use sui::event::emit;
    use sui::object::ID;
 
    friend legato::amm;
    friend legato::vault;
    friend legato::vault_lib;
    friend legato::marketplace;
    friend legato::lp_staking;
    // friend legato::vusd;

    /// Liquidity pool added event.
    struct AddedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64,
    }

    /// Liquidity pool removed event.
    struct RemovedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64,
    }

    /// Liquidity pool swapped event.
    struct SwappedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_in: u64,
        coin_x_out: u64,
        coin_y_in: u64,
        coin_y_out: u64,
    }

    struct NewVaultEvent has copy, drop {
        global: ID,
        vault_name: String,
        created_epoch: u64,
        started_epoch: u64,
        maturity_epoch:u64,
        initial_apy: u64
    }

    struct UpdateVaultApy has copy, drop {
        global: ID,
        vault_name: String,
        vault_apy: u64,
        epoch: u64
    }

    struct MintEvent has copy, drop {  
        vault_name: String,
        pool_id: ID,
        input_amount: u64,
        pt_issued: u64, 
        asset_object_id: ID,
        sender: address,
        epoch: u64
    }

    struct RedeemEvent has copy, drop {  
        vault_name: String,
        pt_burned: u64,
        sui_amount: u64,
        sender: address,
        epoch: u64
    }

    struct ExitEvent has copy, drop { 
        vault_name: String,
        deposit_id: u64,
        asset_object_id: ID,
        pt_burned: u64,
        yt_received: u64,
        sender: address,
        epoch: u64
    }

    struct MigrateEvent has copy, drop {
        from_vault: String,
        from_amount: u64,
        to_vault: String,
        to_amount: u64,
        sender: address,
        epoch: u64
    }

    struct RemoveOrderEvent has copy, drop {
        marketplace: ID,
        order_id: u64,
        owner: address
    }

    struct UpdateOrderEvent has copy, drop {
        marketplace: ID,
        order_id: u64,
        updated_price: u64,
        owner: address
    }

    struct TradeEvent has copy, drop {
        marketplace: ID,
        from_token: String,
        to_token: String,
        input_amount: u64,
        output_amount: u64,
        sender: address
    }

    struct NewOrderEvent has copy, drop {
        marketplace: ID,
        order_id: u64,
        is_bid: bool,
        base_token: String,
        quote_token: String,
        amount: u64,
        unit_price: u64, // per 1 unit
        owner: address
    }

    struct StakeEvent has copy, drop {
        lp_staking: ID,
        pool_name: String,
        input_amount: u64,
        epoch: u64,
        sender: address
    }

    struct UnstakeEvent has copy, drop {
        lp_staking: ID,
        pool_name: String,
        output_amount: u64,
        epoch: u64,
        sender: address
    }

    struct WithdrawRewardsEvent has copy, drop {
        lp_staking: ID,
        pool_name: String,
        reward_name: String,
        reward_amount: u64,
        epoch: u64,
        sender: address
    }

    struct DepositRewardsEvent has copy, drop {
        lp_staking: ID,
        pool_name: String,
        reward_name: String,
        reward_amount: u64,
        epoch: u64,
        sender: address
    }

    struct SnapshotEvent has copy, drop {
        lp_staking: ID,
        pool_name: String,
        reward_name: String,
        total_rewards_to_spend: u64,
        epoch: u64,
        sender: address
    }

    struct VUsdMint has copy, drop {
        position_manager: ID,
        input_token: String,
        input_amount: u64,
        neutralization_factor: u64,
        hedging_amount: u64,
        collateral_staked_sui_amount: u64,
        epoch: u64,
        sender: address
    }

    public(friend) fun vusd_mint_event(
        position_manager: ID,
        input_token: String,
        input_amount: u64,
        neutralization_factor: u64,
        hedging_amount: u64,
        collateral_staked_sui_amount: u64,
        epoch: u64,
        sender: address
    ) {
        emit(
            VUsdMint {
                position_manager,
                input_token,
                input_amount,
                neutralization_factor,
                hedging_amount,
                collateral_staked_sui_amount,
                epoch,
                sender
            }
        )
    }

    public(friend) fun snapshot_event(
        lp_staking: ID,
        pool_name: String,
        reward_name: String,
        total_rewards_to_spend: u64,
        epoch: u64,
        sender: address
    ) {
        emit(
            SnapshotEvent {
                lp_staking,
                pool_name,
                reward_name,
                total_rewards_to_spend,
                epoch,
                sender
            }
        )
    }

    public(friend) fun deposit_rewards_event(
        lp_staking: ID,
        pool_name: String,
        reward_name: String,
        reward_amount: u64,
        epoch: u64,
        sender: address
    ) {
        emit(
            DepositRewardsEvent {
                lp_staking,
                pool_name,
                reward_name,
                reward_amount,
                epoch,
                sender
            }
        )
    }

    public(friend) fun stake_event(
        lp_staking: ID,
        pool_name: String,
        input_amount: u64,
        epoch: u64,
        sender: address
    ) {
        emit(
            StakeEvent {
                lp_staking,
                pool_name,
                input_amount,
                epoch,
                sender
            }
        )
    }

    public(friend) fun withdraw_rewards_event(
        lp_staking: ID,
        pool_name: String,
        reward_name: String,
        reward_amount: u64,
        epoch: u64,
        sender: address
    ) {
        emit(
            WithdrawRewardsEvent {
                lp_staking,
                pool_name,
                reward_name,
                reward_amount,
                epoch,
                sender
            }
        )
    }

    public(friend) fun unstake_event(
        lp_staking: ID,
        pool_name: String,
        output_amount: u64,
        epoch: u64,
        sender: address
    ) {
        emit(
            UnstakeEvent {
                lp_staking,
                pool_name,
                output_amount,
                epoch,
                sender
            }
        )
    }

    public(friend) fun new_order_event(
        marketplace: ID,
        order_id: u64,
        is_bid: bool,
        base_token: String,
        quote_token: String,
        amount: u64,
        unit_price: u64,
        owner: address
    ) {
        emit(
            NewOrderEvent {
                marketplace,
                order_id,
                is_bid,
                base_token,
                quote_token,
                amount,
                unit_price,
                owner
            }
        )
    }

    public(friend) fun trade_event(
        marketplace: ID,
        from_token: String,
        to_token: String,
        input_amount: u64,
        output_amount: u64,
        sender: address
    ) {
        emit(
            TradeEvent {
                marketplace,
                from_token,
                to_token,
                input_amount,
                output_amount,
                sender
            }
        )
    }

    public(friend) fun remove_order_event(
        marketplace: ID,
        order_id: u64,
        owner: address
    ) {
        emit(
            RemoveOrderEvent {
                marketplace,
                order_id,
                owner
            }
        )
    }

    public(friend) fun update_order_event(
        marketplace: ID,
        order_id: u64,
        updated_price: u64,
        owner: address
    ) {
        emit(
            UpdateOrderEvent {
                marketplace,
                order_id,
                updated_price,
                owner
            }
        )
    }

    public(friend) fun added_event(
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64
    ) {
        emit(
            AddedEvent {
                global,
                lp_name,
                coin_x_val,
                coin_y_val,
                lp_val
            }
        )
    }

    public(friend) fun removed_event(
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64
    ) {
        emit(
            RemovedEvent {
                global,
                lp_name,
                coin_x_val,
                coin_y_val,
                lp_val
            }
        )
    }

    public(friend) fun swapped_event(
        global: ID,
        lp_name: String,
        coin_x_in: u64,
        coin_x_out: u64,
        coin_y_in: u64,
        coin_y_out: u64
    ) {
        emit(
            SwappedEvent {
                global,
                lp_name,
                coin_x_in,
                coin_x_out,
                coin_y_in,
                coin_y_out
            }
        )
    }

    public(friend) fun new_vault_event(
        global: ID,
        vault_name: String,
        created_epoch: u64,
        started_epoch: u64,
        maturity_epoch: u64,
        initial_apy: u64
    ) {
        emit(
            NewVaultEvent {
                global,
                vault_name,
                created_epoch,
                started_epoch,
                maturity_epoch,
                initial_apy
            }
        )
    }

    public(friend) fun update_vault_apy_event(
        global: ID,
        vault_name: String,
        vault_apy: u64,
        epoch: u64
    ) {
        emit(
            UpdateVaultApy {
                global,
                vault_name,
                vault_apy,
                epoch
            }
        )
    }

    public(friend) fun mint_event( 
        vault_name: String,
        pool_id: ID,
        input_amount: u64,
        pt_issued: u64, 
        asset_object_id: ID,
        sender: address,
        epoch: u64
    ) {
        emit(
            MintEvent { 
                vault_name,
                pool_id,
                input_amount,
                pt_issued, 
                asset_object_id,
                sender,
                epoch
            }
        )
    }

    public(friend) fun redeem_event(  
        vault_name: String,
        pt_burned: u64,
        sui_amount: u64,
        sender: address,
        epoch: u64
    ) {
        emit(
            RedeemEvent {  
                vault_name,
                pt_burned,
                sui_amount,
                sender,
                epoch
            }
        )
    }

    public(friend) fun exit_event(
        vault_name: String,
        deposit_id: u64,
        asset_object_id: ID,
        pt_burned: u64,
        yt_received: u64,
        sender: address,
        epoch: u64
    ) {
        emit(
            ExitEvent {  
                vault_name,
                deposit_id,
                asset_object_id,
                pt_burned,
                yt_received,
                sender,
                epoch
            }
        )
    }

    public(friend) fun migrate_event(
        from_vault: String,
        from_amount: u64,
        to_vault: String,
        to_amount: u64,
        sender: address,
        epoch: u64
    ) {
        emit(
            MigrateEvent {
                from_vault,
                from_amount,
                to_vault,
                to_amount,
                sender,
                epoch
            }
        )
    }

}