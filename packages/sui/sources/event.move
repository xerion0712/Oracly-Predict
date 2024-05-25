
module legato::event {

    use std::string::String;

    use sui::event::emit;
    use sui::object::ID;

    friend legato::amm;
    friend legato::vault;

    struct NewVaultEvent has copy, drop {
        global: ID,
        vault_name: String,
        created_epoch: u64,
        maturity_epoch:u64,
        initial_apy: u128 // in fixed-point raw value
    }

    struct RegisterPoolEvent has copy, drop {
        global: ID,
        lp_name: String,
        weight_x: u64,
        weight_y: u64,
        is_stable: bool,
        is_lbp: bool
    }

    struct SwappedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_in: u64,
        coin_x_out: u64,
        coin_y_in: u64,
        coin_y_out: u64
    }

    struct FutureSwappedEvent has copy, drop {
        global: ID,
        lp_name: String,
        staked_sui_in: u64,
        future_yield_amount: u64,
        coin_y_out: u64
    }

    struct AddLiquidityEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_amount: u64,
        coin_y_amount: u64,
        lp_amount: u64,
        is_pool_creator: bool
    }

    struct RemoveLiquidityEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_amount: u64,
        coin_y_amount: u64,
        lp_amount: u64
    }

    struct UpdateVaultApy has copy, drop {
        global: ID,
        vault_name: String,
        vault_apy: u128 // in fixed-point raw value
    }

    struct MintEvent has copy, drop {  
        vault_name: String,
        input_amount: u64,
        pt_amount: u64, 
        asset_object_id: ID,
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

    struct RedeemEvent has copy, drop {  
        vault_name: String,
        pt_burned: u64,
        sui_amount: u64,
        sender: address,
        epoch: u64
    }

    struct ExitEvent has copy, drop { 
        vault_name: String,
        pt_burned: u64,
        sui_amount: u64,
        sender: address,
        epoch: u64
    }

    public(friend) fun new_vault_event(
        global: ID,
        vault_name: String,
        created_epoch: u64,
        maturity_epoch: u64,
        initial_apy: u128
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

    public(friend) fun register_pool_event(
        global: ID,
        lp_name: String,
        weight_x: u64,
        weight_y: u64,
        is_stable: bool,
        is_lbp: bool
    ) {
        emit(
            RegisterPoolEvent {
                global,
                lp_name,
                weight_x,
                weight_y,
                is_stable,
                is_lbp
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

    public(friend) fun future_swapped_event(
        global: ID,
        lp_name: String,
        staked_sui_in: u64,
        future_yield_amount: u64,
        coin_y_out: u64
    ) {
        emit(
            FutureSwappedEvent {
                global,
                lp_name,
                staked_sui_in,
                future_yield_amount,
                coin_y_out
            }
        )
    }

    public(friend) fun add_liquidity_event(
        global: ID,
        lp_name: String,
        coin_x_amount: u64,
        coin_y_amount: u64,
        lp_amount: u64,
        is_pool_creator: bool
    ) {
        emit(
            AddLiquidityEvent {
                global,
                lp_name,
                coin_x_amount,
                coin_y_amount,
                lp_amount,
                is_pool_creator
            }
        )
    }

    public(friend) fun remove_liquidity_event(
        global: ID,
        lp_name: String,
        coin_x_amount: u64,
        coin_y_amount: u64,
        lp_amount: u64,
    ) {
        emit(
            RemoveLiquidityEvent {
                global,
                lp_name,
                coin_x_amount,
                coin_y_amount,
                lp_amount
            }
        )
    }
    
    public(friend) fun update_vault_apy_event(
        global: ID,
        vault_name: String,
        vault_apy: u128
    ) {
        emit(
            UpdateVaultApy {
                global,
                vault_name,
                vault_apy
            }
        )
    }

    public(friend) fun mint_event( 
        vault_name: String, 
        input_amount: u64,
        pt_amount: u64, 
        asset_object_id: ID,
        sender: address,
        epoch: u64
    ) {
        emit(
            MintEvent { 
                vault_name, 
                input_amount,
                pt_amount, 
                asset_object_id,
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
        pt_burned: u64,
        sui_amount: u64,
        sender: address,
        epoch: u64
    ) {
        emit(
            ExitEvent {  
                vault_name,
                pt_burned,
                sui_amount,
                sender,
                epoch
            }
        )
    }



}