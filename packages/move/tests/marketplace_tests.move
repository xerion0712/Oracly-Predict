

#[test_only]
module legato::marketplace_tests {

    // use std::debug;

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};

    use legato::marketplace::{Self, GlobalMarketplace };

    const ADMIN_ADDR: address = @0x21;

    const USER_ADDR_1: address = @0x42;
    const USER_ADDR_2: address = @0x43;
    const USER_ADDR_3: address = @0x44;

    const MOCK_MINT_AMOUNT: u64 = 500_000_000_000;
    const MIST_PER_SUI: u64 = 1_000_000_000;

    struct USDC {}

    struct PT {}

    #[test]
    public fun test_add_balances() {
        let scenario = scenario();
        test_add_balances_(&mut scenario);
        test::end(scenario);
    }

    #[test]
    public fun test_modify_orders() {
        let scenario = scenario();
        test_modify_orders_(&mut scenario);
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

    fun test_add_balances_(test: &mut Scenario) {

        // setup quote currencies
        setup_quote(test, ADMIN_ADDR);
        
        let mock_usdc = coin::mint_for_testing<USDC>(MOCK_MINT_AMOUNT, ctx(test));
        let mock_sui = coin::mint_for_testing<SUI>(MOCK_MINT_AMOUNT, ctx(test));

        add_balance<USDC>(test, mock_usdc  , USER_ADDR_1);
        add_balance<SUI>(test, mock_sui , USER_ADDR_1);

        // test withdraw 

        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<GlobalMarketplace>(test);

            marketplace::withdraw<USDC>(&mut global, MOCK_MINT_AMOUNT/2 , ctx(test));
            marketplace::withdraw<USDC>(&mut global, MOCK_MINT_AMOUNT/2 , ctx(test));

            test::return_shared(global);
        };

    }

    fun test_modify_orders_(test: &mut Scenario) {
        // setup quote currencies
        setup_quote(test, ADMIN_ADDR);

        let mock_pt = coin::mint_for_testing<PT>(MOCK_MINT_AMOUNT, ctx(test));

        add_balance<PT>(test, mock_pt  , USER_ADDR_1);

        // listing PT for USDC
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<GlobalMarketplace>(test); 
            marketplace::sell_and_listing<PT, USDC>(&mut global, 100 * MIST_PER_SUI, 900_000_000 , ctx(test));
            test::return_shared(global);
        };

        // updating & deleting order
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<GlobalMarketplace>(test); 
            marketplace::update_order<PT, USDC>(&mut global, 1, 950_000_000 , ctx(test));
            marketplace::cancel_order<PT, USDC>(&mut global, 1, ctx(test));
            test::return_shared(global);
        };

    }

    fun test_sell_and_buy_(test: &mut Scenario) {

        // setup quote currencies
        setup_quote(test, ADMIN_ADDR);

        let mock_pt = coin::mint_for_testing<PT>(MOCK_MINT_AMOUNT, ctx(test));
        let mock_usdc = coin::mint_for_testing<USDC>(MOCK_MINT_AMOUNT, ctx(test));

        add_balance<PT>(test, mock_pt  , USER_ADDR_1);
        add_balance<USDC>(test, mock_usdc, USER_ADDR_2);

        // listing PT for USDC
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<GlobalMarketplace>(test); 

            marketplace::sell_and_listing<PT, USDC>(&mut global, 100 * MIST_PER_SUI, 900_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, 100 * MIST_PER_SUI, 400_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, 100 * MIST_PER_SUI, 800_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, 100 * MIST_PER_SUI, 600_000_000 , ctx(test));
            marketplace::sell_and_listing<PT, USDC>(&mut global, 100 * MIST_PER_SUI, 700_000_000 , ctx(test));

            test::return_shared(global);
        };

        // buying PT with USDC
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<GlobalMarketplace>(test); 

            marketplace::buy_only<USDC, PT>(&mut global, 150 * MIST_PER_SUI, 800_000_000 , ctx(test));

            let pt_amount = marketplace::token_available<PT>( &mut global, USER_ADDR_2 );
            assert!(pt_amount == 271428571428, 1);

            let usdc_amount = marketplace::token_available<USDC>(&mut global, USER_ADDR_1 );
            assert!(usdc_amount == 150000000000, 2); 

            test::return_shared(global);
        };

    }

    fun test_buy_and_sell_(test: &mut Scenario) {
        
        // setup quote currencies
        setup_quote(test, ADMIN_ADDR);

        let mock_pt = coin::mint_for_testing<PT>(MOCK_MINT_AMOUNT, ctx(test));
        let mock_pt_2 = coin::mint_for_testing<PT>(MOCK_MINT_AMOUNT, ctx(test));
        let mock_usdc = coin::mint_for_testing<USDC>(MOCK_MINT_AMOUNT, ctx(test));

        add_balance<PT>(test, mock_pt, USER_ADDR_1);
        add_balance<USDC>(test, mock_usdc, USER_ADDR_2);
        add_balance<PT>(test, mock_pt_2, USER_ADDR_3);

        // listing PT for USDC
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<GlobalMarketplace>(test); 

            marketplace::sell_and_listing<PT, USDC>(&mut global, 10 * MIST_PER_SUI, 900_000_000 , ctx(test));

            test::return_shared(global);
        };

        // buying PT for 10 USDC and listing the remaining
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<GlobalMarketplace>(test); 

            marketplace::buy_and_listing<USDC, PT>(&mut global, 100 * MIST_PER_SUI, 950_000_000 , ctx(test));

            test::return_shared(global);
        };

        // selling PT for USDC
        next_tx(test, USER_ADDR_3);
        {
            let global = test::take_shared<GlobalMarketplace>(test); 

            marketplace::sell_only<PT, USDC>(&mut global, 20 * MIST_PER_SUI, 940_000_000 , ctx(test));

            let usdc_amount = marketplace::token_available<USDC>(&mut global, USER_ADDR_3 );
            assert!(usdc_amount == 19_000_000_000, 3); 

            test::return_shared(global);
        };

    }

    fun setup_quote(test: &mut Scenario, admin_address: address) {
        
        next_tx(test, admin_address);
        {
            marketplace::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let global = test::take_shared<GlobalMarketplace>(test);

            marketplace::setup_quote<SUI>(&mut global, ctx(test));
            marketplace::setup_quote<USDC>(&mut global, ctx(test));

            test::return_shared(global);
        };

    }

    fun add_balance<T>(test: &mut Scenario, input_coin : Coin<T> , user_address: address) {

        next_tx(test, user_address);
        {
            let global = test::take_shared<GlobalMarketplace>(test);

            marketplace::deposit<T>(&mut global, input_coin , ctx(test));

            test::return_shared(global);
        };

    }

    fun scenario(): Scenario { test::begin(@0x1) }

}