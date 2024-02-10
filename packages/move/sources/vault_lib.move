// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::vault_lib {

    use sui_system::staking_pool::{ Self, StakedSui};

    use std::string::{ Self, String }; 
    use std::ascii::{ into_bytes};
    use std::type_name::{get, into_string};
    use std::vector;

    public fun token_to_name<P>(): String {
        string::utf8(into_bytes(into_string(get<P>())))
    }

    public fun calculate_pt_debt_from_epoch(apy: u64, from_epoch: u64, to_epoch: u64, input_amount: u64): u64 {
        let for_epoch = to_epoch-from_epoch;
        let (for_epoch, apy, input_amount) = ((for_epoch as u128), (apy as u128), (input_amount as u128));
        let result = (for_epoch*apy*input_amount) / (365_000_000_000);
        (result as u64)
    }

    public fun sort_items(items: &mut vector<StakedSui>) {
        let length = vector::length(items);
        let i = 1;
        while (i < length) {
            let cur = vector::borrow(items, i);
            let cur_amount = staking_pool::staked_sui_amount(cur);
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

    // #[test_only]
    // public fun median_apy(wrapper: &mut SuiSystemState, vault: &PoolConfig, epoch: u64): u64 {
    //     let count = vector::length(&vault.staking_pools);
    //     let i = 0;
    //     let total_sum = 0;
    //     while (i < count) {
    //         let pool_id = vector::borrow(&vault.staking_pools, i);
    //         total_sum = total_sum+apy_reader::pool_apy(wrapper, pool_id, epoch);
    //         i = i + 1;
    //     };
    //     total_sum / i
    // }

    // #[test_only]
    // public fun ceil_apy(wrapper: &mut SuiSystemState, vault: &PoolConfig, epoch: u64): u64 {
    //     let count = vector::length(&vault.staking_pools);
    //     let i = 0;
    //     let output = 0;
    //     while (i < count) {
    //         let pool_id = vector::borrow(&vault.staking_pools, i);
    //         output = math::max( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
    //         i = i + 1;
    //     };
    //     output
    // }

    // #[test_only]
    // public fun floor_apy(wrapper: &mut SuiSystemState, vault: &PoolConfig, epoch: u64): u64 {
    //     let count = vector::length(&vault.staking_pools);
    //     let i = 0;
    //     let output = 0;
    //     while (i < count) {
    //         let pool_id = vector::borrow(&vault.staking_pools, i);
    //         if (output == 0)
    //                 output = apy_reader::pool_apy(wrapper, pool_id, epoch)
    //             else output = math::min( output, apy_reader::pool_apy(wrapper, pool_id, epoch) );
    //         i = i + 1;
    //     };
    //     output
    // }

}