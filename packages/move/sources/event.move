 
module legato::event {
    use std::string::String;

    use sui::event::emit;
    use sui::object::ID;

    friend legato::legato;
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
        maturity_epoch:u64,
        initial_apy: u64
    }

    struct UpdateVaultApy has copy, drop {
        global: ID,
        vault_name: String,
        vault_apy: u64,
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        pending_balance: u64,
        earning_balance: u64
    }

    struct MintEvent has copy, drop {  
        vault_name: String,
        pool_id: ID,
        input_amount: u64,
        pt_issued: u64,
        deposit_id: u64,
        asset_object_id: ID,
        sender: address,
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        earning_balance: u64,
        pending_balance: u64
    }

    struct RedeemEvent has copy, drop {  
        vault_name: String,
        pt_burned: u64,
        sui_amount: u64,
        sender: address,
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        earning_balance: u64,
        pending_balance: u64
    }

    struct ExitEvent has copy, drop { 
        vault_name: String,
        deposit_id: u64,
        asset_object_id: ID,
        pt_burned: u64,
        yt_received: u64,
        sender: address,
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        earning_balance: u64,
        pending_balance: u64
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
        maturity_epoch: u64,
        initial_apy: u64
    ) {
        emit(
            NewVaultEvent {
                global,
                vault_name,
                created_epoch,
                maturity_epoch,
                initial_apy
            }
        )
    }

    public(friend) fun update_vault_apy_event(
        global: ID,
        vault_name: String,
        vault_apy: u64,
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        pending_balance: u64,
        earning_balance: u64
    ) {
        emit(
            UpdateVaultApy {
                global,
                vault_name,
                vault_apy,
                epoch,
                principal_balance,
                debt_balance,
                pending_balance,
                earning_balance
            }
        )
    }

    public(friend) fun mint_event( 
        vault_name: String,
        pool_id: ID,
        input_amount: u64,
        pt_issued: u64,
        deposit_id: u64,
        asset_object_id: ID,
        sender: address,
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        earning_balance: u64,
        pending_balance: u64
    ) {
        emit(
            MintEvent { 
                vault_name,
                pool_id,
                input_amount,
                pt_issued,
                deposit_id,
                asset_object_id,
                sender,
                epoch,
                principal_balance,
                debt_balance,
                earning_balance,
                pending_balance
            }
        )
    }

    public(friend) fun redeem_event(  
        vault_name: String,
        pt_burned: u64,
        sui_amount: u64,
        sender: address,
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        earning_balance: u64,
        pending_balance: u64
    ) {
        emit(
            RedeemEvent {  
                vault_name,
                pt_burned,
                sui_amount,
                sender,
                epoch,
                principal_balance,
                debt_balance,
                earning_balance,
                pending_balance
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
        epoch: u64,
        principal_balance: u64,
        debt_balance: u64,
        earning_balance: u64,
        pending_balance: u64
    ) {
        emit(
            ExitEvent {  
                vault_name,
                deposit_id,
                asset_object_id,
                pt_burned,
                yt_received,
                sender,
                epoch,
                principal_balance,
                debt_balance,
                earning_balance,
                pending_balance
            }
        )
    }

}