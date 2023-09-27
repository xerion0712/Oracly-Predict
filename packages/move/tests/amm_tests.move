#[test_only]
module legato::amm_tests {

    use sui::coin::{Self};  
    use sui::sui::SUI;
    use legato::vault::{Self, Reserve, ManagerCap, TOKEN, YT  };
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

    const INITIAL_LIQUIDITY: u64 = 100000000000; // 100 SUI
     // 100 SUI / 1 Mil. YT -> 1 YT = 0.0001 SUI
    const ONE : u64 = 1000000000;

    #[test]
    public fun test_swap() {
        let scenario = scenario();
        test_swap_(&mut scenario);
        test::end(scenario);
    }

    fun test_swap_(test: &mut Scenario) {
        
        let (provider, buyer, seller) = users();

        next_tx(test, provider);
        {
            vault::test_init(ctx(test));
        };

        // Setup Vault that locks Staked SUI for 10 Epoch
        next_tx(test, provider);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            let sui_token = coin::mint_for_testing<SUI>(INITIAL_LIQUIDITY, ctx(test));
            vault::new_vault(&mut managercap,  10, sui_token, ctx(test));
            test::return_to_sender(test, managercap);
        };

        // Buying YT
        next_tx(test, buyer);
        {       
            let reserve = test::take_shared<Reserve>(test);
            let sui_token = coin::mint_for_testing<SUI>(ONE, ctx(test));

            // check token price that 1 SUI -> 9,900 YT from (1 SUI x 1 Mil. YT / 100 SUI + 1 SUI)
            assert!(vault::token_price(&reserve, ONE) > (9900 * ONE), 1);

            vault::swap_sui(&mut reserve, ONE, &mut sui_token, ctx(test));

             coin::burn_for_testing(sui_token);
            test::return_shared(reserve);
        };

        // Selling YT
        next_tx(test, seller);
        {       
            let reserve = test::take_shared<Reserve>(test);
            let yt_token = coin::mint_for_testing<TOKEN<YT>>(10000*ONE, ctx(test));

            vault::swap_token(&mut reserve, 10000*ONE, &mut yt_token, ctx(test));

            coin::burn_for_testing(yt_token);
            test::return_shared(reserve);
        };

    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address, address) { (@0xBEEF, @0x1337, @0x2222) }

}