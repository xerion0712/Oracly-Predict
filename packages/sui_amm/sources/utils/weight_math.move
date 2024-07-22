
// Module for weighted math operations, the formulas are borrowed from Balancer V2 Lite project.
// https://github.com/icmoore/balancer-v2-lite

module legato::weighted_math {
  
    use legato_math::fixed_point64::{Self, FixedPoint64}; 
    use legato_math::math_fixed64;
    use legato_math::math128;
    use legato_math::legato_math::{absolute, power};

    const WEIGHT_SCALE: u64 = 10000; 

    // Maximum values for u64 and u128
    const MAX_U64: u128 = 18446744073709551615;
    const MAX_U128: u256 = 340282366920938463463374607431768211455;

    const LOG_2_E: u128 = 26613026195707766742;

    const ERR_INCORRECT_SWAP: u64 = 1; 

    // Computes the optimal value for adding liquidity
    public fun compute_optimal_value(
        amount_out: u64,
        reserve_in: u64, 
        weight_in: u64,
        reserve_out: u64,
        weight_out: u64
    ) : u64 {

        get_amount_in(
            amount_out,
            reserve_in,
            weight_in,
            reserve_out,
            weight_out
        )
    }

    // Calculate the output amount according to the pool weight 
    // - amountIn = balanceIn * ((( balanceOut / (balanceOut - amountOut) ) ^ (wO/wI))-1)
    public fun get_amount_in(
        amount_out: u64,
        reserve_in: u64,
        weight_in: u64, 
        reserve_out: u64,
        weight_out: u64, 
    ) : u64 {
        
        let amount_out_after_scaled = (amount_out as u128);
        let reserve_in_after_scaled = (reserve_in as u128);
        let reserve_out_after_scaled  = (reserve_out as u128);

        if (weight_in == weight_out) {
            // For pools with equal weights, apply simplified calculation
            let denominator = reserve_out_after_scaled-amount_out_after_scaled;
            let base = fixed_point64::create_from_rational(reserve_out_after_scaled , denominator);
            let amount_out = fixed_point64::multiply_u128( reserve_in_after_scaled, fixed_point64::sub(base, fixed_point64::create_from_u128(1))  );

            (amount_out as u64)
        }  else {
            // For pools with different weights
            let denominator = reserve_out_after_scaled-amount_out_after_scaled;
            let base = fixed_point64::create_from_rational(reserve_out_after_scaled , denominator);
            let exponent = fixed_point64::create_from_rational((weight_out as u128), (weight_in as u128));

            // Calculate the power function
            let power = power(base, exponent);
            let amount_out = fixed_point64::multiply_u128( reserve_in_after_scaled, fixed_point64::sub(power, fixed_point64::create_from_u128(1))  );

            (amount_out as u64)
        }

    }

    // Calculate the output amount according to the pool weight
    // - amountOut = balanceOut * (1 - ((balanceIn / (balanceIn + amountIn)) ^ (wI / wO)))
    public fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        weight_in: u64, 
        reserve_out: u64,
        weight_out: u64, 
    ) : u64 {

        // Scale the amount to adjust for the provided scaling factor of the asset
        let amount_in_after_scaled = (amount_in as u128);
        let reserve_in_after_scaled = (reserve_in as u128);
        let reserve_out_after_scaled  = (reserve_out as u128);

        if (weight_in == weight_out) {
            let denominator = reserve_in_after_scaled+amount_in_after_scaled; 
            let base = fixed_point64::create_from_rational(reserve_in_after_scaled , denominator);
            let amount_out = fixed_point64::multiply_u128( reserve_out_after_scaled, fixed_point64::sub(fixed_point64::create_from_u128(1), base ) );

            (amount_out as u64)
        }  else {

            let denominator = reserve_in_after_scaled+amount_in_after_scaled; 
            let base = fixed_point64::create_from_rational(reserve_in_after_scaled , denominator);
            let exponent = fixed_point64::create_from_rational((weight_in as u128), (weight_out as u128));
 
            let power = power(base, exponent);
            let amount_out = fixed_point64::multiply_u128( reserve_out_after_scaled , fixed_point64::sub( fixed_point64::create_from_u128(1), power   )  );

            (amount_out as u64)
        }
 
    }

    // Computes initial LP amount using the formula - total_share = (amount_x^weight_x) * (amount_y^weight_y)
    public fun compute_initial_lp(
        weight_x: u64,
        weight_y: u64, 
        amount_x: u64,
        amount_y: u64
    ): u64 {

        let amount_x_after_weighted = power( fixed_point64::create_from_u128( (amount_x as u128)), fixed_point64::create_from_rational( (weight_x as u128), (WEIGHT_SCALE as u128) ));
        let amount_y_after_weighted = power( fixed_point64::create_from_u128( (amount_y as u128)), fixed_point64::create_from_rational( (weight_y as u128), (WEIGHT_SCALE as u128) ));

        let sum = math_fixed64::mul_div( amount_x_after_weighted, amount_y_after_weighted, fixed_point64::create_from_u128(1) );

        (fixed_point64::round( sum ) as u64)
    }

    // Computes LP when it's set
    public fun compute_derive_lp(
        amount_x: u64,
        amount_y: u64,
        weight_x: u64,
        weight_y: u64,
        reserve_x: u64,
        reserve_y: u64,
        lp_supply: u64
    ): (u64) {
        // Calculate the LP tokens for token X
        let for_x = token_for_lp(amount_x, reserve_x, weight_x, lp_supply );

        // Calculate the LP tokens for token Y
        let for_y = token_for_lp(amount_y, reserve_y, weight_y, lp_supply );

        (fixed_point64::round( fixed_point64::add(for_x, for_y ) ) as u64)
    }
 

    // Computes the amounts of tokens to be sent out when withdrawing liquidity
    public fun compute_withdrawn_coins(
        lp_amount: u64,
        lp_supply: u64,
        reserve_x: u64,
        reserve_y: u64,
        weight_x: u64,
        weight_y: u64
    ): (u64, u64) {

        // Calculate the amount of token X to be withdrawn based on the LP tokens and weight
        let amount_x = lp_for_token( (lp_amount/2 as u128) , lp_supply, reserve_x, weight_x );
        
        // Calculate the amount of token Y to be withdrawn based on the LP tokens and weight
        let amount_y =  lp_for_token( (lp_amount/2 as u128)  , lp_supply, reserve_y, weight_y );

        // Return the amounts of token X and token Y as a tuple, casting them to u64
        ((amount_x as u64),(amount_y as u64))
    }   

    // Calculates the amount of output coins to receive from a given LP amount 
    // - output_amount = reserve * (1 - ((lp_supply - lp_amount) / lp_supply) ^ (1 / weight))
    public fun lp_for_token(
        lp_amount: u128,
        lp_supply: u64, 
        reserve: u64, 
        weight: u64
    ) : u64 {

        let base = fixed_point64::create_from_rational( ((lp_supply-(lp_amount as u64)) as u128), (lp_supply as u128) );
        let power = power(base, fixed_point64::create_from_rational( (WEIGHT_SCALE as u128), (weight as u128) ) );

        ( (fixed_point64::multiply_u128( (reserve as u128) ,  fixed_point64::sub( fixed_point64::create_from_u128(1), power )  )) as u64)
    }

    // Calculates the amount of LP tokens to receive from a given coins.
    // - lp_out = lp_supply * ((reserve + amount) / reserve) ^ (weight / WEIGHT_SCALE) - 1  
    public fun token_for_lp(
        amount: u64,
        reserve: u64,
        weight: u64,
        lp_supply: u64
    ) : FixedPoint64 {

        let base = fixed_point64::create_from_rational( ( (reserve+amount) as u128 ), (reserve as u128) );
        let power = power(base,  fixed_point64::create_from_rational( (weight as u128), (WEIGHT_SCALE as u128) ) ); 

        // fixed_point64::multiply_u128( (lp_supply as u128) ,  fixed_point64::sub( power,  fixed_point64::create_from_u128(1) )  )
        math_fixed64::mul_div(  fixed_point64::create_from_u128(  (lp_supply as u128) ), fixed_point64::sub( power,  fixed_point64::create_from_u128(1) ), fixed_point64::create_from_u128(1)  )
    }

     
    // Calculate the natural logarithm of the input using FixedPoint64
    public fun ln(input : FixedPoint64) : FixedPoint64 {
        // Define the constant log_2(e)
        let log_2_e = fixed_point64::create_from_raw_value( LOG_2_E );
        
        // Calculate the base-2 logarithm of the input
        let after_log2 = (math_fixed64::log2_plus_64( input ));

        let fixed_2 = fixed_point64::create_from_u128(64);

        // Subtract 64 to adjust the result back 
        let (after_subtracted, _) = absolute( after_log2, fixed_2 );
        math_fixed64::mul_div( after_subtracted, fixed_point64::create_from_u128(1) , log_2_e)
    }
 
    // scale an amount by a scaling factor
    public fun scale_amount(amount: u64, scaling_factor: u64): u128 {
        ((amount as u128)*(scaling_factor as u128))
    }

    // calculate fee to treasury
    public fun get_fee_to_treasury(current_fee: FixedPoint64, input: u64): (u64,u64) { 
        let fee = (fixed_point64::multiply_u128( (input as u128) , current_fee) as u64);
        return ( input-fee,fee)
    }
 


    // Test for conversion between input and output amounts in a weighted pool
    #[test]
    public fun test_amount_in_out_conversion() {

        // Given a pool with 50:50 weight for 1.5 USDC/SUI
        let usdc_reserve = 50000_000_000; // 50,000 USDC
        let sui_reserve = 33333_000_000_000; // 33,333 SUI

        // Conversion from USDC to SUI
        let sui_out = get_amount_out(100_000_000, usdc_reserve, 5000, sui_reserve , 5000 ); 
        assert!( sui_out == 66_532_934_131, 11 ); // 66.53 SUI -> 1.503081317 USDC/SUI

        let usdc_in = get_amount_in( sui_out, usdc_reserve, 5000, sui_reserve, 5000 );
        assert!( usdc_in == 99_999_999, 12); // ~100 USDC 

        // Conversion from SUI to USDC
        let usdc_out = get_amount_out(100_000_000_000, sui_reserve, 5000, usdc_reserve , 5000 ); 
        assert!( usdc_out == 149_552_837, 13 ); // 149.55 USDC -> 1.49552 USDC/SUI

        let sui_in = get_amount_in( usdc_out, sui_reserve, 5000, usdc_reserve, 5000 );
        assert!( sui_in == 99_999_999_988, 14 ); // ~100 SUI 

        // Given a pool with 90:10 weight for 50000 USDT/BTC
        let usdt_reserve = 10000_000_000; // 10,000 USDT
        let btc_reserve = 180_000_000; // 1.8 BTC

        // Conversion from USDT to BTC
        let btc_out = get_amount_out(100_000_000, usdt_reserve, 1000, btc_reserve , 9000 );
        assert!( btc_out == 198_895, 15 ); // 0.00198 BTC -> 50505 USDT/BTC

        let usdt_in = get_amount_in(btc_out, usdt_reserve, 1000, btc_reserve, 9000);  
        assert!( usdt_in == 99_999_167, 16 ); // ~100 USDT

        // Conversion from BTC to USDT
        let usdt_out = get_amount_out(200_000, btc_reserve, 9000, usdt_reserve , 1000 );
        assert!( usdt_out == 99_446_700, 17 ); // 99.46 USDT -> 49723 USDT/BTC

        let btc_in = get_amount_in( usdt_out,  btc_reserve, 9000, usdt_reserve, 1000);
        assert!( btc_in == 199_999, 18 ); // ~0.002 BTC 

    }
 
}