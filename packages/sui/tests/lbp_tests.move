

#[test_only]
module legato::lbp_tests {

    use std::vector;

    use sui::coin::{ Self, mint_for_testing as mint, burn_for_testing as burn}; 
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, end};
    
    use legato::fixed_point64::{Self};
    use legato::lbp::{Self, LBPGlobal, LBPManagerCap};

    // Setting up a LBP pool to distribute 25 mil. LEGATO tokens at different weights. 
    // Weight is shifted by 10% every 5 mil. tokens sold until it reaches a 50/50 ratio:
    // 1. 90% LEGATO, 10% USDC 
    // 2. 80% LEGATO, 20% USDC 
    // 3. 70% LEGATO, 30% USDC 
    // 4. 60% LEGATO, 40% USDC 
    // 5. 50% LEGATO, 50% USDC 

    // The initial price is set to 1 LEGATO = 0.002 USDC.
    const LEGATO_AMOUNT: u64 = 25000000_00000000; // 25 mil. LEGATO at 90%
    // const LEGATO_AMOUNT: u64 = 1_000_000_000;
    // Therefore, at 100%, it would be 27.77 mil., with 10% in USDC being 2.7 million * 0.002
    const USDC_AMOUNT: u64 = 555_000_000; // requires only 555 USDC

    struct USDC {}

    struct LEGATO {}

    #[test]
    fun test_register_pools() {
        let scenario = scenario();
        register_pools(&mut scenario);
        end(scenario);
    }

    // Registering 2 LBP pools:
    // 1. Pool that accepts the common coin USDC.
    // 2. Pool that accepts staking rewards
    fun register_pools(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
        {
            lbp::test_init(ctx(test));
        };

        setup_common_pool(test);
    
    }

    fun setup_common_pool(test: &mut Scenario) {

        let (owner, _) = people();

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            lbp::register_lbp_pool<LEGATO>( &mut global, ctx(test) );
            test_scenario::return_shared(global);
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::setup_weight_data<LEGATO>( 
                &mut global, 
                9000,
                1000,
                8000,
                2000,
                7000,
                3000,
                6000,
                4000,
                5000,
                5000,
                1,
                5000000_00000000,
                ctx(test) 
            );

            lbp::setup_reserve_with_common_coin<LEGATO, USDC>( &mut global, ctx(test) );
            
            test_scenario::return_shared(global);
        };

        next_tx(test, owner);
        {
            let global = test_scenario::take_shared<LBPGlobal>(test);
            
            lbp::add_liquidity<LEGATO, USDC>( 
                &mut global, 
                mint<LEGATO>(LEGATO_AMOUNT, ctx(test)),  
                1,
                mint<USDC>(USDC_AMOUNT, ctx(test)),   
                1,
                ctx(test) 
            );

            test_scenario::return_shared(global);
        };

    }

    fun fixed_point_value( numerator: u128, denominator: u128) : u128 {
        let value = fixed_point64::create_from_rational( numerator, denominator );
        fixed_point64::get_raw_value(value)
    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }

}