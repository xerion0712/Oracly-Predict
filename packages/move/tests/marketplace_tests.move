

#[test_only]
module legato::marketplace_tests {

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};

    use legato::marketplace::{Self, GlobalMarketplace };

    const ADMIN_ADDR: address = @0x21;

    const USER_ADDR_1: address = @0x42;
    const USER_ADDR_2: address = @0x43;

    const MOCK_MINT_AMOUNT: u64 = 100_000_000_000;

    struct USDC {}

    #[test]
    public fun test_add_balances() {
        let scenario = scenario();
        test_add_balances_(&mut scenario);
        test::end(scenario);
    }

    fun test_add_balances_(test: &mut Scenario) {

        // setup base markets
        setup_market(test, ADMIN_ADDR);
        
        let mock_usdc = coin::mint_for_testing<USDC>(MOCK_MINT_AMOUNT, ctx(test));
        let mock_sui = coin::mint_for_testing<SUI>(MOCK_MINT_AMOUNT, ctx(test));

        add_balance(test, mock_usdc  , USER_ADDR_1);
        add_balance(test, mock_sui , USER_ADDR_1);

        // test withdraw 

        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<GlobalMarketplace>(test);

            marketplace::withdraw<USDC>(&mut global, MOCK_MINT_AMOUNT/2 , ctx(test));
            marketplace::withdraw<USDC>(&mut global, MOCK_MINT_AMOUNT/2 , ctx(test));

            test::return_shared(global);
        };

    }

    fun setup_market(test: &mut Scenario, admin_address: address) {
        
        next_tx(test, admin_address);
        {
            marketplace::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let global = test::take_shared<GlobalMarketplace>(test);

            marketplace::setup_market<SUI>(&mut global, ctx(test));
            marketplace::setup_market<USDC>(&mut global, ctx(test));

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