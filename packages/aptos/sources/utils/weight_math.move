

// Module for weighted math operations, the formulas are borrowed from Balancer V2 Lite project.
// https://github.com/icmoore/balancer-v2-lite


module legato_addr::weighted_math {
  
    use aptos_std::fixed_point64::{Self, FixedPoint64}; 
    use aptos_std::math_fixed64; 

    const WEIGHT_SCALE: u64 = 10000;

    const LOG_2_E: u128 = 26613026195707766742;

    // Maximum values for u64 and u128
    const MAX_U64: u128 = 18446744073709551615;
    const MAX_U128: u256 = 340282366920938463463374607431768211455;

    const ERR_INCORRECT_SWAP: u64 = 1; 

    // Computes the optimal value for adding liquidity
    public fun compute_optimal_value(
        amount_out: u64,
        reserve_in: u64, 
        weight_in: u64,
        reserve_out: u64,
        weight_out: u64,
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
            let denominator = reserve_out_after_scaled-amount_out_after_scaled;
            let base = fixed_point64::create_from_rational(reserve_out_after_scaled , denominator);
            let amount_out = fixed_point64::multiply_u128( reserve_in_after_scaled, fixed_point64::sub(base, fixed_point64::create_from_u128(1))  );

            (amount_out as u64)
        } else {

            let denominator = reserve_out_after_scaled-amount_out_after_scaled;
            let base = fixed_point64::create_from_rational(reserve_out_after_scaled , denominator);
            let exponent = fixed_point64::create_from_rational((weight_out as u128), (weight_in as u128));
 
            let power = power(base, exponent);
            let amount_out = fixed_point64::multiply_u128( reserve_in_after_scaled, fixed_point64::sub(power, fixed_point64::create_from_u128(1))  );

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

        let for_x = token_for_lp(amount_x, reserve_x, weight_x, lp_supply );
        let for_y = token_for_lp(amount_y, reserve_y, weight_y, lp_supply );

        (fixed_point64::round( fixed_point64::add(for_x, for_y ) ) as u64)
    }

    // Computes coins to be sent out when withdrawing liquidity
    public fun compute_withdrawn_coins(
        lp_amount: u64,
        lp_supply: u64,
        reserve_x: u64,
        reserve_y: u64,
        weight_x: u64,
        weight_y: u64
    ): (u64, u64) {
 
        let amount_x = lp_for_token( (lp_amount/2 as u128) , lp_supply, reserve_x, weight_x );
        let amount_y =  lp_for_token( (lp_amount/2 as u128)  , lp_supply, reserve_y, weight_y );

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

    // Helper function to calculate the power of a FixedPoint64 number to a FixedPoint64 exponent
    // - When `n` is > 1, it uses the formula `exp(y * ln(x))` instead of `x^y`.
    // - When `n` is < 1, it employs the Newton-Raphson method.
    public fun power(n: FixedPoint64, e: FixedPoint64) : FixedPoint64 {
        // Check if the exponent is 0, return 1 if it is
        if (fixed_point64::equal(e, fixed_point64::create_from_u128(0)) ) {
            fixed_point64::create_from_u128(1)
        } else if (fixed_point64::equal(e, fixed_point64::create_from_u128(1))) {
            // If the exponent is 1, return the base value n 
            n
        } else if (fixed_point64::less(n, fixed_point64::create_from_u128(1))) {

            // Split the exponent into integer and fractional parts
            let integerPart = fixed_point64::floor( e );
            let fractionalPart = fixed_point64::sub(e, fixed_point64::create_from_u128(integerPart));

            // Calculate the integer power using math_fixed64 power function
            let result = math_fixed64::pow( n, (integerPart as u64) );

            if ( fixed_point64::equal( fractionalPart, fixed_point64::create_from_u128(0) ) ) {
                // If the fractional part is zero, return the integer result
                result
            } else {
                // Calculate the fractional using internal nth root function
                let nth = math_fixed64::mul_div( fixed_point64::create_from_u128(1), fixed_point64::create_from_u128(1), fractionalPart );

                let nth_rounded = fixed_point64::round(nth); 

                let fractionalResult =  nth_root( n , (nth_rounded as u64) );
                
                // Combine the integer and fractional powers using multiplication
                math_fixed64::mul_div( result, fractionalResult,  fixed_point64::create_from_u128(1)  )
            }

        } else {

            // Calculate ln(n) times e
            let ln_x_times_y = math_fixed64::mul_div(  e , ln(n), fixed_point64::create_from_u128(1) );
            // Compute exp(ln(x) * y) to get the result of x^y
            math_fixed64::exp(ln_x_times_y)
        }

    }

    // Helper function to approximate the n-th root of a number using the Newton-Raphson method when x < 1.
    public fun nth_root( x: FixedPoint64, n: u64): FixedPoint64 {
        if ( n == 0 ) {
            fixed_point64::create_from_u128(1)
        } else {
            
            // Initialize guess 
            let guess = fixed_point64::create_from_rational(1, 2);

            // Define the epsilon value for determining convergence
            let epsilon = fixed_point64::create_from_rational( 1, 1000 );

            let delta = fixed_point64::create_from_rational( MAX_U64, 1 );

            // Perform Newton-Raphson iterations until convergence
            while ( fixed_point64::greater( delta ,  epsilon )) {
                
                let xn = pow_raw( guess,  n); 
                let derivative = math_fixed64::mul_div( fixed_point64::create_from_u128( (n as u128)), pow_raw( guess,  n-1), fixed_point64::create_from_u128(1) );

                if (fixed_point64::greater_or_equal(xn, x)) { 
                    delta = math_fixed64::mul_div( fixed_point64::sub(xn, x) , fixed_point64::create_from_u128(1), derivative);
                    guess = fixed_point64::sub(guess, delta);
                } else {
                    delta = math_fixed64::mul_div( fixed_point64::sub(x, xn) , fixed_point64::create_from_u128(1), derivative);
                    guess = fixed_point64::add(guess, delta);
                };
            
            };
            // Return the final approximation of the n-th root
            guess
        }
    }

    // Function to calculate the power of a FixedPoint64 number
    public fun pow_raw(x: FixedPoint64, n: u64): FixedPoint64 {
        // Get the raw value of x as a 256-bit unsigned integer
        let raw_value = (fixed_point64::get_raw_value(x) as u256);

        let res: u256 = 1 << 64;

        // Perform exponentiation using bitwise operations
        while (n != 0) {
            if (n & 1 != 0) {
                res = (res * raw_value) >> 64;
            };
            n = n >> 1;
            if ( raw_value <= MAX_U128 ) {
                raw_value = (raw_value * raw_value) >> 64;
            } else {
                raw_value = (raw_value >> 32) * (raw_value >> 32);
            };
        };

        fixed_point64::create_from_raw_value((res as u128))
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

    fun absolute( a: FixedPoint64, b:  FixedPoint64 ) : (FixedPoint64, bool) {
        if (fixed_point64::greater_or_equal(a, b)) { 
            (fixed_point64::sub(a, b), false)
        } else {
            (fixed_point64::sub(b, a), true)
        }
    }

    // calculate fee to treasury
    public fun get_fee_to_treasury(current_fee: FixedPoint64, input: u64): (u64,u64) { 
        let fee = (fixed_point64::multiply_u128( (input as u128) , current_fee) as u64);
        return ( input-fee,fee)
    }

    #[test]
    public fun test_ln() {

        let output_1 = ln( fixed_point64::create_from_u128(10) ); 
        assert!( fixed_point64::almost_equal( output_1, fixed_point64::create_from_rational( 230258509299, 100000000000  ), fixed_point64::create_from_u128(1)) , 0 ); // 2.30258509299

        let output_2 = ln( fixed_point64::create_from_u128(100) ); 
        assert!( fixed_point64::almost_equal( output_2, fixed_point64::create_from_rational( 460517018599 , 100000000000  ), fixed_point64::create_from_u128(1)) , 1 ); // 4.60517018599

        let output_3 = ln( fixed_point64::create_from_u128(500) ); 
        assert!( fixed_point64::almost_equal( output_3, fixed_point64::create_from_rational( 621460809842 , 100000000000  ), fixed_point64::create_from_u128(1)) , 2 ); // 6.21460809842
        
        // return absolute value when input < 1
        let output_4 = ln( fixed_point64::create_from_rational(1, 2) ); 
        assert!( fixed_point64::almost_equal( output_4, fixed_point64::create_from_rational( 693147181 , 1000000000  ), fixed_point64::create_from_u128(1)) , 2 ); // 0.693147181

    }

    #[test]
    public fun test_power() {

        // Asserts that 2^3 = 8
        let output_1 = power(  fixed_point64::create_from_u128(2), fixed_point64::create_from_u128(3) );
        assert!( fixed_point64::round(output_1) == 8, 0 );

        // Asserts that 200^3 = 8000000
        let output_2 = power(  fixed_point64::create_from_u128(200), fixed_point64::create_from_u128(3) );
        assert!( fixed_point64::round(output_2) == 8000000, 1 );

        // Asserts that 30^5 = 24300000
        let output_3 = power(  fixed_point64::create_from_u128(30), fixed_point64::create_from_u128(5) );
        assert!( fixed_point64::round(output_3) == 24300000, 2 ); // 30^5 = 24300000

        // tests for nth-root calculations

        // Asserts that the square root of 16 is approximately 4.
        let n_output_1 = power(  fixed_point64::create_from_u128(16), fixed_point64::create_from_rational(1, 2 )  );
        assert!( fixed_point64::almost_equal( n_output_1, fixed_point64::create_from_rational( 4, 1  ), fixed_point64::create_from_u128(1)) , 3 );
        // Asserts that the fifth root of 625 is approximately 3.623.
        let n_output_2 = power(  fixed_point64::create_from_u128(625), fixed_point64::create_from_rational(1, 5 )  );
        assert!( fixed_point64::almost_equal( n_output_2, fixed_point64::create_from_rational( 3623, 1000 ), fixed_point64::create_from_u128(1)) , 4 );
        // Asserts that the cube root of 1000 is approximately 9.999999977.
        let n_output_3 = power(  fixed_point64::create_from_u128(1000), fixed_point64::create_from_rational(1, 3 )  );
        assert!( fixed_point64::almost_equal( n_output_3, fixed_point64::create_from_rational( 9999, 1000 ), fixed_point64::create_from_u128(1)) , 5 );
        // Asserts that the cube root of 729 is approximately 8.99999998.
        let n_output_4 = power(  fixed_point64::create_from_u128(729), fixed_point64::create_from_rational(1, 3 )  );
        assert!( fixed_point64::almost_equal( n_output_4, fixed_point64::create_from_rational( 8999, 1000 ), fixed_point64::create_from_u128(1)) , 6 );
        
        // Asserts that the fourth root of 9/16 is approximately 0.866025404.
        let n_output_5 = power(  fixed_point64::create_from_rational( 9, 16 ), fixed_point64::create_from_rational( 1, 4 )  );
        assert!( fixed_point64::almost_equal( n_output_5, fixed_point64::create_from_rational( 866025404, 1000000000 ), fixed_point64::create_from_u128(1)) , 7 ); // 0.866025404
        
        // Asserts that the tenth root of 1/2 is approximately 0.420448208.
        let n_output_6 = power(  fixed_point64::create_from_rational( 1, 2 ), fixed_point64::create_from_rational( 10, 8 )  );
        assert!( fixed_point64::almost_equal( n_output_6, fixed_point64::create_from_rational( 420448208, 1000000000 ), fixed_point64::create_from_u128(1)) , 8 ); // 0.420448208

        // Asserts that the fifth root of 2/5 is approximately 0.01024.
        let n_output_7 = power(  fixed_point64::create_from_rational( 2, 5 ), fixed_point64::create_from_rational( 5, 1 )  );
        assert!( fixed_point64::almost_equal( n_output_7, fixed_point64::create_from_rational( 1024, 100000 ), fixed_point64::create_from_u128(1)) , 9 ); // 0.01024

        // Asserts that the ninth root of 3/5 is approximately 0.566896603.
        let n_output_8 = power(  fixed_point64::create_from_rational( 3, 5 ), fixed_point64::create_from_rational( 10, 9 )  );
        assert!( fixed_point64::almost_equal( n_output_8, fixed_point64::create_from_rational( 566896603, 1000000000 ), fixed_point64::create_from_u128(1)) , 10 ); // 0.566896603
        
    }

}