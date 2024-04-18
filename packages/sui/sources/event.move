 
module legato::event {
    use std::string::String;

    use sui::event::emit;
    use sui::object::ID;
    
    friend legato::amm;
    friend legato::vault; 

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

    struct Rebalance has copy, drop {
        vault_name: String,
        minted_pt: u64,
        liquidity_amount: u64,
        conversion_rate: u64,
        epoch: u64
    }

    public(friend) fun rebalance_event(
        vault_name: String,
        minted_pt: u64,
        liquidity_amount: u64,
        conversion_rate: u64,
        epoch: u64
    ) {
        emit (
            Rebalance {
                vault_name,
                minted_pt,
                liquidity_amount,
                conversion_rate,
                epoch
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