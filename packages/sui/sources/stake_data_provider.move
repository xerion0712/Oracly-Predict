
// The module retrieves on-chain information from the network's global state
// Including the APY rate, using the same formula as stated in the RPC node

module legato::stake_data_provider {

    use std::vector;

    use sui_system::sui_system::{ Self, SuiSystemState, pool_exchange_rates};
    use sui_system::staking_pool::{ Self, PoolTokenExchangeRate, StakedSui}; 

    use sui::object::{ID};
    use sui::table::{Self,  Table};
    use sui::random::{Self, Random};
    use sui::tx_context::{ TxContext};
    
    const EPOCH_TO_WEIGHT : u64 = 30;
    const MIST_PER_SUI: u64 = 1_000_000_000;

    const EInvalidRefEpoch: u64 = 1;
    const EInvalidEpoch: u64 = 2;


    // Retrieve a random active validator address
    #[allow(lint(public_random))]
    public fun random_active_validator(wrapper: &mut SuiSystemState, r: &Random, whitelist: vector<address>, ctx: &mut TxContext) : address {

        // Generate a random number
        let generator = random::new_generator(r, ctx);
        let random_num = random::generate_u64(&mut generator);

        // Check if the whitelist is empty, if so, we load all validators
        if (vector::length(&whitelist) == 0) { 
            let active_list = sui_system::active_validator_addresses(wrapper);
            // Return a random validator address from all in the system
            *vector::borrow( &active_list, random_num % vector::length(&active_list) )
        } else {
             // Return a random validator address from the whitelist
            *vector::borrow( &whitelist, random_num % vector::length(&whitelist) )
        }

    }

    // Fetch APY from the provided pool ID
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

    // Calculate APY using the formula: APY_e = (ER_e / ER_e-diff)^(365/diff) - 1
    fun calculate_apy(table_rates: &Table<u64, PoolTokenExchangeRate>, epoch: u64, ref_epoch: u64,) : u64 {
        assert!(epoch > ref_epoch, EInvalidRefEpoch);

        let current_rate = table::borrow(table_rates, epoch);
        let ref_rate = table::borrow(table_rates, ref_epoch);

        let numerator = (staking_pool::sui_amount(current_rate) as u256) * (staking_pool::pool_token_amount(ref_rate) as u256) / (MIST_PER_SUI as u256);
        let denominator = (staking_pool::sui_amount(ref_rate) as u256) * (staking_pool::pool_token_amount(current_rate) as u256) / (MIST_PER_SUI as u256);

        (((numerator * (MIST_PER_SUI as u256)  / denominator) - (MIST_PER_SUI as u256)) as u64) * (365/(epoch-ref_epoch))
    }
 
    // Re-implement earnings calculation from staking_pool module
    public fun earnings_from_staked_sui(wrapper: &mut SuiSystemState, staked_sui: &StakedSui, to_epoch: u64): u64  {

        let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);
        let principal_amount = staking_pool::staked_sui_amount(staked_sui);
        let pool_id = staking_pool::pool_id(staked_sui);

        assert!(to_epoch > activation_epoch, EInvalidEpoch);
        
        let table_rates = pool_exchange_rates(wrapper, &pool_id);

        let at_staking_rate = table::borrow(table_rates, activation_epoch);        
        let pool_token_withdraw_amount = get_token_amount(at_staking_rate, principal_amount);

        let epoch = to_epoch;
        let target_epoch = activation_epoch;

        while(epoch >= activation_epoch) {
            if (table::contains(table_rates, epoch)) {
                target_epoch = epoch;
                activation_epoch = epoch+1; // break loop
            };
            epoch = epoch - 1;
        };

        let current_rate = table::borrow(table_rates, target_epoch);
        let total_sui_withdraw_amount = get_sui_amount(current_rate, pool_token_withdraw_amount);

        let reward_withdraw_amount =
            if (total_sui_withdraw_amount >= principal_amount)
                total_sui_withdraw_amount - principal_amount
            else 0;

        reward_withdraw_amount
    }


    // TODO: Overall APY = Σ (Probability * APY)



    // ======== Helper Functions =========

    fun get_token_amount(exchange_rate: &PoolTokenExchangeRate, sui_amount: u64): u64 {

        let rate_sui_amount = staking_pool::sui_amount(exchange_rate);
        let rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);

        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (rate_sui_amount == 0 || rate_pool_token_amount == 0) {
            return sui_amount
        };
        let res = (rate_pool_token_amount as u128)
                * (sui_amount as u128)
                / (rate_sui_amount as u128);
        (res as u64)
    }

    fun get_sui_amount(exchange_rate: &PoolTokenExchangeRate, token_amount: u64): u64 {

        let rate_sui_amount = staking_pool::sui_amount(exchange_rate);
        let rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);

        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (rate_sui_amount == 0 || rate_pool_token_amount == 0) {
            return token_amount
        };
        let res = (rate_sui_amount as u128)
                * (token_amount as u128)
                / (rate_pool_token_amount as u128);
        (res as u64)
    }



}