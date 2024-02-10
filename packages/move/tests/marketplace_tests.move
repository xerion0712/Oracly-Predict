#[test_only]
module legato::marketplace_tests {

    // use std::debug;

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::coin::{Self, Coin};

    use legato::marketplace::{Self, Marketplace, ManagerCap };

    const ADMIN_ADDR: address = @0x21;

    const USER_ADDR_1: address = @0x42;
    const USER_ADDR_2: address = @0x43;
    const USER_ADDR_3: address = @0x44;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    struct USDC {}

    struct PT {}

    #[test]
    public fun test_update_orders() {
        let scenario = scenario();
        test_update_orders_(&mut scenario);
        test::end(scenario);
    }

    #[test]
    public fun test_sell_and_buy() {
        let scenario = scenario();
        test_sell_and_buy_(&mut scenario);
        test::end(scenario);
    }

    #[test]
    public fun test_buy_and_sell() {
        let scenario = scenario();
        test_buy_and_sell_(&mut scenario);
        test::end(scenario);
    }

    fun test_update_orders_(test: &mut Scenario) {
        // setup quote currencies
        setup_quote(test, ADMIN_ADDR);

        // listing PT for USDC
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 900_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 1000_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 1100_000_000 , ctx(test));
            test::return_shared(global);
        };

        // updating & deleting ask order
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::update_order<PT, USDC>(&mut global, 1, 950_000_000 , ctx(test));
            marketplace::cancel_order<PT, USDC>(&mut global, 1, ctx(test));
            test::return_shared(global);
        };

        // listing USDC for PT
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::buy_and_listing<USDC, PT>(&mut global, coin::mint_for_testing<USDC>( 100 * MIST_PER_SUI, ctx(test)), 1200_000_000, ctx(test));
            test::return_shared(global);
        };

        // updating & deleting bid order
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::update_order<PT, USDC>(&mut global, 4, 1150_000_000 , ctx(test));
            marketplace::cancel_order<PT, USDC>(&mut global, 4, ctx(test));
            test::return_shared(global);
        };

    }

    fun test_sell_and_buy_(test: &mut Scenario) {
        // setup quote currencies
        setup_quote(test, ADMIN_ADDR);

        // listing PT for USDC
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 900_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 400_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 800_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 600_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 100 * MIST_PER_SUI, ctx(test)), 700_000_000 , ctx(test));
            test::return_shared(global);
        };

        // buying PT with USDC
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::buy_only<USDC, PT>(&mut global, coin::mint_for_testing<USDC>( 150 * MIST_PER_SUI, ctx(test)), 800_000_000 , ctx(test));
            test::return_shared(global);
        };

        // checking 
        next_tx(test, USER_ADDR_2);
        {
            let pt_token = test::take_from_sender<Coin<PT>>(test);
            let pt_value = coin::value(&pt_token);
            assert!(pt_value == 271428571428, 1);

            test::return_to_sender(test, pt_token);
        };

    }

    fun test_buy_and_sell_(test: &mut Scenario) {
        
        // setup quote currencies
        setup_quote(test, ADMIN_ADDR);

        // listing PT for USDC
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::sell_and_listing<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 10 * MIST_PER_SUI, ctx(test)), 300_000_000 , ctx(test));
            test::return_shared(global);
        };

        // buying PT for 10 USDC and listing the remaining
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::buy_and_listing<USDC, PT>(&mut global, coin::mint_for_testing<USDC>( 100 * MIST_PER_SUI, ctx(test)), 350_000_000 , ctx(test));
            test::return_shared(global);
        };

        // selling PT for USDC
        next_tx(test, USER_ADDR_3);
        {
            let global = test::take_shared<Marketplace>(test); 
            marketplace::sell_only<PT, USDC>(&mut global, coin::mint_for_testing<PT>( 20 * MIST_PER_SUI, ctx(test)), 330_000_000 , ctx(test));
            test::return_shared(global);
        };

        // checking 
        next_tx(test, USER_ADDR_3);
        {
            let usdc_token = test::take_from_sender<Coin<USDC>>(test);
            let usdc_value = coin::value(&usdc_token);
            assert!(usdc_value == 7_000_000_000, 2);
            test::return_to_sender(test, usdc_token);
        };
    
    }

    fun setup_quote(test: &mut Scenario, admin_address: address) {
        
        next_tx(test, admin_address);
        {
            marketplace::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let global = test::take_shared<Marketplace>(test);
            let managercap = test::take_from_sender<ManagerCap>(test);
            marketplace::setup_quote<USDC>(&mut global, &mut managercap,  ctx(test));
            test::return_shared(global);
            test::return_to_sender(test, managercap);
        };

        

    }

    

    fun scenario(): Scenario { test::begin(@0x1) }
}