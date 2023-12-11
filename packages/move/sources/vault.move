

module legato::vault {

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID , ID};
    use sui::transfer; 
    use sui::table::{Self, Table};
    use std::vector;

    use sui_system::sui_system::{SuiSystemState };
    use sui_system::staking_pool::{Self, StakedSui};

    use legato::apy_reader::{Self};

    // ======== Constants ========
    const MIST_PER_SUI : u64 = 1_000_000_000;
    const EPOCH_OPTIONS : vector<u8> = vector[0,10,30];

    // ======== Errors ========
    const E_EMPTY_VECTOR: u64 = 1;
    const E_DUPLICATED_ENTRY: u64 = 2;
    const E_NOT_FOUND: u64 = 3;
    const E_MIN_THRESHOLD: u64 = 4;
    const E_INSUFFICIENT_AMOUNT: u64 = 5;
    const E_RESERVE_PAUSED: u64 = 6;
    const E_UNAUTHOIZED: u64 = 7;

    // ======== Structs =========

    struct ManagerCap has key {
        id: UID
    }

    struct DepositInfo has store {
        
    }

    struct Reserve has key {
        id: UID,
        paused: bool,
        start_epoch: u64,
        pools: vector<ID>, // supported staking pools
        whitelist: vector<address>, // whitelisting users (will be removed in the next version)
        deposited: Table<u64, StakedSui>,
        deposited_info: Table<u64, DepositInfo>,
        deposit_count: u64
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

    // convert Staked SUI to receive PT
    public entry fun lock(
        reserve: &mut Reserve,
        staked_sui: &mut StakedSui,
        amount: u64,
        for_epoch: u8,
        ctx: &mut TxContext
    ) {
        assert!(vector::contains(&EPOCH_OPTIONS, &for_epoch), E_NOT_FOUND);
        assert!(amount >= MIST_PER_SUI,E_MIN_THRESHOLD);
        assert!(staking_pool::staked_sui_amount(staked_sui) >= amount, E_INSUFFICIENT_AMOUNT);

        assert!(reserve.paused == true, E_RESERVE_PAUSED);

        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&reserve.whitelist, &sender), E_UNAUTHOIZED);

        let asset_locked = staking_pool::split(staked_sui, amount, ctx);

        table::add(
            &mut reserve.deposited,
            reserve.deposit_count,
            asset_locked
        );

        reserve.deposit_count = reserve.deposit_count + 1;

        // send the caller YT tokens

    }

    public entry fun staking_pools(reserve: &Reserve) : vector<ID> {
        reserve.pools
    }

    public entry fun vault_apy(wrapper: &mut SuiSystemState, reserve: &Reserve, epoch: u64): u64 {
        let count = vector::length(&reserve.pools);
        let i = 0;
        let total_sum = 0;
        while (i < count) {
            let pool_id = vector::borrow(&reserve.pools, i);

            total_sum = total_sum+apy_reader::pool_apy(wrapper, pool_id, epoch);
            
            i = i + 1;
        };
        total_sum / i
    }

    public entry fun check_whitelist(reserve: &Reserve, account: address): bool {
        vector::contains(&reserve.whitelist, &account)
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
    public entry fun new_vault(
        _manager_cap: &mut ManagerCap,
        pools: vector<ID>,
        ctx: &mut TxContext
    ) {
        assert!(vector::length<ID>(&pools) > 0, E_EMPTY_VECTOR);

        let deposited = table::new(ctx);
        let deposited_info = table::new(ctx);

        let reserve = Reserve {
            id: object::new(ctx),
            paused: false,
            start_epoch: tx_context::epoch(ctx),
            pools,
            whitelist: vector::empty<address>(),
            deposited,
            deposited_info,
            deposit_count: 0
        };

        transfer::share_object(reserve);
    }

    // add pool to reserve
    public entry fun add_pool(
        reserve: &mut Reserve,
        _manager_cap: &ManagerCap,
        pool_id: ID
    ) {
        assert!(
            !vector::contains(&reserve.pools, &pool_id),
            E_DUPLICATED_ENTRY
        );

        vector::push_back<ID>(&mut reserve.pools, pool_id);
    }

    // remove pool from reserve
    public entry fun remove_pool(
        reserve: &mut Reserve,
        _manager_cap: &ManagerCap,
        pool_id: ID
    ) {
        let (contained, index) = vector::index_of<ID>(&reserve.pools, &pool_id);
        assert!(
            contained,
            E_NOT_FOUND
        );
        vector::remove<ID>(&mut reserve.pools, index);
    }

    // whitelist the user to reserve
    public entry fun whitelist_user(
        reserve: &mut Reserve,
        _manager_cap: &ManagerCap,
        user: address
    ) {
        assert!(
            !vector::contains(&reserve.whitelist, &user),
            E_DUPLICATED_ENTRY
        );

        vector::push_back<address>(&mut reserve.whitelist, user);
    }

    // de-whitelist the user from reserve
    public entry fun remove_user(
        reserve: &mut Reserve,
        _manager_cap: &ManagerCap,
        user: address
    ) {
        let (contained, index) = vector::index_of<address>(&reserve.whitelist, &user);
        assert!(
            contained,
            E_NOT_FOUND
        );
        vector::remove<address>(&mut reserve.whitelist, index);
    }

    // pause the reserve
    public entry fun pause(
        reserve: &mut Reserve,
        _manager_cap: &ManagerCap
    ) {
        reserve.paused = true;
    }

    // unpause the reserve
    public entry fun unpause(
        reserve: &mut Reserve,
        _manager_cap: &ManagerCap
    ) {
        reserve.paused = false;
    }

}