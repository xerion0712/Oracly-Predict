

module legato::weighted_math {

    use legato::math::{sqrt};
    use legato::fixed_point64::{Self}; 
    use legato::math128;

    const WEIGHT_SCALE: u64 = 10000;
    const HALF_WEIGHT_SCALE: u64 = 5000;

    // Computes the optimal value for the pair asset
    public fun get_optimal_value(
        amount_in: u64,
        balance_in: u64,
        _weight_in: u64,
        scaling_factor_in: u64,
        balance_out: u64,
        _weight_out: u64,
        scaling_factor_out: u64
    ) : u64 {
        let amount_in_after_scaled = scale_amount(amount_in, scaling_factor_in);
        let balance_in_after_scaled = scale_amount(balance_in, scaling_factor_in);
        let balance_out_after_scaled  = scale_amount(balance_out, scaling_factor_out);

        let current_ratio = fixed_point64::create_from_rational( balance_out_after_scaled , balance_in_after_scaled );
        let amount_out = fixed_point64::multiply_u128(amount_in_after_scaled , current_ratio );

        (math128::ceil_div( amount_out, (scaling_factor_out as u128) ) as u64)
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
        _weight_in: u64,
        _weight_out: u64,
        scaling_factor: u64,
        reserve: u64
    ): u128 {
        let amount_after_scaled = scale_amount(amount, scaling_factor);
        let reserve_after_scaled = scale_amount(reserve, scaling_factor);

        let multiplier = fixed_point64::create_from_rational( (lp_supply as u128), reserve_after_scaled );
        fixed_point64::multiply_u128( amount_after_scaled , multiplier )
    }

    fun scale_amount(amount: u64, scaling_factor: u64): u128 {
        ((amount as u128)*(scaling_factor as u128))
    }

    fun apply_weighting(amount: u128, weight_in: u64, weight_out: u64): u128 {
        let weight_factor = fixed_point64::create_from_rational((weight_out as u128), (weight_in as u128) );
        fixed_point64::multiply_u128( amount, weight_factor )
    } 

}