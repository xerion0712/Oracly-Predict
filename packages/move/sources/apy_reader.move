
// A module to fetch APY on-chain using the same formula stated in the RPC node

module legato::apy_reader {

    // use std::debug;

    use sui_system::sui_system::{SuiSystemState, pool_exchange_rates};
    use sui_system::staking_pool::{ Self, PoolTokenExchangeRate};

    use sui::object::{ID};
    use sui::table::{Self,  Table};
    
    // const STAKE_SUBSIDY_START_EPOCH : u64 = 20;
    const EPOCH_TO_WEIGHT : u64 = 30;
    const MIST_PER_SUI: u64 = 1_000_000_000;

    const EInvalidRefEpoch: u64 = 1;
    const EInvalidEpoch: u64 = 2;

    // fetch APY from the given pool
    public fun pool_apy(wrapper: &mut SuiSystemState, pool_id: &ID, epoch: u64) : u64 {
        let table_rates = pool_exchange_rates(wrapper, pool_id);
        assert!(table::contains(table_rates, epoch), EInvalidEpoch);

        let sum = 0;
        let i = 0;
        let total_sum = 0;
        while (i < EPOCH_TO_WEIGHT) {

            if (table::contains(table_rates, epoch-i)) {
                // find the closest previous epoch
                let count = 1;
                while (count < 10) {
                    if (table::contains(table_rates, epoch-i-count)) break;
                    count = count + 1
                };
                if (table::contains(table_rates, epoch-i-count)) {
                    sum = sum+calculate_apy(table_rates, epoch-i, epoch-i-count);
                    total_sum = total_sum+1;
                };
            };

            i = i + 1
        };
        sum / total_sum
    }

    // APY_e = (ER_e+1 / ER_e) ^ 365
    fun calculate_apy(table_rates: &Table<u64, PoolTokenExchangeRate>, epoch: u64, ref_epoch: u64,) : u64 {
        assert!(epoch > ref_epoch, EInvalidRefEpoch);

        let current_rate = table::borrow(table_rates, epoch);
        let ref_rate = table::borrow(table_rates, ref_epoch);

        let numerator = (staking_pool::sui_amount(current_rate) as u128) * (staking_pool::pool_token_amount(ref_rate) as u128) / (MIST_PER_SUI as u128);
        let denominator = (staking_pool::sui_amount(ref_rate) as u128) * (staking_pool::pool_token_amount(current_rate) as u128) / (MIST_PER_SUI as u128);

        (((numerator * (MIST_PER_SUI as u128)  / denominator) - (MIST_PER_SUI as u128)) as u64) * (365/(epoch-ref_epoch))
    }

}