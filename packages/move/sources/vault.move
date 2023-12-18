

module legato::vault {

    // use std::debug;
    // use sui::math;

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID , ID};
    use sui::transfer; 
    use sui::table::{Self, Table};
    use sui::balance::{ Self, Supply  };
    use sui::coin::{Self };
    use sui::event;
    use std::vector;
    use std::string::{ String};

    use sui_system::sui_system::{SuiSystemState };
    use sui_system::staking_pool::{Self, StakedSui};

    use legato::apy_reader::{Self};

    // ======== Constants ========
    const MIST_PER_SUI : u64 = 1_000_000_000;
    const MIN_SUI_TO_STAKE : u64 = 10_000_000_000; // 10 Sui
    const MAX_EPOCH: u64 = 365;
    const INIT_RAND_NONCE: u64 = 32012210897210;
    // const TOKEN_DECIMAL: u8 = 6;

    // ======== Errors ========
    const E_EMPTY_VECTOR: u64 = 1;
    const E_DUPLICATED_ENTRY: u64 = 2;
    const E_NOT_FOUND: u64 = 3;
    const E_MIN_THRESHOLD: u64 = 4;
    const E_INSUFFICIENT_AMOUNT: u64 = 5;
    const E_VAULT_PAUSED: u64 = 6;
    const E_UNAUTHORIZED_USER: u64 = 7;
    const E_UNAUTHORIZED_POOL: u64 = 8;
    const E_EXCEED_LIMIT: u64 = 9;
    const E_INVALID_MATURITY: u64 = 10;
    const E_VAULT_MATURED: u64 = 11;

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
        rand_nonce: u64,
        paused: bool,
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
        asset_id: u64,
        issued_pt: u64,
        sender: address
    }

    struct NewVaultEvent has copy, drop {
        name: String,
        symbol: String,
        created_epoch: u64,
        maturity_epoch:u64
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

    // convert Staked SUI to PT
    public entry fun mint<P>(
        wrapper: &mut SuiSystemState,
        vault: &mut Vault<P>,
        staked_sui: StakedSui,
        ctx: &mut TxContext
    ) {
        assert!(vault.paused == false, E_VAULT_PAUSED);
        assert!(vault.maturity_epoch > tx_context::epoch(ctx), E_VAULT_MATURED);

        let amount = staking_pool::staked_sui_amount(&staked_sui); 
        assert!(amount >= MIN_SUI_TO_STAKE, E_MIN_THRESHOLD);
        
        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&vault.whitelist, &sender), E_UNAUTHORIZED_USER);

        let pool_id = staking_pool::pool_id(&staked_sui);
        assert!(vector::contains(&vault.pools, &pool_id), E_UNAUTHORIZED_POOL);

        // Take the Staked SUI
        let asset_id = receive_staked_sui(vault, staked_sui);

        // Calculates future yield
        let pt_amount = amount+calculate_additional_pt(wrapper, vault, tx_context::epoch(ctx), amount);

        // Mint to the user
        mint_pt(vault, pt_amount, ctx);

        event::emit(MintEvent {
            vault_id: object::id(vault),
            pool_id,
            input_amount: amount,
            asset_id,
            issued_pt: pt_amount,
            sender
        });

    }


    // redeem when the vault reaches its maturity date.
    public entry fun redeem() {
        
    }

    // redeem before the vault matures
    public entry fun redeem_before_maturity() {
        
    }

    // publish events containing vault information for the frontend
    public entry fun publish_vault_info() {

    }

    // estimates the PT output
    public fun estimate_pt_output<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, amount: u64, from_epoch: u64  ) : u64 {
        amount+calculate_additional_pt(wrapper, vault, from_epoch, amount)
    }

    // get supported staking pools
    public fun get_supported_pools<P>(vault: &Vault<P>) : vector<ID> {
        vault.pools
    }

    public fun pt_supply<P>(vault: &Vault<P>) : u64 {
        balance::supply_value<TOKEN<P,PT>>(&vault.pt_supply)
    }

    // avr. apy across staking pools
    public fun vault_apy<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, epoch: u64): u64 {
        calculate_vault_apy(wrapper, vault, epoch)
    }

    // check whether the given address is whitelisted
    public entry fun check_whitelist<P>(vault: &Vault<P>, account: address): bool {
        vector::contains(&vault.whitelist, &account)
    }

    // ======== Only Governance =========

    public entry fun transfer_manager_cap(
        _manager_cap: &ManagerCap,
        to_address: address,
        ctx: &mut TxContext
    ) {
        transfer::transfer(ManagerCap {id: object::new(ctx)}, to_address);
    }

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
        let created_epoch =  tx_context::epoch(ctx);
        assert!( maturity_epoch > created_epoch , E_INVALID_MATURITY);
        assert!( MAX_EPOCH >= maturity_epoch-created_epoch , E_INVALID_MATURITY);

        let holdings = table::new(ctx); 

        // setup PT
        let pt_supply = balance::create_supply(TOKEN<P,PT> {});

        let vault = Vault {
            id: object::new(ctx),
            name,
            symbol,
            rand_nonce: INIT_RAND_NONCE ,
            paused: false,
            created_epoch,
            maturity_epoch,
            pools,
            whitelist: vector::empty<address>(),
            holdings,
            pt_supply,
            asset_count: 0
        };

        transfer::share_object(vault);

        // emit event
        event::emit(NewVaultEvent {
            name,
            symbol,
            created_epoch,
            maturity_epoch
        });
    }

    // add pool to vault
    public entry fun add_pool<P>(
        vault: &mut Vault<P>,
        _manager_cap: &ManagerCap,
        pool_id: ID
    ) {
        assert!(
            !vector::contains(&vault.pools, &pool_id),
            E_DUPLICATED_ENTRY
        );

        vector::push_back<ID>(&mut vault.pools, pool_id);
    }

    // remove pool from reserve
    public entry fun remove_pool<P>(
        vault: &mut Vault<P>,
        _manager_cap: &ManagerCap,
        pool_id: ID
    ) {
        let (contained, index) = vector::index_of<ID>(&vault.pools, &pool_id);
        assert!(
            contained,
            E_NOT_FOUND
        );
        vector::remove<ID>(&mut vault.pools, index);
    }

    // whitelist the user to reserve
    public entry fun whitelist_user<P>(
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

    // de-whitelist the user from reserve
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

    // pause the reserve
    public entry fun pause<P>(
        vault: &mut Vault<P>,
        _manager_cap: &ManagerCap
    ) {
        vault.paused = true;
    }

    // unpause the reserve
    public entry fun unpause<P>(
        vault: &mut Vault<P>,
        _manager_cap: &ManagerCap
    ) {
        vault.paused = false;
    }

    // update vault name 
    public entry fun update_name<P>(vault: &mut Vault<P>, _manager_cap: &ManagerCap, name: String) {
        vault.name = name;
    }

    // update vault symbol 
    public entry fun update_symbol<P>(vault: &mut Vault<P>, _manager_cap: &ManagerCap, symbol: String) {
        vault.symbol = symbol;
    }

    // update rand_nonce
    public entry fun update_rand_nonce<P>(vault: &mut Vault<P>, _manager_cap: &ManagerCap, rand_nonce: u64) {
        vault.rand_nonce = rand_nonce;
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

    fun calculate_additional_pt<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, from_epoch: u64, principal: u64): u64 {

        let apy = calculate_vault_apy(wrapper, vault, from_epoch);
        let for_epoch = vault.maturity_epoch-from_epoch;

        let (for_epoch, apy, principal) = ((for_epoch as u128), (apy as u128), (principal as u128));
        let result = (for_epoch*apy*principal) / (365_000_000_000);

        (result as u64)
    }

    fun calculate_vault_apy<P>(wrapper: &mut SuiSystemState, vault: &mut Vault<P>, epoch: u64): u64 {
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