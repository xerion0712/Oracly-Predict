
#[test_only]
module legato_options::put_options_tests {

    use sui::coin::{ Self, Coin, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, next_epoch, ctx, end};
    use sui::sui::SUI;

    use legato_options::options_manager::{Self, ManagerCap, OptionsGlobal, Option, WRITE_STABLE }; 
    use legato_options::mock_usdy::{MOCK_USDY};

    #[test]
    fun test_setup_pools() {
        let mut scenario = scenario();
        setup_pools(&mut scenario);
        end(scenario);
    }

    #[test]
    fun test_exercise_atm() {
        let mut scenario = scenario();
        exercise_atm(&mut scenario);
        scenario.end();
    }

    #[test]
    fun test_exercise_otm() {
        let mut scenario = scenario();
        exercise_otm(&mut scenario);
        scenario.end();
    }

    #[test]
    fun test_lp_earn_premium() {
        let mut scenario = scenario();
        lp_earn_premium(&mut scenario);
        scenario.end();
    }

    // Setting up all LP pools that act as counterparties for long traders
    #[test_only]
    fun setup_pools(test: &mut Scenario) {
        let (lp_provider, _) = users();

        next_tx(test, lp_provider);
        {
            options_manager::test_init(ctx(test)); 
        };

        // Creates price feeds
        next_tx(test, lp_provider);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut managercap = test_scenario::take_from_sender<ManagerCap>(test);
            // 0.8 SUI/USD
            options_manager::update_price_feed<SUI>(&mut global, &mut managercap, 8000, 4, ctx(test));
            test_scenario::return_shared(global);
            test_scenario::return_to_sender(test, managercap);
        };

        // Provides liquidity
        next_tx(test, lp_provider);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            // Supply 10,000 USDY
            options_manager::provide_stable(&mut global, mint<MOCK_USDY>(10000_000000000, ctx(test)) , ctx(test));
            test_scenario::return_shared(global);
        };
    }

    // Create a put option and exercise.
    #[test_only]
    fun exercise_atm(test: &mut Scenario) {
        let (lp_provider, user) = users();

        setup_pools(test);

        // Create a put option with a strike price of 0.8 SUI/USD
        // pay a premium and set the expiry to 1 epoch
        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut usdy_coin = mint<MOCK_USDY>(1000000000, ctx(test));

            options_manager::create_put_option(
                &mut global,
                1,
                1000000000, // 1 SUI
                800000000, // 0.8 SUI/USD
                &mut usdy_coin,
                ctx(test)
            );

            assert!( 983885001 == coin::value((&usdy_coin)), 0 ); // premium is ~0.016114999 USDY
            burn(usdy_coin);

            test_scenario::return_shared(global);
        };

        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 

            options_manager::exercise_put_option(
                &mut global,
                0,
                ctx(test)
            );

            test_scenario::return_shared(global);
        };
    
    }

    // Create a put option and exercise it when the price drops to 0.6 SUI/USD
    #[test_only]
    fun exercise_otm(test: &mut Scenario) {
        let (lp_provider, user) = users();

        setup_pools(test);

        // Create a put option with a strike price of 0.8 SUI/USD
        // pay a premium and set the expiry to 1 epoch
        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut usdy_coin = mint<MOCK_USDY>(1000000000, ctx(test));

            options_manager::create_put_option(
                &mut global,
                1,  // Expiry in 1 epoch
                1000000000, // Option amount of 1 SUI
                800000000, // Strike price of 0.8 SUI/USD
                &mut usdy_coin, // Premium payment in USDY
                ctx(test)
            );
 
            assert!( 983885001 == coin::value((&usdy_coin)), 0 ); // premium is ~0.016114999 USDY
            burn(usdy_coin);

            test_scenario::return_shared(global);
        };

        // Update the price feed to 0.6 SUI/USD
        next_tx(test, lp_provider);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut managercap = test_scenario::take_from_sender<ManagerCap>(test); 
            options_manager::update_price_feed<SUI>(&mut global, &mut managercap, 6000 , 4  , ctx(test)  );
            test_scenario::return_shared(global);
            test_scenario::return_to_sender(test, managercap);
        };

        // Exercise the put option
        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 

            options_manager::exercise_put_option(
                &mut global,
                0,  // Index of the option to exercise
                ctx(test)
            );

            test_scenario::return_shared(global);
        };

        // Check the balance after exercising the option
        next_tx(test, user);
        {
            let usdy_token = test_scenario::take_from_sender<Coin<MOCK_USDY>>(test); 
            assert!( coin::value(&(usdy_token)) == 199999999, 0 ); // Profit of ~0.2 USDY
            test_scenario::return_to_sender(test, usdy_token);
        };

    }

    // LP provides liquidity and earns premium on withdrawal
    #[test_only]
    fun lp_earn_premium(test: &mut Scenario) {
        let (lp_provider, user) = users();

        next_tx(test, lp_provider);
        {
            options_manager::test_init(ctx(test)); 
        };

        next_tx(test, lp_provider);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut managercap = test_scenario::take_from_sender<ManagerCap>(test);

            // 0.8 SUI/USD
            options_manager::update_price_feed<SUI>(&mut global, &mut managercap, 8000, 4  , ctx(test)  );

            test_scenario::return_shared(global);
            test_scenario::return_to_sender(test, managercap);
        };

        // Both lp_provider, user provide 100 USDY & open a put option over 10 SUI
        next_tx(test, lp_provider);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 
            options_manager::provide_stable(&mut global, mint<MOCK_USDY>(100_000000000, ctx(test)) , ctx(test) );

            let mut stablecoin_coin = mint<MOCK_USDY>(1000000000, ctx(test));
            options_manager::create_put_option(
                &mut global,
                1,
                10_000000000, // 10 SUI
                800000000, // 0.8 SUI/USD
                &mut stablecoin_coin,
                ctx(test)
            );
            burn(stablecoin_coin);
            test_scenario::return_shared(global);
        };

        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 
            options_manager::provide_stable(&mut global, mint<MOCK_USDY>(100_000000000, ctx(test)) , ctx(test) );

            let mut stablecoin_coin = mint<MOCK_USDY>(1000000000, ctx(test));
            options_manager::create_put_option(
                &mut global,
                1,
                10_000000000, // 10 SUI
                800000000, // 0.8 SUI/USD
                &mut stablecoin_coin,
                ctx(test)
            );
            burn(stablecoin_coin);
            test_scenario::return_shared(global);
        };

        // Fast-forward 3 epoch
        next_epoch(test, lp_provider);
        next_epoch(test, lp_provider);
        next_epoch(test, lp_provider);

        // User withdraws all LP shares and should receive premiums
        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 
            let lp_token = test_scenario::take_from_sender<Coin<WRITE_STABLE>>(test);
            options_manager::withdraw_stable( &mut global, lp_token, ctx(test) );
            test_scenario::return_shared(global);
        };

        // Check the balance
        next_tx(test, user);
        {
            let stable_token = test_scenario::take_from_sender<Coin<MOCK_USDY>>(test); 
            assert!( coin::value(&(stable_token)) == 100_055544131, 0 ); // Depositing 100 USDY that can be withdrawn for 100.055544131 USDY
            test_scenario::return_to_sender(test, stable_token);
        };
    
    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun users(): (address, address) { (@0xBEEF, @0x1337) }
}