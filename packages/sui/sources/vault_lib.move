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

    public fun token_to_name_with_prefix<P>(prefix: vector<u8>): String {
        let name_with_prefix = string::utf8(b"");
        string::append_utf8(&mut name_with_prefix, prefix);
        string::append_utf8(&mut name_with_prefix, b"-");
        string::append_utf8(&mut name_with_prefix, into_bytes(into_string(get<P>())));
        name_with_prefix
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

   

}