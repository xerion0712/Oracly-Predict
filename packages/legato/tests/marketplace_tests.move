
#[test_only]
module legato::marketplace_tests {

    use sui::coin::{Self};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use legato::marketplace::{Self, Marketplace};
    use legato::vault::{VAULT};
    use sui::object;

    #[test]
    public fun test_list_and_buy() {
        let scenario = scenario();
        test_list_and_buy_(&mut scenario);
        test::end(scenario);
    }

    #[test_only]
    fun test_list_and_buy_(test: &mut Scenario) {
        let (admin, _, buyer) = users();

        let vault_token = coin::mint_for_testing<VAULT>(1, ctx(test));
        let vault_token_id = object::id(&vault_token);

        next_tx(test, admin);
        {
            marketplace::init_for_testing(ctx(test));
        };

        next_tx(test, admin);
        {
            // list
            let mkp_val = test::take_shared<Marketplace>(test);
            let mkp = &mut mkp_val;

            marketplace::list(mkp, vault_token, 1000, ctx(test));

            test::return_shared(mkp_val)
        };
        next_tx(test, buyer);
        {
            // buy
            let mkp_val = test::take_shared<Marketplace>(test);
            let mkp = &mut mkp_val;

            let sui_token = coin::mint_for_testing<SUI>(1000, ctx(test));

            marketplace::buy_and_take(mkp, vault_token_id, sui_token, ctx(test));

            test::return_shared(mkp_val)
        };

    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address, address) { (@0xBEEF, @0x1337, @0x00B) }
}