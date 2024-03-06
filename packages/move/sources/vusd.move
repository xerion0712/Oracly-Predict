// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// module legato::vusd {

//     use std::debug;

//     use sui::balance::{ Self, Supply, Balance };
//     use sui::object::{ Self, UID, ID };
//     use sui::transfer;
//     use sui::url::{Self};
//     use sui::coin::{Self, Coin};
//     use sui::bag::{ Self, Bag};
//     use sui::sui::SUI;
//     use sui::table::{Self, Table};

//     use std::vector;
//     use std::option::{Self};
//     use std::string::{  String }; 

//     use sui_system::sui_system::{ Self, SuiSystemState};
//     use sui_system::staking_pool::{StakedSui};

//     use sui::tx_context::{Self, TxContext};

//     use legato::marketplace::{Self, Marketplace};
//     use legato::vault_lib::{token_to_name};
//     use legato::math::{mul_div};

//     // ======== Constants ======== 

//     const U64_MAX: u64 = 18446744073709551615;
//     const MIST_PER_SUI: u64 = 1_000_000_000;
//     const CLAIM_FEE: u64 = 100000000; // 10%
//     const NEUTRALIZATION_FACTOR: u64 = 700000000; // 70/30
//     const MIN_COLLATERAL_RATIO: u64 = 1010000000; // 101%
//     const MIN_SUI_TO_STAKE: u64 = 1_000_000_000;

//     // ======== Errors ========

//     const E_DUPLICATED_ENTRY: u64 = 101;
//     const E_NOT_FOUND: u64 = 102;
//     const E_INVALID_CONFIG: u64 = 103;
//     const E_ZERO_AMOUNT: u64 = 104;
//     const E_INSUFFICIENT_LIQUIDITY: u64 = 105;
//     const E_TOO_LOW_SUI_TO_STAKE: u64 = 106;
//     const E_TOKEN_NOT_SUPPORT: u64 = 107;
//     const E_TOO_LOW: u64 = 108;
//     const E_TOO_HIGH: u64 = 109;

//     // ======== Structs =========

//     // a cdp-like pool that accepts stablecoins, converts them into SUI -> Staked SUI accordingly
//     // and subsequently issuing a yield-bearing stablecoin mirroring Sui's staking floor APY
//     struct ReversePool has key, store {
//         id: UID,
//         staking_pools: vector<address>, // supported staking pools
//         staking_pool_ids: vector<ID>, // staking pool's ID
//         stablecoins: Table<String, u64>, // supported stablecoins and their conversion rate to VT
//         neutralization_factor: u64, // by default, it's set to 70/30, where 30% of the input will be used for hedging by the team
//         min_collateral_ratio: u64, // the pool will enter a paused state when the ratio falls below this level
//         reserves: Bag, // reserve for hedging, the early version is managed by the team
//         collateral_items: vector<StakedSui>,
//         vt_supply: Supply<VUSD>,
//         total_outstanding: u64, // total VT issued by this pool
//         management_fee: u64,
//         enable_mint: bool,
//         enable_redeem: bool
//     }

//     struct VUSD has drop {} // A yield-bearing token pegged to USD, abbreviated as vUSD

//     // using ManagerCap for vusd.move
//     struct ManagerCap has key {
//         id: UID
//     }

//     fun init(witness: VUSD, ctx: &mut TxContext) {
        
//         // setup VT
//         let (treasury_cap, metadata) = coin::create_currency<VUSD>(witness, 9, b"Legato vUSD", b"vUSD", b"", option::some(url::new_unsafe_from_bytes(b"https://img.tamago.finance/legato/legato-icon.png")), ctx);
//         transfer::public_freeze_object(metadata);

//         let vt_supply = coin::treasury_into_supply<VUSD>(treasury_cap);

//         transfer::transfer(
//             ManagerCap {id: object::new(ctx)},
//             tx_context::sender(ctx)
//         );

//         transfer::share_object(ReversePool {
//             id: object::new(ctx), 
//             staking_pools: vector::empty<address>(),
//             staking_pool_ids: vector::empty<ID>(),
//             stablecoins: table::new(ctx),
//             neutralization_factor: NEUTRALIZATION_FACTOR,
//             min_collateral_ratio: MIN_COLLATERAL_RATIO,
//             collateral_items: vector::empty<StakedSui>(),
//             vt_supply,
//             reserves: bag::new(ctx) ,
//             total_outstanding: 0,
//             management_fee: CLAIM_FEE,
//             enable_mint: true,
//             enable_redeem: true
//         })
//     }

//     // ======== Public Functions =========

//     // mint vUSD 
//     public entry fun mint<P>(
//         _system_state: &mut SuiSystemState,
//         marketplace: &mut Marketplace,
//         reverse_pool: &mut ReversePool, 
//         input_coin: Coin<P>,
//         _output_amount: u64, // number of tokens to mint
//         ctx: &mut TxContext
//     ) {
//         check_input_token<P>(reverse_pool);
//         marketplace::check_quote<P>(marketplace);
//         assert!(coin::value(&input_coin) > 0, E_ZERO_AMOUNT);
    
//         // allocate a portion for delta hedging
//         // coin_allocate<P>(reverse_pool, input_coin);

//         let amount_to_staking = mul_div(coin::value(&input_coin), reverse_pool.neutralization_factor, MIST_PER_SUI);
//         debug::print(&amount_to_staking);

//         transfer::public_transfer(input_coin, tx_context::sender(ctx));

//         // let (remaining_token, base_token) = marketplace::buy<P, SUI>(marketplace, quote_token, bid_price ,ctx);
//         // assert!(coin::value(&remaining_token) == 0, E_INSUFFICIENT_LIQUIDITY);
//         // coin::destroy_zero(remaining_token);

//         // assert!(coin::value(&base_token) >= MIN_SUI_TO_STAKE, E_TOO_LOW_SUI_TO_STAKE);
    
//         // // randomly picking one staking pool
//         // let validator_address = random_staking_pool(reverse_pool, ctx);
//         // // staking & attaching to the collateral pool
//         // let staked_sui = sui_system::request_add_stake_non_entry(system_state, base_token, validator_address, ctx);
//         // vector::push_back<StakedSui>(&mut reverse_pool.collateral_items, staked_sui);


//     }

//     public entry fun burn(reverse_pool: &mut ReversePool, input_coin: Coin<VUSD>) {
//         balance::decrease_supply(&mut reverse_pool.vt_supply, coin::into_balance(input_coin));
//     }

//     // ======== Only Governance =========


//     public entry fun update_config(
//         reverse_pool: &mut ReversePool,
//         _manager_cap: &ManagerCap,
//         neutralization_factor: u64,
//         min_collateral_ratio: u64,
//         management_fee: u64,
//         enable_mint: bool,
//         enable_redeem: bool
//     ) {
//         assert!( 1_000_000_000 >= neutralization_factor && neutralization_factor >= 500_000_000, E_INVALID_CONFIG); // within 100%-50%
//         assert!( 10_000_000_000 >= min_collateral_ratio && min_collateral_ratio >= 500_000_000 , E_INVALID_CONFIG); // within 1000%-50%
//         assert!( 200_000_000 >= management_fee , E_INVALID_CONFIG); // <20%
//         reverse_pool.neutralization_factor = neutralization_factor;
//         reverse_pool.min_collateral_ratio = min_collateral_ratio;
//         reverse_pool.management_fee = management_fee;
//         reverse_pool.enable_mint = enable_mint;
//         reverse_pool.enable_redeem = enable_redeem;
//     }

//     // add support staking pool on reverse pool
//     public entry fun attach_pool(reverse_pool: &mut ReversePool, _manager_cap: &ManagerCap, pool_address:address, pool_id: ID) {
//         assert!(!vector::contains(&reverse_pool.staking_pools, &pool_address), E_DUPLICATED_ENTRY);
//         vector::push_back<address>(&mut reverse_pool.staking_pools, pool_address);
//         vector::push_back<ID>(&mut reverse_pool.staking_pool_ids, pool_id);
//     }

//     // remove support staking pool on reverse pool
//     public entry fun detach_pool(reverse_pool: &mut ReversePool ,_manager_cap: &ManagerCap, pool_address: address) {
//         let (contained, index) = vector::index_of<address>(&reverse_pool.staking_pools, &pool_address);
//         assert!(contained, E_NOT_FOUND);
//         vector::remove<address>(&mut reverse_pool.staking_pools, index);
//         vector::remove<ID>(&mut reverse_pool.staking_pool_ids, index);
//     }

//     // add support stablecoin
//     public entry fun register_stablecoin<P>(reverse_pool: &mut ReversePool, conversion_rate: u64, _manager_cap: &ManagerCap) {
//         assert!( conversion_rate >= 500_000_000 , E_TOO_LOW);
//         assert!( 1_500_000_000 >= conversion_rate , E_TOO_HIGH);
//         let token_name = token_to_name<P>();
//         assert!( !table::contains(&reverse_pool.stablecoins,  token_name), E_DUPLICATED_ENTRY);
//         table::add(&mut reverse_pool.stablecoins, token_name, conversion_rate);
//     }

//     // remove support stablecoin
//     public entry fun deregister_stablecoin<P>(reverse_pool: &mut ReversePool ,_manager_cap: &ManagerCap) {
//         let token_name = token_to_name<P>();
//         table::remove(&mut reverse_pool.stablecoins, token_name);
//     }

//     // minting VUSD that bypasses the collateral ratio wall 
//     public entry fun force_mint<P>(system_state: &mut SuiSystemState, marketplace: &mut Marketplace, reverse_pool: &mut ReversePool,
//         _manager_cap: &ManagerCap, input_coin: Coin<P>, output_amount: u64, recipient_address: address, ctx: &mut TxContext) {
//         check_input_token<P>(reverse_pool);
//         marketplace::check_quote<P>(marketplace);
//         assert!(coin::value(&input_coin) > 0, E_ZERO_AMOUNT);
    
//         // allocate a portion for delta hedging
//         let (for_staking, for_hedging) = coin_allocate<P>(reverse_pool, input_coin, ctx);
//         put_to_reserve<P>(reverse_pool, for_hedging);

//         debug::print(&output_amount);
//         debug::print(&coin::value(&for_staking));

//         // acquire SUI from marketplace.move
//         let (remaining_token, sui_token) = marketplace::buy<P, SUI>(marketplace, for_staking, U64_MAX ,ctx);
//         assert!(coin::value(&remaining_token) == 0, E_INSUFFICIENT_LIQUIDITY);
//         coin::destroy_zero(remaining_token);

//         debug::print(&coin::value(&sui_token));

//         assert!(coin::value(&sui_token) >= MIN_SUI_TO_STAKE, E_TOO_LOW_SUI_TO_STAKE);
    
//         // randomly picking one staking pool
//         let validator_address = random_staking_pool_address(reverse_pool, ctx);
//         // staking & attaching to the collateral pool
//         let staked_sui = sui_system::request_add_stake_non_entry(system_state, sui_token, validator_address, ctx);
//         vector::push_back<StakedSui>(&mut reverse_pool.collateral_items, staked_sui);

//         // mint VT
//         let minted_balance = balance::increase_supply(&mut reverse_pool.vt_supply, output_amount);
//         transfer::public_transfer(coin::from_balance(minted_balance, ctx), recipient_address);

//     }

//     public entry fun withdraw_reserve<P>(reverse_pool: &mut ReversePool, _manager_cap: &ManagerCap, withdraw_amount: u64, destination_address: address) {
//         check_input_token<P>(reverse_pool);
//         assert!(withdraw_amount > 0, E_ZERO_AMOUNT);
//     }

//     // ======== Internal Functions =========

//     fun random_staking_pool_address(reverse_pool: &ReversePool, ctx: &mut TxContext):address {
//         let random_id = (tx_context::epoch(ctx)) % vector::length(&reverse_pool.staking_pools);
//         *vector::borrow<address>(&reverse_pool.staking_pools, random_id)
//     }

//     fun check_input_token<P>(reverse_pool: &ReversePool) {
//         let token_name = token_to_name<P>();
//         assert!(table::contains(&reverse_pool.stablecoins,  token_name), E_TOKEN_NOT_SUPPORT);
//     }

//     fun coin_allocate<P>(reverse_pool: &ReversePool, input_coin: Coin<P>, ctx: &mut TxContext) : (Coin<P>, Coin<P>) {
//         let amount_to_staking = mul_div(coin::value(&input_coin), reverse_pool.neutralization_factor, MIST_PER_SUI);
//         let splited_coin = coin::split(&mut input_coin, amount_to_staking, ctx);
//         (splited_coin, input_coin)
//     }

//     fun put_to_reserve<P>(reverse_pool: &mut ReversePool, coin: Coin<P>) {
//         let token_name = token_to_name<P>();
//         let has_registered = bag::contains_with_type<String, Balance<P>>(&reverse_pool.reserves, token_name);

//         if (!has_registered) {
//             bag::add(&mut reverse_pool.reserves, token_name, coin::into_balance(coin));
//         } else {
//             let token_reserve = bag::borrow_mut<String, Balance<P>>(&mut reverse_pool.reserves, token_name);
//             balance::join(token_reserve, coin::into_balance(coin));
//         };
//     }

//     // ======== Test-related Functions =========

//     #[test_only]
//     public fun test_init(ctx: &mut TxContext) {
//         init( VUSD {} ,ctx);
//     } 
// }

// module legato::vusd {

//     // use std::debug;

//     use sui::object::{ Self, UID, ID };
//     use sui::balance::{ Self, Supply, Balance };
//     use sui::tx_context::{Self, TxContext};
//     use sui::transfer;
//     use sui::url::{Self};
//     use sui::bag::{ Self, Bag};
//     use sui::coin::{Self, Coin};
//     use sui::table::{Self, Table};
//     use sui::sui::SUI;

//     use std::vector;
//     use std::option::{Self};
//     use std::string::{String }; 

//     use sui_system::sui_system::{Self, SuiSystemState};
//     use sui_system::staking_pool::{Self, StakedSui};

//     use legato::vault_lib::{token_to_name};
//     use legato::marketplace::{Self, Marketplace};
//     use legato::math::{mul_div};
//     use legato::event::{vusd_mint_event};

//     // ======== Constants ========

//     const U64_MAX: u64 = 18446744073709551615;
//     const DEFAULT_FEE: u64 = 100000000; // 10%
//     const NEUTRALIZATION_FACTOR: u64 = 800000000; // 80/20
//     const MIST_PER_SUI: u64 = 1_000_000_000;
//     const MIN_SUI_TO_STAKE: u64 = 1_000_000_000;

//     // ======== Errors ========

//     const E_DUPLICATED_ENTRY: u64 = 101;
//     const E_TOO_HIGH: u64 = 102;
//     const E_TOO_LOW: u64 = 103;
//     const E_NOT_FOUND: u64 = 104;
//     const E_ZERO_VALUE: u64 = 105;
//     const E_TOKEN_NOT_SUPPORT: u64 = 106;
//     const E_ZERO_AMOUNT: u64 = 108;
//     const E_INVALID_CONFIG: u64 = 109;
//     const E_ACTIVE_POSITION: u64 = 110;
//     const E_INSUFFICIENT_LIQUIDITY: u64 = 111;
//     const E_TOO_LOW_SUI_TO_STAKE: u64 = 112;

//     // ======== Structs =========

//     // a cdp-like pool that accepts stablecoins, converts them into SUI -> Staked SUI accordingly
//     // and subsequently issuing a yield-bearing stablecoin mirroring Sui's staking floor APY
//     struct PositionManager has key, store {
//         id: UID,
//         staking_pools: vector<address>, // supported staking pools
//         staking_pool_ids: vector<ID>, // staking pool's ID
//         stablecoins: Table<String, u64>, // supported stablecoins and their conversion rate to VT
//         neutralization_factor: u64, // by default, it's set to 80/20, with 20% of the input used for hedging
//         positions: Table<address, Position>, // each sponsor can have only one position
//         sponsor_list: vector<address>,
//         reserves: Bag, // reserve for hedging, the early version is managed by the team
//         fee: u64,
//         vt_supply: Supply<VUSD>,
//         total_raw_collateral_amount: u64,
//         total_hedging_amount: u64,
//         enable_mint: bool,
//         enable_redeem: bool
//     }

//     struct Position has store {
//         tokens_outstanding: u64,
//         neutralization_factor: u64,
//         raw_collateral_item: StakedSui,
//         hedging_amount: u64,
//         hedging_currency: String,
//         created_epoch: u64,
//         owner: address
//     }

//     struct VUSD has drop {} // A yield-bearing token pegged to USD, abbreviated as vUSD

//     struct ManagerCap has key {
//         id: UID
//     }

//     fun init(witness: VUSD, ctx: &mut TxContext) {
        
//         // setup VT
//         let (treasury_cap, metadata) = coin::create_currency<VUSD>(witness, 9, b"Legato vUSD", b"vUSD", b"", option::some(url::new_unsafe_from_bytes(b"https://img.tamago.finance/legato/legato-icon.png")), ctx);
//         transfer::public_freeze_object(metadata);

//         let vt_supply = coin::treasury_into_supply<VUSD>(treasury_cap);

//         transfer::transfer(
//             ManagerCap {id: object::new(ctx)},
//             tx_context::sender(ctx)
//         );

//         transfer::share_object(PositionManager {
//             id: object::new(ctx), 
//             staking_pools: vector::empty<address>(),
//             staking_pool_ids: vector::empty<ID>(),
//             stablecoins: table::new(ctx),
//             vt_supply,
//             positions: table::new(ctx),
//             sponsor_list: vector::empty<address>(),
//             reserves: bag::new(ctx),
//             total_raw_collateral_amount: 0,
//             total_hedging_amount: 0,
//             neutralization_factor: NEUTRALIZATION_FACTOR,
//             fee: DEFAULT_FEE,
//             enable_mint: true,
//             enable_redeem: true
//         })

//     }

    

//     // ======== Public Functions =========

//     // mint vUSD
//     // public entry fun mint<P>(reverse_pool: &mut PositionManager) {
        
//     // }

//     // public entry fun repay(reverse_pool: &mut PositionManager) {

//     // }

//     // public entry fun redeem(reverse_pool: &mut PositionManager) {

//     // }

//     // ======== Only Governance =========

//     // add support staking pool on reverse pool
//     public entry fun attach_pool(position_manager: &mut PositionManager, _manager_cap: &ManagerCap, pool_address:address, pool_id: ID) {
//         assert!(!vector::contains(&position_manager.staking_pools, &pool_address), E_DUPLICATED_ENTRY);
//         vector::push_back<address>(&mut position_manager.staking_pools, pool_address);
//         vector::push_back<ID>(&mut position_manager.staking_pool_ids, pool_id);
//     }

//     // remove support staking pool on reverse pool
//     public entry fun detach_pool(position_manager: &mut PositionManager ,_manager_cap: &ManagerCap, pool_address: address) {
//         let (contained, index) = vector::index_of<address>(&position_manager.staking_pools, &pool_address);
//         assert!(contained, E_NOT_FOUND);
//         vector::remove<address>(&mut position_manager.staking_pools, index);
//         vector::remove<ID>(&mut position_manager.staking_pool_ids, index);
//     }

//     // add support stablecoin
//     public entry fun register_stablecoin<P>(position_manager: &mut PositionManager, conversion_rate: u64, _manager_cap: &ManagerCap) {
//         assert!( conversion_rate >= 500_000_000 , E_TOO_LOW);
//         assert!( 1_500_000_000 >= conversion_rate , E_TOO_HIGH);
//         let token_name = token_to_name<P>();
//         assert!( !table::contains(&position_manager.stablecoins,  token_name), E_DUPLICATED_ENTRY);
//         table::add(&mut position_manager.stablecoins, token_name, conversion_rate);
//     }

//     // remove support stablecoin
//     public entry fun deregister_stablecoin<P>(position_manager: &mut PositionManager ,_manager_cap: &ManagerCap) {
//         let token_name = token_to_name<P>();
//         table::remove(&mut position_manager.stablecoins, token_name);
//     }

//     // allows minting with a custom collateral ratio, aiming for the first mint or when the collateral ratio falls below a certain poin
//     public entry fun force_mint<P>(system_state: &mut SuiSystemState, marketplace: &mut Marketplace, position_manager: &mut PositionManager,
//         _manager_cap: &ManagerCap, input_coin: Coin<P>, output_amount: u64, recipient_address: address, ctx: &mut TxContext) {
//         check_input_token<P>(position_manager);
//         marketplace::check_quote<P>(marketplace);
//         assert!(coin::value(&input_coin) > 0, E_ZERO_AMOUNT);

//         mint_<P>(system_state, marketplace, position_manager, input_coin, output_amount, recipient_address, ctx);
//     }

//     public entry fun set_fee(position_manager: &mut PositionManager, _manager_cap: &ManagerCap, value: u64) {
//         assert!( value > 0 , E_ZERO_VALUE);
//         position_manager.fee = value;
//     }

//     public entry fun enable_mint(position_manager: &mut PositionManager, _manager_cap: &ManagerCap, value: bool) {
//         position_manager.enable_mint = value;
//     }

//     public entry fun enable_redeem(position_manager: &mut PositionManager, _manager_cap: &ManagerCap, value: bool) {
//         position_manager.enable_redeem = value;
//     }

//     public entry fun set_neutralization_factor(position_manager: &mut PositionManager, _manager_cap: &ManagerCap, neutralization_factor: u64) {
//         assert!( 1_000_000_000 >= neutralization_factor && neutralization_factor >= 500_000_000, E_INVALID_CONFIG); // within 100%-50%
//         position_manager.neutralization_factor = neutralization_factor;
//     }

//     public entry fun withdraw_reserve<P>(position_manager: &mut PositionManager, _manager_cap: &ManagerCap, withdraw_amount: u64, destination_address: address, ctx: &mut TxContext) {
//         check_input_token<P>(position_manager);
//         assert!(withdraw_amount > 0, E_ZERO_AMOUNT);

//         let token_name = token_to_name<P>();
//         let token_reserve = bag::borrow_mut<String, Balance<P>>(&mut position_manager.reserves, token_name);
//         let payout_balance = balance::split<P>(token_reserve, withdraw_amount);
//         transfer::public_transfer(coin::from_balance(payout_balance, ctx), destination_address);
//     }
    
//     public fun collateral_ratio(position_manager: &PositionManager, sponsor_address: address): u64 {
        
//     }

//     public fun global_collateral_ratio(position_manager: &PositionManager): u64 {
        
//     }
    
//     // ======== Internal Functions =========

//     fun check_input_token<P>(position_manager: &PositionManager) {
//         let token_name = token_to_name<P>();
//         assert!(table::contains(&position_manager.stablecoins,  token_name), E_TOKEN_NOT_SUPPORT);
//     }

//     fun coin_allocate<P>(position_manager: &PositionManager, input_coin: Coin<P>, ctx: &mut TxContext) : (Coin<P>, Coin<P>) {
//         let amount_to_staking = mul_div(coin::value(&input_coin), position_manager.neutralization_factor, MIST_PER_SUI);
//         let splited_coin = coin::split(&mut input_coin, amount_to_staking, ctx);
//         (splited_coin, input_coin)
//     }

//     fun random_staking_pool(position_manager: &PositionManager, ctx: &mut TxContext): address {
//         let random_id = (tx_context::epoch(ctx)) % vector::length(&position_manager.staking_pools);
//         *vector::borrow<address>(&position_manager.staking_pools, random_id)
//     }

//     fun mint_<P>(system_state: &mut SuiSystemState, marketplace: &mut Marketplace, position_manager: &mut PositionManager, input_coin: Coin<P>, output_amount: u64, recipient_address: address, ctx: &mut TxContext) {
//         assert!( !table::contains( &position_manager.positions, tx_context::sender(ctx) ), E_ACTIVE_POSITION);
//         let input_amount = coin::value(&input_coin);

//         // allocate a portion for delta hedging
//         let (for_staking, for_hedging) = coin_allocate<P>(position_manager, input_coin, ctx);
//         let hedging_amount = coin::value(&for_hedging);
//         let hedging_currency = token_to_name<P>();

//         put_to_reserve<P>(position_manager, for_hedging);

//         // acquire SUI from marketplace.move
//         let (remaining_token, sui_token) = marketplace::buy<P, SUI>(marketplace, for_staking, U64_MAX ,ctx);
//         assert!(coin::value(&remaining_token) == 0, E_INSUFFICIENT_LIQUIDITY);
//         coin::destroy_zero(remaining_token);

//         assert!(coin::value(&sui_token) >= MIN_SUI_TO_STAKE, E_TOO_LOW_SUI_TO_STAKE);

//         // randomly picking one staking pool
//         let validator_address = random_staking_pool(position_manager, ctx);
//         // staking
//         let staked_sui = sui_system::request_add_stake_non_entry(system_state, sui_token, validator_address, ctx);
//         // mint VT
//         let minted_balance = balance::increase_supply(&mut position_manager.vt_supply, output_amount);
//         transfer::public_transfer(coin::from_balance(minted_balance, ctx), recipient_address);

//         let collateral_staked_sui_amount = staking_pool::staked_sui_amount(&staked_sui);
//         position_manager.total_raw_collateral_amount = position_manager.total_raw_collateral_amount+collateral_staked_sui_amount;
//         position_manager.total_hedging_amount = position_manager.total_hedging_amount+hedging_amount;

//         let sender = tx_context::sender(ctx);

//         let position = Position {
//             tokens_outstanding: output_amount,
//             neutralization_factor: position_manager.neutralization_factor,
//             raw_collateral_item: staked_sui,
//             hedging_amount,
//             hedging_currency,
//             created_epoch: tx_context::epoch(ctx),
//             owner: sender
//         };

//         table::add(&mut position_manager.positions, sender, position);

//         // add to sponsor_list
//         let (contained, _) = vector::index_of<address>(&position_manager.sponsor_list, &sender);
//         if (!contained) {
//             vector::push_back<address>(&mut position_manager.sponsor_list, sender);
//         };

//         // emit event
//         vusd_mint_event(
//             object::id(position_manager),
//             hedging_currency,
//             input_amount,
//             position_manager.neutralization_factor,
//             hedging_amount,
//             collateral_staked_sui_amount,
//             tx_context::epoch(ctx),
//             sender
//         );
        
//     }

//     fun put_to_reserve<P>(position_manager: &mut PositionManager, coin: Coin<P>) {
//         let token_name = token_to_name<P>();
//         let has_registered = bag::contains_with_type<String, Balance<P>>(&position_manager.reserves, token_name);

//         if (!has_registered) {
//             bag::add(&mut position_manager.reserves, token_name, coin::into_balance(coin));
//         } else {
//             let token_reserve = bag::borrow_mut<String, Balance<P>>(&mut position_manager.reserves, token_name);
//             balance::join(token_reserve, coin::into_balance(coin));
//         };
//     }

//     fun collateral_ratio(position_manager: &PositionManager, sponsor_address: address): u64 {
        
//     }

//     fun global_collateral_ratio_(position_manager: &PositionManager): u64 {

//     }

//     // ======== Test-related Functions =========

//     #[test_only]
//     public fun test_init(ctx: &mut TxContext) {
//         init( VUSD {} ,ctx);
//     }

// }