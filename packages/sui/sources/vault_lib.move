// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// All necessary functions for vault.move calculations reside here

module legato::vault_lib {

    use legato::fixed_point64::{ Self, FixedPoint64};
    use legato::math_fixed64::{Self};

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

}