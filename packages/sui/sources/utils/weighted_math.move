

module legato::weighted_math {

    use legato::math::{sqrt};
    use legato::fixed_point64::{Self}; 
    use legato::math128::{Self};

    const WEIGHT_SCALE: u64 = 10000;
    const HALF_WEIGHT_SCALE: u64 = 5000;

    const ERR_INCORRECT_SWAP: u64 = 214; 

    // Computes the optimal value for adding liquidity
    public fun compute_optimal_value(
        amount_in: u64,
        reserve_in: u64,
        _weight_in: u64,
        scaling_factor_in: u64,
        reserve_out: u64,
        _weight_out: u64,
        scaling_factor_out: u64
    ) : u64 {
        let amount_in_after_scaled = scale_amount(amount_in, scaling_factor_in);
        let balance_in_after_scaled = scale_amount(reserve_in, scaling_factor_in);
        let balance_out_after_scaled  = scale_amount(reserve_out, scaling_factor_out);

        let current_ratio = fixed_point64::create_from_rational( balance_out_after_scaled , balance_in_after_scaled );
        let amount_out = fixed_point64::multiply_u128(amount_in_after_scaled , current_ratio );

        (math128::ceil_div( amount_out, (scaling_factor_out as u128) ) as u64)
    }


    // Calculate the output amount according to the pool weight
    public fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        weight_in: u64,
        scaling_factor_in: u64,
        reserve_out: u64,
        weight_out: u64,
        scaling_factor_out: u64
    ) : u64 {

        /**********************************************************************************************
        // outGivenIn                                                                                //
        // aO = amountOut                                                                            //
        // bO = balanceOut                                                                           //
        // bI = balanceIn              /      /            bI             \    (wI / wO) \           //
        // aI = amountIn    aO = bO * |  1 - | --------------------------  | ^            |          //
        // wI = weightIn               \      \       ( bI + aI )         /              /           //
        // wO = weightOut                                                                            //
        **********************************************************************************************/

        let amount_in_after_scaled = scale_amount(amount_in, scaling_factor_in);
        let reserve_in_after_scaled = scale_amount(reserve_in, scaling_factor_in);
        let reserve_out_after_scaled = scale_amount(reserve_out, scaling_factor_out); 

        if (weight_in == weight_out) {
            
            let denominator = reserve_in_after_scaled+amount_in_after_scaled; 
            let base = fixed_point64::create_from_rational(reserve_in_after_scaled , denominator);
            let amount_out = fixed_point64::multiply_u128( reserve_out_after_scaled, fixed_point64::sub(fixed_point64::create_from_u128(1), base ) );

            // (math128::ceil_div(amount_out , (scaling_factor_out as u128)) as u64)
            (amount_out as u64) / scaling_factor_out
        } else if (weight_in > weight_out) { 
            std::debug::print(&456);
            1000
        } else {
            std::debug::print(&789);
            1000
        }
    }


    // Computes initial LP amount
    public fun compute_initial_lp(
        weight_x: u64,
        weight_y: u64,
        scaling_factor_x: u64,
        scaling_factor_y: u64,
        amount_x: u64,
        amount_y: u64
    ): u64 {
        let amount_x_after_scaled = scale_amount(amount_x, scaling_factor_x);
        let amount_y_after_scaled = scale_amount(amount_y, scaling_factor_y);
        sqrt( apply_weighting(amount_x_after_scaled, weight_x, HALF_WEIGHT_SCALE ) * apply_weighting(amount_y_after_scaled, weight_y ,HALF_WEIGHT_SCALE) )
    }

    // Computes LP when it's set
    public fun compute_derive_lp(
        lp_supply: u64,
        amount: u64,
        scaling_factor: u64,
        reserve: u64
    ): u128 {
        let amount_after_scaled = scale_amount(amount, scaling_factor);
        let reserve_after_scaled = scale_amount(reserve, scaling_factor);

        let multiplier = fixed_point64::create_from_rational( (lp_supply as u128), reserve_after_scaled );
        fixed_point64::multiply_u128( amount_after_scaled , multiplier )
    }

    // Computes coins to be sent out when withdrawing liquidity
    public fun compute_withdrawn_coins(
        balance: u64, 
        lp_amount: u64,
        lp_supply: u64
    ): u64 {
        let multiplier = fixed_point64::create_from_rational( (lp_amount as u128) , (lp_supply as u128) );
        let amount_out = fixed_point64::multiply_u128( (balance as u128), multiplier );
        (amount_out as u64)
    } 

    public fun assert_lp_value_is_increased(
        weight_x: u64,
        weight_y: u64,
        scaling_factor_x: u64,
        scaling_factor_y: u64,
        old_reserve_x: u64,
        old_reserve_y: u64,
        new_reserve_x: u64,
        new_reserve_y: u64,
    ) {

        let old_reserve_x_after_scaled = scale_amount(old_reserve_x, scaling_factor_x);
        let old_reserve_y_after_scaled = scale_amount(old_reserve_y, scaling_factor_y);
        let new_reserve_x_after_scaled = scale_amount(new_reserve_x, scaling_factor_x);
        let new_reserve_y_after_scaled = scale_amount(new_reserve_y, scaling_factor_y);
        assert!(
            apply_weighting(old_reserve_x_after_scaled, weight_x, HALF_WEIGHT_SCALE ) * apply_weighting(old_reserve_y_after_scaled, weight_y ,HALF_WEIGHT_SCALE)
                < apply_weighting(new_reserve_x_after_scaled, weight_x, HALF_WEIGHT_SCALE ) * apply_weighting(new_reserve_y_after_scaled, weight_y ,HALF_WEIGHT_SCALE),
            ERR_INCORRECT_SWAP
        )
    }

    public fun get_fee_to_treasury(current_fee: u64, input: u64): (u64,u64) {
        let multiplier = fixed_point64::create_from_rational( (current_fee as u128) , (WEIGHT_SCALE as u128) );
        let fee = (fixed_point64::multiply_u128( (input as u128) , multiplier ) as u64);
        return ( input-fee,fee)
    }

    fun scale_amount(amount: u64, scaling_factor: u64): u128 {
        ((amount as u128)*(scaling_factor as u128))
    }

    fun apply_weighting(amount: u128, weight_in: u64, weight_out: u64): u128 {
        let weight_factor = fixed_point64::create_from_rational((weight_out as u128), (weight_in as u128) );
        fixed_point64::multiply_u128( amount, weight_factor )
    } 

}