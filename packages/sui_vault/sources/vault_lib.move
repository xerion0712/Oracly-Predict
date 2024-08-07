

// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::vault_lib {

    use std::vector;

    use sui_system::sui_system::{ Self, SuiSystemState }; 
    use sui_system::staking_pool::{ Self, StakedSui};

    use legato::stake_data_provider::{Self};

    use legato_math::fixed_point64::{Self, FixedPoint64};

    // Staked SUI with earnings at a specific epoch
    public fun get_amount_with_rewards(wrapper: &mut SuiSystemState, staked_sui: &StakedSui, epoch: u64 ) : u64 {
        staking_pool::staked_sui_amount(staked_sui)+stake_data_provider::earnings_from_staked_sui(wrapper, staked_sui, epoch)
    }

    // Sorts the items in ascending order based on the amount of Staked SUI they contain.
    public fun sort_items(items: &mut vector<StakedSui>) {
        let length = vector::length(items);
        let mut i = 1;
        while (i < length) {
            let cur = vector::borrow(items, i);
            let cur_amount =  staking_pool::staked_sui_amount(cur);
            let mut j = i;
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
        let mut i = 1;
        while (i < length) {
            let cur = *vector::borrow(items, i);
            let mut j = i;
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

    //  Find one Staked SUI asset with sufficient value that cover the input amount and minimal excess
    public fun find_one_with_minimal_excess(wrapper: &mut SuiSystemState, item_list: &vector<StakedSui>, input_amount: u64, epoch: u64 ) : (Option<u64>) {
        let length = vector::length(item_list); 

        let mut count = 0;
        let mut output_id = option::none<u64>();

        while ( count < length ) {
            let staked_sui = vector::borrow(item_list, count);
            if (epoch > staking_pool::stake_activation_epoch(staked_sui)) {
                let amount_with_rewards = get_amount_with_rewards(wrapper,  staked_sui, epoch);
                // If the amount with rewards is greater than the input amount, update output variables and break
                if (amount_with_rewards > input_amount) {   
                    output_id = option::some<u64>( count );
                    count = length;
                    break
                };
            };
            count = count + 1;
        };

        output_id
    }

    // Find a combination of staked SUI assets that have sufficient value to cover the input amount.
    public fun find_combination(wrapper: &mut SuiSystemState, item_list: &vector<StakedSui>, input_amount: u64, epoch: u64 ): vector<u64> {
        // Normalizing the value into the ratio
        let (mut ratio, mut ratio_to_id) = normalize_into_ratio(wrapper, item_list, input_amount, epoch);

        // Initialize output variables
        let mut output_id = vector::empty<u64>();
        let mut ratio_count = 0; // Tracks the total ratio

        // Looking for the asset that has 0.5 ratio first
        let mut target_ratio = fixed_point64::create_from_rational(1, 2);

        // Iterate until ratio > 10000
        while ( ratio_count <= 10000 ) {
            // Finds an asset with a ratio close to the target ratio
            let (value, id) = matching_asset_to_ratio(&ratio, target_ratio );

            if (option::is_some( &id ) ) {
                let current_value = *option::borrow(&value);
                let current_id = *option::borrow(&id);

                if (fixed_point64::greater_or_equal(  fixed_point64::create_from_u128(1), current_value )) {
                    // set new target
                    target_ratio = fixed_point64::sub( fixed_point64::create_from_u128(1), current_value );
                    vector::swap_remove( &mut ratio, current_id );
                    let asset_id = vector::swap_remove( &mut ratio_to_id, current_id );
                    vector::push_back(&mut output_id, asset_id);
                    // increase ratio count 
                    ratio_count = ratio_count+fixed_point64::multiply_u128(10000, current_value);
                };

            } else {
                break
            }

        };

        output_id
    }

    fun normalize_into_ratio(wrapper: &mut SuiSystemState,  item_list: &vector<StakedSui>, input_amount: u64, epoch: u64 ): (vector<FixedPoint64>, vector<u64>) {
        let mut ratio = vector::empty<FixedPoint64>();
        let mut ratio_to_id = vector::empty<u64>();
        let mut count = 0;

        while (count < vector::length(item_list)) {
            let staked_sui = vector::borrow(item_list, count);
            let activation_epoch = staking_pool::stake_activation_epoch(staked_sui);

            if (epoch > activation_epoch) {
                let amount_with_rewards = get_amount_with_rewards(wrapper,  staked_sui, epoch);
                let this_ratio = fixed_point64::create_from_rational( (amount_with_rewards as u128) , (input_amount as u128));
                vector::push_back(&mut ratio, this_ratio);
                vector::push_back(&mut ratio_to_id, count);
            };

            count = count+1;
        };

        (ratio, ratio_to_id)
    }

    // Finds an asset with a ratio close to the target ratio
    fun matching_asset_to_ratio( ratio_list: &vector<FixedPoint64>, target_ratio: FixedPoint64 ) : (Option<FixedPoint64>, Option<u64>) {

        let mut output_value = option::none<FixedPoint64>();
        let mut output_id = option::none<u64>();

        let mut precision = 1; // Initialize precision from 0.05 to 1

        // Iterate over different precision values
        while ( precision <= 20) {
            
            let p = fixed_point64::create_from_rational(precision, 20);  // Create fixed-point precision value

            let mut item_count = 0;

            // Iterate over each ratio in the ratio list
            while (item_count < vector::length(ratio_list)) {

                let current_ratio = *vector::borrow( ratio_list, item_count );

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



}