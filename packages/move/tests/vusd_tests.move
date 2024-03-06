// #[test_only]
// module legato::vusd_tests {

//     use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
//     use sui::coin::{Self};
//     use sui_system::sui_system::{ SuiSystemState };
//     use sui::tx_context::{Self};

//     use legato::vault_utils::{
//         scenario, 
//         advance_epoch, 
//         set_up_sui_system_state,
//         setup_marketplace,
//         setup_vusd,
//         USDC
//     };

//     use legato::vusd::{Self, ReversePool, ManagerCap};
//     use legato::marketplace::{Marketplace};

//     const VALIDATOR_ADDR_1: address = @0x1;
//     const VALIDATOR_ADDR_2: address = @0x2;
//     const VALIDATOR_ADDR_3: address = @0x3;
//     const VALIDATOR_ADDR_4: address = @0x4;

//     const ADMIN_ADDR: address = @0x21;

//     const USER_ADDR_1: address = @0x42;
//     const USER_ADDR_2: address = @0x43;
//     const USER_ADDR_3: address = @0x44;

//     const MIST_PER_SUI: u64 = 1_000_000_000;

//     // ======== Asserts ========
//     const ASSERT_CHECK_VALUE: u64 = 1;
//     const ASSERT_CHECK_EPOCH: u64 = 2;

//     #[test]
//     public fun test_vusd() {
//         let scenario = scenario();
//         test_vusd_(&mut scenario);
//         test::end(scenario);
//     }

//     fun test_vusd_(test: &mut Scenario) {
//         set_up_sui_system_state();
//         advance_epoch(test, 40); // <-- overflow when less than 40

//         // setup marketplace
//         setup_marketplace(test, ADMIN_ADDR);

//         // setup vusd
//         setup_vusd(test, ADMIN_ADDR);

//         // first mint
//         next_tx(test, ADMIN_ADDR);
//         {
//             let system_state = test::take_shared<SuiSystemState>(test);
//             let reserve_pool = test::take_shared<ReversePool>(test);
//             let marketplace = test::take_shared<Marketplace>(test);
//             let managercap = test::take_from_sender<ManagerCap>(test);

//             vusd::force_mint<USDC>(&mut system_state, &mut marketplace, &mut reserve_pool, &mut managercap, coin::mint_for_testing<USDC>( 100 * MIST_PER_SUI, ctx(test)), 100_000_000, tx_context::sender(ctx(test)) ,ctx(test));

//             test::return_shared(reserve_pool);
//             test::return_shared(marketplace);
//             test::return_shared(system_state);
//             test::return_to_sender(test, managercap);
//         };

//     }

// }

// #[test_only]
// module legato::vusd_tests {

//     use sui::test_scenario::{Self as test, Scenario, next_tx, ctx };
//     use sui::coin::{Self};
//     use sui_system::sui_system::{ SuiSystemState };
//     use sui::tx_context::{Self};

//     use legato::vault_utils::{
//         scenario,
//         advance_epoch,
//         set_up_sui_system_state,
//         setup_marketplace,
//         setup_vusd,
//         USDC
//     };

//     use legato::vusd::{ Self, PositionManager, ManagerCap};
//     use legato::marketplace::{Marketplace};

//     const VALIDATOR_ADDR_1: address = @0x1;
//     const VALIDATOR_ADDR_2: address = @0x2;
//     const VALIDATOR_ADDR_3: address = @0x3;
//     const VALIDATOR_ADDR_4: address = @0x4;

//     const ADMIN_ADDR: address = @0x21;

//     const USER_ADDR_1: address = @0x42;
//     const USER_ADDR_2: address = @0x43;
//     const USER_ADDR_3: address = @0x44;

//     const MIST_PER_SUI: u64 = 1_000_000_000;

//     // ======== Asserts ========
//     const ASSERT_CHECK_VALUE: u64 = 1;
//     const ASSERT_CHECK_EPOCH: u64 = 2;

//     #[test]
//     public fun test_vusd() {
//         let scenario = scenario();
//         test_vusd_(&mut scenario);
//         test::end(scenario);
//     }

//     fun test_vusd_(test: &mut Scenario) {
//         set_up_sui_system_state();
//         advance_epoch(test, 40); // <-- overflow when less than 40

//         // setup marketplace
//         setup_marketplace(test, ADMIN_ADDR);

//         // setup vusd
//         setup_vusd(test, ADMIN_ADDR);

//         next_tx(test, ADMIN_ADDR);
//         {
//             let system_state = test::take_shared<SuiSystemState>(test);
//             let position_manager = test::take_shared<PositionManager>(test);
//             let marketplace = test::take_shared<Marketplace>(test);
//             let managercap = test::take_from_sender<ManagerCap>(test);

//             // force mint at CR 200%
//             vusd::force_mint<USDC>(&mut system_state, &mut marketplace, &mut position_manager, &mut managercap, coin::mint_for_testing<USDC>( 200 * MIST_PER_SUI, ctx(test)), 100_000_000, tx_context::sender(ctx(test)) ,ctx(test));

//             test::return_shared(position_manager);
//             test::return_shared(marketplace);
//             test::return_shared(system_state);
//             test::return_to_sender(test, managercap);
//         };

//         next_tx(test, ADMIN_ADDR);
//         {
//             let system_state = test::take_shared<SuiSystemState>(test);
//             let position_manager = test::take_shared<PositionManager>(test);
//             let marketplace = test::take_shared<Marketplace>(test);
//             let managercap = test::take_from_sender<ManagerCap>(test);




//             test::return_shared(position_manager);
//             test::return_shared(marketplace);
//             test::return_shared(system_state);
//             test::return_to_sender(test, managercap);
//         };



//     }



// }