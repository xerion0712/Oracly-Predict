#[test_only]
module legato::marketplace_tests {
 
    use sui::coin::{Self};  
    use sui::sui::SUI; 
    use legato::vault::{Self, Reserve, ManagerCap, TOKEN, PT  };
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

    const MINT_AMOUNT: u64 = 10000000000; // 10 PT
    const SELL_AMOUNT: u64 = 1000000000; // 1 PT
    const PRICE: u64 = 950000000; // 1 PT = 0.95 SUI

    #[test]
    public fun test_list_delist() {
        let scenario = scenario();
        test_list_delist_(&mut scenario);
        test::end(scenario);
    }

    #[test]
    public fun test_buy() {
        let scenario = scenario();
        test_buy_(&mut scenario);
        test::end(scenario);
    }

    // TODO : PARTIAL BUY

    fun test_list_delist_(test: &mut Scenario) {
        let (seller, _) = users();
        
        next_tx(test, seller);
        {
            vault::test_init(ctx(test));
        };

        // Setup Vault that locks Staked SUI for 10 Epoch
        next_tx(test, seller);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            vault::new_vault(&mut managercap,  10, coin::mint_for_testing<SUI>(MINT_AMOUNT, ctx(test)), ctx(test));
            test::return_to_sender(test, managercap);
        };

        // Listing 1 PT
        next_tx(test, seller);
        {
            let reserve = test::take_shared<Reserve>(test);
            let mock_vault_token = coin::mint_for_testing<TOKEN<PT>>(MINT_AMOUNT, ctx(test));

            vault::list(
                &mut reserve,
                &mut mock_vault_token,
                SELL_AMOUNT,
                PRICE,
                ctx(test)
            );

            coin::burn_for_testing(mock_vault_token);
            test::return_shared(reserve);
        };

        // Delisting
        next_tx(test, seller);
        {
            let reserve = test::take_shared<Reserve>(test); 

            vault::delist(
                &mut reserve,
                0,
                ctx(test)
            );

            test::return_shared(reserve);
        };

    }

    fun test_buy_(test: &mut Scenario) {
        let (seller, buyer) = users();

        next_tx(test, seller);
        {
            vault::test_init(ctx(test));
        };

        // Setup Vault that locks Staked SUI for 10 Epoch
        next_tx(test, seller);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            vault::new_vault(&mut managercap,  10, coin::mint_for_testing<SUI>(MINT_AMOUNT, ctx(test)) , ctx(test));
            test::return_to_sender(test, managercap);
        };

        // Listing 1 PT for 0.95 SUI
        next_tx(test, seller);
        {
            let reserve = test::take_shared<Reserve>(test);
            let mock_vault_token = coin::mint_for_testing<TOKEN<PT>>(MINT_AMOUNT, ctx(test));

            vault::list(
                &mut reserve,
                &mut mock_vault_token,
                SELL_AMOUNT,
                PRICE,
                ctx(test)
            );

            coin::burn_for_testing(mock_vault_token);
            test::return_shared(reserve);
        };

        // Buying 1 PT for 0.95 SUI
        next_tx(test, buyer);
        {
            let reserve = test::take_shared<Reserve>(test);
            let sui_token = coin::mint_for_testing<SUI>(MINT_AMOUNT, ctx(test));

            vault::buy(
                &mut reserve,
                0,
                SELL_AMOUNT,
                &mut sui_token,
                ctx(test)
            );

            coin::burn_for_testing(sui_token);
            test::return_shared(reserve);
        };


    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address) { (@0xBEEF, @0x1337) }
}