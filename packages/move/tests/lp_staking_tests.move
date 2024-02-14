

#[test_only]
module legato::lp_staking_tests {

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx, next_epoch};
    use sui::coin::{Self};

    use legato::lp_staking::{Self, Staking};
    use legato::vault::{Self, ManagerCap};
    use legato::vault_utils::{
        scenario
    };

    const ADMIN_ADDR: address = @0x21;

    const USER_ADDR_1: address = @0x42;
    const USER_ADDR_2: address = @0x43;
    const USER_ADDR_3: address = @0x44;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    struct JAN_2024 {} // principal assets

    struct YT_TOKEN<phantom P> has drop {}

    struct REWARD {} // reward assets

    #[test]
    public fun test_lp_staking() {
        let scenario = scenario();
        test_lp_staking_(&mut scenario);
        test::end(scenario);
    }

    fun test_lp_staking_(test: &mut Scenario) {
        // setup contract
        setup(test, ADMIN_ADDR);

        // staking 100 YT for #1
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<Staking>(test); 
            lp_staking::stake<YT_TOKEN<JAN_2024>>(&mut global, coin::mint_for_testing<YT_TOKEN<JAN_2024>>( 100_000_000_000, ctx(test)), ctx(test));
            test::return_shared(global);  
        };

        // staking 200 YT for #2
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<Staking>(test); 
            lp_staking::stake<YT_TOKEN<JAN_2024>>(&mut global, coin::mint_for_testing<YT_TOKEN<JAN_2024>>( 200_000_000_000, ctx(test)), ctx(test));
            test::return_shared(global); 
        };

        // take a snapshot then they can claim after
        snapshot(test, ADMIN_ADDR, 10);
        
        // unstaking and withdrawing for #1
        next_tx(test, USER_ADDR_1);
        {
            let global = test::take_shared<Staking>(test); 
            lp_staking::unstake<YT_TOKEN<JAN_2024>>(&mut global, 100_000_000_000, ctx(test));
            lp_staking::withdraw_rewards<YT_TOKEN<JAN_2024>, REWARD>(&mut global, ctx(test));
            test::return_shared(global);  
        };

        // unstaking and withdrawing for #2
        next_tx(test, USER_ADDR_2);
        {
            let global = test::take_shared<Staking>(test); 
            lp_staking::unstake<YT_TOKEN<JAN_2024>>(&mut global, 200_000_000_000, ctx(test));
            lp_staking::withdraw_rewards<YT_TOKEN<JAN_2024>, REWARD>(&mut global, ctx(test));
            test::return_shared(global);  
        };

    }
    
    fun setup(test: &mut Scenario, admin_address: address) {

        next_tx(test, admin_address);
        {
            vault::test_init(ctx(test));
            lp_staking::test_init(ctx(test));
        };

        next_tx(test, admin_address);
        {
            let global = test::take_shared<Staking>(test);
            let managercap = test::take_from_sender<ManagerCap>(test);
            lp_staking::set_reward<YT_TOKEN<JAN_2024>, REWARD>(&mut global, &mut managercap);
            test::return_shared(global);
            test::return_to_sender(test, managercap);
        };

        // deposit reward tokens and set distribution per epoch
        next_tx(test, admin_address);
        {
            let global = test::take_shared<Staking>(test);
            let managercap = test::take_from_sender<ManagerCap>(test);

            // deposit 10,000 REWARD for further claim
            lp_staking::deposit_rewards<YT_TOKEN<JAN_2024>, REWARD>(&mut global, coin::mint_for_testing<REWARD>( 10_000_000_000_000, ctx(test)), ctx(test));
            // set reward distributes from epoch
            lp_staking::set_reward_table<YT_TOKEN<JAN_2024>>(&mut global, &mut managercap, 3, 1_000_000_000, ctx(test));
            
            test::return_shared(global); 
            test::return_to_sender(test, managercap);
        };
    }

    fun snapshot(test: &mut Scenario, admin_address: address, value:u64) {

        let i = 0;
        while (i < value) {
            snapshot_each(test, admin_address);
            i = i + 1;
        };
 
    }

    fun snapshot_each(test: &mut Scenario, admin_address: address) {
        next_tx(test, admin_address);
        {
            let global = test::take_shared<Staking>(test);
            lp_staking::snapshot<YT_TOKEN<JAN_2024>>(&mut global, ctx(test));
            test::return_shared(global); 
        };

        next_epoch(test, admin_address);
    }
 

}