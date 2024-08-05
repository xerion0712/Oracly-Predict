

#[test_only]
module legato_options::call_options_tests {

    use sui::coin::{ Self, Coin, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, next_epoch, ctx, end};
    use sui::sui::SUI;

    use legato_options::options_manager::{Self, ManagerCap, OptionsGlobal, Option, WRITE_SUI }; 
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

            // Supply 10,000 SUI
            options_manager::provide_sui(&mut global, mint<SUI>(10000_000000000, ctx(test)) , ctx(test) );
            // Supply 10,000 USDY
            options_manager::provide_stable(&mut global, mint<MOCK_USDY>(10000_000000000, ctx(test)) , ctx(test));
            test_scenario::return_shared(global);
        };
    }

    // Create a call option and exercise.
    #[test_only]
    fun exercise_atm(test: &mut Scenario) {
        let (lp_provider, user) = users();

        setup_pools(test);

        // Create a call option with a strike price of 0.8 SUI/USD
        // pay a premium and set the expiry to 1 epoch
        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut sui_coin = mint<SUI>(800000000, ctx(test));

            options_manager::create_call_option(
                &mut global,
                1,
                1000000000, // 1 SUI
                800000000, // 0.8 SUI/USD
                &mut sui_coin,
                ctx(test)
            );

            assert!( 783885001 == coin::value((&sui_coin)), 0 ); // premium is ~0.011115000 SUI
            burn(sui_coin);

            test_scenario::return_shared(global);
        };

        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 

            options_manager::exercise_call_option(
                &mut global,
                0,
                ctx(test)
            );

            test_scenario::return_shared(global);
        };

    }

    // Create a call option and exercise when the price rises to 1 SUI/USD
    #[test_only]
    fun exercise_otm(test: &mut Scenario) {
        let (lp_provider, user) = users();

        setup_pools(test);

        // Create a call option with a strike price of 0.8 SUI/USD
        // pay a premium and set the expiry to 1 epoch
        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut sui_coin = mint<SUI>(800000000, ctx(test));

            options_manager::create_call_option(
                &mut global,
                1,
                1000000000, // 1 SUI
                800000000, // 0.8 SUI/USD
                &mut sui_coin,
                ctx(test)
            );

            assert!( 783885001 == coin::value((&sui_coin)), 0 ); // premium is ~0.011115000 SUI
            burn(sui_coin);

            test_scenario::return_shared(global);
        };

        next_tx(test, lp_provider);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test);
            let mut managercap = test_scenario::take_from_sender<ManagerCap>(test);

            // 1 SUI/USD
            options_manager::update_price_feed<SUI>(&mut global, &mut managercap, 10000 , 4  , ctx(test)  );

            test_scenario::return_shared(global);
            test_scenario::return_to_sender(test, managercap);
        };

        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 

            options_manager::exercise_call_option(
                &mut global,
                0,
                ctx(test)
            );

            test_scenario::return_shared(global);
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

        // Both lp_provider, user provide 100 SUI & open a call option over 10 SUI
        next_tx(test, lp_provider);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 
            options_manager::provide_sui(&mut global, mint<SUI>(100_000000000, ctx(test)) , ctx(test) );

            let mut sui_coin = mint<SUI>(800000000, ctx(test));
            options_manager::create_call_option(
                &mut global,
                1,
                10_000000000, // 10 SUI
                800000000, // 0.8 SUI/USD
                &mut sui_coin,
                ctx(test)
            );
            burn(sui_coin);
            test_scenario::return_shared(global);
        };

        next_tx(test, user);
        {
            let mut global = test_scenario::take_shared<OptionsGlobal>(test); 
            options_manager::provide_sui(&mut global, mint<SUI>(100_000000000, ctx(test)) , ctx(test) );

            let mut sui_coin = mint<SUI>(800000000, ctx(test));
            options_manager::create_call_option(
                &mut global,
                1,
                10_000000000, // 10 SUI
                800000000, // 0.8 SUI/USD
                &mut sui_coin,
                ctx(test)
            );
            burn(sui_coin);
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
            let lp_token = test_scenario::take_from_sender<Coin<WRITE_SUI>>(test);
            options_manager::withdraw_sui( &mut global, lp_token, ctx(test) );
            test_scenario::return_shared(global);
        };

        // Check the balance
        next_tx(test, user);
        {
            let sui_token = test_scenario::take_from_sender<Coin<SUI>>(test);   
            assert!( coin::value(&(sui_token)) == 100_055544131, 0 ); // Depositing 100 SUI that can be withdrawn for 100.055544131 SUI
            test_scenario::return_to_sender(test, sui_token);
        };
 
    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun users(): (address, address) { (@0xBEEF, @0x1337) }
}
 