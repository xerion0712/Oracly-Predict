// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// All shared helper functions for vault.move / amm.move

module legato_addr::legato_lib {

    use aptos_std::fixed_point64::{Self, FixedPoint64};
    use aptos_std::math_fixed64::{Self};
    use std::string::{Self, String, utf8};
    use aptos_std::type_info;   

     const ERR_INVALID_TYPE: u64 = 1;

    // Construct the name and symbol of the PT token
    public fun generate_vault_name_and_symbol<P>() : (String, String) {
        let type_name = type_info::type_name<P>();
        let index = string::index_of(&type_name, &utf8(b"vault_token_name::"));
        assert!(index != string::length(&type_name) , ERR_INVALID_TYPE );

        let token_symbol =  string::sub_string( &type_name, index+18, string::length(&type_name));
        let token_name = string::utf8(b"PT-");

        string::append(&mut token_name, token_symbol);

        (token_name, token_symbol)
    }

    // Calculate the amount of PT debt to be sent out using the formula P = S * e^(rt)
    public fun calculate_pt_debt_amount(apy: FixedPoint64, from_timestamp: u64, to_timestamp: u64, input_amount: u64): u64 {
        
        // Calculate time duration in years
        let time = fixed_point64::create_from_rational( ((to_timestamp-from_timestamp) as u128), 31556926 );

        // Calculate rt (rate * time)
        let rt = math_fixed64::mul_div( apy, time, fixed_point64::create_from_u128(1));
        let multiplier = math_fixed64::exp(rt);

        // the final PT debt amount
        ( fixed_point64::multiply_u128( (input_amount as u128), multiplier  ) as u64 )
    }

    // Calculate the amount when exiting using the formula S = P / e^(rt
    public fun calculate_exit_amount(apy: FixedPoint64, from_timestamp: u64, to_timestamp: u64, output_amount: u64) : u64 {

        let time = fixed_point64::create_from_rational( ((to_timestamp-from_timestamp) as u128), 31556926 );

        let rt = math_fixed64::mul_div( apy, time, fixed_point64::create_from_u128(1));
        let denominator = math_fixed64::exp(rt);

        ( fixed_point64::divide_u128( (output_amount as u128), denominator  ) as u64 )
    }
}