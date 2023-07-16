#[test_only]
module legato::staked_sui_tests {

    use legato::staked_sui::{Self, STAKED_SUI};
    use sui::coin::{TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx};

    #[test]
    fun mint() {
        let addr1 = @0xA;

        let scenario = test_scenario::begin(addr1);
        {
            staked_sui::test_init(ctx(&mut scenario))
        };
         
        next_tx(&mut scenario, addr1);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<STAKED_SUI>>(&scenario);
            staked_sui::mint(&mut treasurycap, 100, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_address<TreasuryCap<STAKED_SUI>>(addr1, treasurycap);
        };

        test_scenario::end(scenario);
    }
}