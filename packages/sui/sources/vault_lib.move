// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// All necessary functions for vault.move calculations reside here

module legato::vault_lib {

    use std::vector;
    use std::string::{  String };
    use std::option::{  Self, Option}; 
    use sui_system::staking_pool::{ Self, StakedSui};
    use sui_system::sui_system::{ Self, SuiSystemState };
    

    use legato::fixed_point64::{ Self, FixedPoint64};
    use legato::math_fixed64::{Self};
    use legato::stake_data_provider;
    
    const MAX_U64: u128 = 18446744073709551615;
    
    const ERR_INVALID_LENGTH : u64 = 401;

    // Calculate the amount of PT debt to be sent out using the formula A = P * e^(rt)
    public fun calculate_pt_debt_amount(apy: FixedPoint64, from_epoch: u64, to_epoch: u64, input_amount: u64): u64 {
        
        // Calculate time duration in years
        let time = fixed_point64::create_from_rational( ((to_epoch-from_epoch) as u128), 365 );

        // Calculate rt (rate * time)
        let rt = math_fixed64::mul_div( apy, time, fixed_point64::create_from_u128(1));
        let multiplier = math_fixed64::exp(rt);

        // the final PT debt amount
        ( fixed_point64::multiply_u128( (input_amount as u128), multiplier  ) as u64 )
    }

    // Finds an asset with a ratio close to the target ratio
    public fun matching_asset_to_ratio( ratio_list: vector<FixedPoint64>, target_ratio: FixedPoint64 ) : (Option<FixedPoint64>, Option<u64>) {

        let output_value = option::none<FixedPoint64>();
        let output_id = option::none<u64>();

        let precision = 1; // Initialize precision from 0.05 to 1

        // Iterate over different precision values
        while ( precision <= 20) {
            
            let p = fixed_point64::create_from_rational(precision, 20);  // Create fixed-point precision value

            let item_count = 0;

            // Iterate over each ratio in the ratio list
            while (item_count < vector::length(&ratio_list)) {

                let current_ratio = *vector::borrow( &ratio_list, item_count );

                // Check if the current ratio is close to the target ratio within the given precision
                if ( fixed_point64::almost_equal( current_ratio , target_ratio, p) ) {
                    // If found, update output variables and break the loop
                    output_value = option::some<FixedPoint64>( current_ratio );
                    output_id = option::some<u64>( item_count ); 
                    precision = 21; // break main loop
                    break
                };

                item_count = item_count + 1;
            };

            precision = precision+1;
        };

        (output_value, output_id)
    }
 
    // Reduces a list of pool IDs to unique pool IDs.
    public fun reduce_pool_list(pool_ids: vector<String>) : vector<String> {
        let output = vector::empty<String>();
        let count = 0;
        while (count < vector::length(&(pool_ids))) {
            let pool_id = *vector::borrow(&pool_ids, count );
            let (contained, _) = vector::index_of<String>(&output, &pool_id );
            if (contained == false) {
                vector::push_back( &mut output, pool_id );
            };  
            count = count +1;
        };
        output
    }

    // Filters asset IDs based on a specific pool ID.
    public fun filter_asset_ids(filter_id: String, pool_ids: vector<String>, asset_ids: vector<u64>) : vector<u64> {
        assert!( vector::length(&pool_ids) == vector::length(&asset_ids) , ERR_INVALID_LENGTH);
        
        let output = vector::empty<u64>();

        let count = 0;

        while (count < vector::length(&(pool_ids))) {
            let pool_id = *vector::borrow(&pool_ids, count );
            if (filter_id == pool_id) {
                let asset_id = *vector::borrow(&asset_ids, count );
                vector::push_back(&mut output, asset_id);
            };
            count = count +1;
        };

        sort_u64(&mut output);

        output
    }


    // staked SUI with earnings at a specific epoch
    public fun get_amount_with_rewards(wrapper: &mut SuiSystemState, staked_sui: &StakedSui, epoch: u64 ) : u64 {
        staking_pool::staked_sui_amount(staked_sui)+stake_data_provider::earnings_from_staked_sui(wrapper, staked_sui, epoch)
    }
 

    /// Sorts the items in ascending order based on the amount of Staked SUI they contain.
    public fun sort_items(items: &mut vector<StakedSui>) {
        let length = vector::length(items);
        let i = 1;
        while (i < length) {
            let cur = vector::borrow(items, i);
            let cur_amount =  staking_pool::staked_sui_amount(cur);
            let j = i;
            while (j > 0) {
                j = j - 1;
                let item = vector::borrow(items, j);
                let item_amount = staking_pool::staked_sui_amount(item);
                if (item_amount > cur_amount) {
                    vector::swap(items, j, j + 1);
                } else {
                    break
                };
            };
            i = i + 1;
        };
    }

    public fun sort_u64(items: &mut vector<u64>) {
        let length = vector::length(items);
        let i = 1;
        while (i < length) {
            let cur = *vector::borrow(items, i);
            let j = i;
            while (j > 0) {
                j = j - 1;
                let item = *vector::borrow(items, j); 
                if (item > cur) {
                    vector::swap(items, j, j + 1);
                } else {
                    break
                };
            };
            i = i + 1;
        };
    }


 
 
}