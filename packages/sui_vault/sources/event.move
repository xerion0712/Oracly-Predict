
module legato::event {

    use std::string::String;

    use sui::event::emit;
    use sui::object::ID;
 
    friend legato::vault;

    struct NewVaultEvent has copy, drop {
        global: ID,
        vault_name: String,
        created_epoch: u64,
        maturity_epoch:u64,
        initial_apy: u128 // in fixed-point raw value
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