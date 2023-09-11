#[test_only]
module legato::oracle_tests {

    use legato::oracle::{Self, ManagerCap, Feed};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use std::ascii::Self; 
    // use sui::object;

    const HELLO: vector<u8> = vector[72, 101, 108, 108, 111]; // "Hello" in ASCII.

    #[test]
    public fun test_feed() {
        let scenario = scenario();
        test_feed_(&mut scenario);
        test::end(scenario);
    }

    #[test_only]
    fun test_feed_(test: &mut Scenario) {
        let (admin, _, _) = users();

        next_tx(test, admin);
        {
            oracle::test_init(ctx(test));
        };

        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            
            oracle::new_feed(&mut managercap, ascii::string(HELLO), 2, ctx(test));

            test::return_to_sender(test, managercap);
        };

        next_tx(test, admin);
        {
            let managercap = test::take_from_sender<ManagerCap>(test);
            
            // getting feed object
            let feed = test::take_shared<Feed>(test);

            oracle::update(&mut feed, &mut managercap, 999, ctx(test));
            
            let (val, dec ) = oracle::get_value(&mut feed);

            assert!(val == 999, 1); // value
            assert!(dec == 2, 2); // decimals

            test::return_shared(feed);
            test::return_to_sender(test, managercap);
        };

    }

    fun scenario(): Scenario { test::begin(@0x1) }

    fun users(): (address, address, address) { (@0xBEEF, @0x1337, @0x00B) }
}   