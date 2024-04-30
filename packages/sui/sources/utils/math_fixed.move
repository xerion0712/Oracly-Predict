/// Standard math utilities missing in the Move Language.
module legato::math_fixed {

    use legato::fixed_point32;
    use legato::fixed_point32::FixedPoint32;
    use legato::math128;
    use legato::math64;

    /// Abort code on overflow
    const EOVERFLOW_EXP: u64 = 1;

    /// Natural log 2 in 32 bit fixed point
    const LN2: u128 = 2977044472;  // ln(2) in fixed 32 representation
    const LN2_X_32: u64 = 32 * 2977044472;  // 32 * ln(2) in fixed 32 representation

    /// Square root of fixed point number
    public fun sqrt(x: FixedPoint32): FixedPoint32 {
        let y = (fixed_point32::get_raw_value(x) as u128);
        fixed_point32::create_from_raw_value((math128::sqrt(y << 32) as u64))
    }

    /// Exponent function with a precission of 9 digits.
    public fun exp(x: FixedPoint32): FixedPoint32 {
        let raw_value = (fixed_point32::get_raw_value(x) as u128);
        fixed_point32::create_from_raw_value((exp_raw(raw_value) as u64))
    }

    /// Because log2 is negative for values < 1 we instead return log2(x) + 32 which
    /// is positive for all values of x.
    public fun log2_plus_32(x: FixedPoint32): FixedPoint32 {
        let raw_value = (fixed_point32::get_raw_value(x) as u128);
        math128::log2(raw_value)
    }

    public fun ln_plus_32ln2(x: FixedPoint32): FixedPoint32 {
        let raw_value = (fixed_point32::get_raw_value(x) as u128);
        let x = (fixed_point32::get_raw_value(math128::log2(raw_value)) as u128);
        fixed_point32::create_from_raw_value((x * LN2 >> 32 as u64))
    }

    /// Integer power of a fixed point number
    public fun pow(x: FixedPoint32, n: u64): FixedPoint32 {
        let raw_value = (fixed_point32::get_raw_value(x) as u128);
        fixed_point32::create_from_raw_value((pow_raw(raw_value, (n as u128)) as u64))
    }

    /// Specialized function for x * y / z that omits intermediate shifting
    public fun mul_div(x: FixedPoint32, y: FixedPoint32, z: FixedPoint32): FixedPoint32 {
        let a = fixed_point32::get_raw_value(x);
        let b = fixed_point32::get_raw_value(y);
        let c = fixed_point32::get_raw_value(z);
        fixed_point32::create_from_raw_value (math64::mul_div(a, b, c))
    }

    // Calculate e^x where x and the result are fixed point numbers
    fun exp_raw(x: u128): u128 {
        // exp(x / 2^32) = 2^(x / (2^32 * ln(2))) = 2^(floor(x / (2^32 * ln(2))) + frac(x / (2^32 * ln(2))))
        let shift_long = x / LN2;
        assert!(shift_long <= 31, EOVERFLOW_EXP);
        let shift = (shift_long as u8);
        let remainder = x % LN2;
        // At this point we want to calculate 2^(remainder / ln2) << shift
        // ln2 = 595528 * 4999 which means
        let bigfactor = 595528;
        let exponent = remainder / bigfactor;
        let x = remainder % bigfactor;
        // 2^(remainder / ln2) = (2^(1/4999))^exponent * exp(x / 2^32)
        let roottwo = 4295562865;  // fixed point representation of 2^(1/4999)
        // This has an error of 5000 / 4 10^9 roughly 6 digits of precission
        let power = pow_raw(roottwo, exponent);
        let eps_correction = 1241009291;
        power = power + ((power * eps_correction * exponent) >> 64);
        // x is fixed point number smaller than 595528/2^32 < 0.00014 so we need only 2 tayler steps
        // to get the 6 digits of precission
        let taylor1 = (power * x) >> (32 - shift);
        let taylor2 = (taylor1 * x) >> 32;
        let taylor3 = (taylor2 * x) >> 32;
        (power << shift) + taylor1 + taylor2 / 2 + taylor3 / 6
    }

    // Calculate x to the power of n, where x and the result are fixed point numbers.
    fun pow_raw(x: u128, n: u128): u128 {
        let res: u256 = 1 << 64;
        x = x << 32;
        while (n != 0) {
            if (n & 1 != 0) {
                res = (res * (x as u256)) >> 64;
            };
            n = n >> 1;
            x = ((((x as u256) * (x as u256)) >> 64) as u128);
        };
        ((res >> 32) as u128)
    }

}
