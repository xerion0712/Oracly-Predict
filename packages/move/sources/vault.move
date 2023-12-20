

module legato::vault {

    use sui::tx_context::{Self, TxContext};
    use sui::table::{ Self, Table};
    use sui::balance::{ Self, Supply  };
    use sui::object::{ Self, ID, UID };
    use sui::coin::{Self, Coin };
    use sui::transfer;
    use std::vector;
    use sui::event;
    use std::string::{ String};

    use sui_system::staking_pool::{ Self, StakedSui};
    use sui_system::sui_system::{SuiSystemState };

    use legato::apy_reader::{Self};

    // ======== Constants ========
    const MIST_PER_SUI : u64 = 1_000_000_000;
    const MIN_SUI_TO_STAKE : u64 = 10_000_000_000; // 10 Sui
    const MAX_EPOCH: u64 = 365;
    const COOLDOWN_EPOCH: u64 = 3;

    // ======== Errors ========
    const E_EMPTY_VECTOR: u64 = 1;
    const E_INVALID_MATURITY: u64 = 2;
    const E_DUPLICATED_ENTRY: u64 = 3;
    const E_NOT_FOUND: u64 = 4;
    const E_VAULT_MATURED: u64 = 5;
    const E_MIN_THRESHOLD: u64 = 6;
    const E_UNAUTHORIZED_USER: u64 = 7;
    const E_UNAUTHORIZED_POOL: u64 = 8;

    // ======== Structs =========      
    struct ManagerCap has key {
        id: UID
    }

    struct PT has drop {}
    struct YT has drop {}

    struct TOKEN<phantom P, phantom T> has drop {}

    struct Vault<phantom P> has key {
        id: UID,
        symbol: String,
        name: String,
        created_epoch: u64,
        maturity_epoch: u64,
        pools: vector<ID>, // supported staking pools
        whitelist: vector<address>, // whitelisting users (will be removed in the next version)
        holdings: Table<u64, StakedSui>,
        asset_count: u64,
        pt_supply: Supply<TOKEN<P, PT>>
    }

    struct MintEvent has copy, drop {
        vault_id: ID,
        pool_id: ID,
        input_amount: u64,
        pt_amount: u64,
        asset_id: u64,
        asset_object_id: ID,
        sender: address
    }

    struct NewVaultEvent has copy, drop {
        name: String,
        symbol: String,
        created_epoch: u64,
        maturity_epoch:u64,
        pools: vector<ID>
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
    
    // ======== Public Functions =========

    // convert Staked SUI to PT
    public entry fun mint<P>(
        wrapper: &mut SuiSystemState,
        vault: &mut Vault<P>,
        staked_sui: StakedSui,
        ctx: &mut TxContext
    ) {
        assert!(vault.maturity_epoch-COOLDOWN_EPOCH > tx_context::epoch(ctx), E_VAULT_MATURED);
        assert!(staking_pool::staked_sui_amount(&staked_sui) >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);
        
        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&vault.whitelist, &sender), E_UNAUTHORIZED_USER);
        let pool_id = staking_pool::pool_id(&staked_sui);
        assert!(vector::contains(&vault.pools, &pool_id), E_UNAUTHORIZED_POOL);

        let asset_object_id = object::id(vault);

        // Take the Staked SUI
        let input_amount = staking_pool::staked_sui_amount(&staked_sui); 
        let asset_id = receive_staked_sui(vault, staked_sui);

        // Calculate PT to send out
        let pt_amount = input_amount+future_pt(wrapper, vault, tx_context::epoch(ctx), input_amount);

        // Mint to the user
        mint_pt(vault, pt_amount, ctx);
  
        event::emit(MintEvent {
            vault_id: object::id(vault),
            pool_id,
            input_amount,
            pt_amount,
            asset_id,
            asset_object_id,
            sender
        });

    }

    // redeem when the vault reaches its maturity date
    // public entry fun redeem<P>(
    //     vault: &mut Vault<P>,
    //     pt: Coin<TOKEN<P,PT>>,
    //     ctx: &mut TxContext
    // ) {



    // }

    // ======== Only Governance =========

    // create new vault
    public entry fun new_vault<P: drop>(
        _manager_cap: &mut ManagerCap,
        _: P,
        name: String,
        symbol: String,
        pools: vector<ID>,
        maturity_epoch: u64,
        ctx: &mut TxContext
    ) {
        assert!(vector::length<ID>(&pools) > 0, E_EMPTY_VECTOR);
        assert!( maturity_epoch > tx_context::epoch(ctx) , E_INVALID_MATURITY);

        // setup PT
        let pt_supply = balance::create_supply(TOKEN<P,PT> {});

        let vault = Vault {
            id: object::new(ctx),
            name,
            symbol,
            created_epoch: tx_context::epoch(ctx),
            maturity_epoch,
            pools,
            whitelist: vector::empty<address>(),
            holdings: table::new(ctx),
            asset_count: 0,
            pt_supply
        };

        transfer::share_object(vault);

        // emit event
        event::emit(NewVaultEvent {
            name,
            symbol,
            created_epoch: tx_context::epoch(ctx),
            maturity_epoch,
            pools
        });

    }

    // add user to the whitelist
    public entry fun add_user<P>(
        vault: &mut Vault<P>,
        _manager_cap: &ManagerCap,
        user: address
    ) {
        assert!(
            !vector::contains(&vault.whitelist, &user),
            E_DUPLICATED_ENTRY
        );
        vector::push_back<address>(&mut vault.whitelist, user);
    }


    // remove user from the whitelist
    public entry fun remove_user<P>(
        vault: &mut Vault<P>,
        _manager_cap: &ManagerCap,
        user: address
    ) {
        let (contained, index) = vector::index_of<address>(&vault.whitelist, &user);
        assert!(
            contained,
            E_NOT_FOUND
        );
        vector::remove<address>(&mut vault.whitelist, index);
    }

    // ======== Internal Functions =========

    fun receive_staked_sui<P>(vault: &mut Vault<P>, staked_sui: StakedSui) : u64 {
        let asset_id = vault.asset_count;

        table::add(
            &mut vault.holdings,
            asset_id,
            staked_sui
        );

        vault.asset_count = vault.asset_count + 1;
        asset_id
    }

    fun mint_pt<P>(vault: &mut Vault<P>, amount: u64, ctx: &mut TxContext) {
        let minted_balance = balance::increase_supply(&mut vault.pt_supply, amount);
        transfer::public_transfer(coin::from_balance(minted_balance, ctx), tx_context::sender(ctx));
    }

    fun future_pt<P>(wrapper: &mut SuiSystemState, vault: &Vault<P>, from_epoch: u64, principal: u64): u64 {
        let apy = vault_apy(wrapper, vault, from_epoch);
        let for_epoch = vault.maturity_epoch-from_epoch;

        let (for_epoch, apy, principal) = ((for_epoch as u128), (apy as u128), (principal as u128));
        let result = (for_epoch*apy*principal) / (365_000_000_000);

        (result as u64)
    }

    fun vault_apy<P>(wrapper: &mut SuiSystemState, vault: &Vault<P>, epoch: u64): u64 {
        let count = vector::length(&vault.pools);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            let pool_id = vector::borrow(&vault.pools, i);
            total_sum = total_sum+apy_reader::pool_apy(wrapper, pool_id, epoch);
            i = i + 1;
        };
        total_sum / i
    }

}